function Convert-CVSSStringToBaseScore {
    # This function takes a CVSS v3.1 string as input and returns the base score as output
    param (
        [Parameter(Mandatory=$true)]
        [string]$CVSSString # The CVSS v3.1 string to convert
    )

    # Validate the input string
    if ($CVSSString -notmatch "CVSS:3\.1/AV:[NALP]/AC:[LH]/PR:[NLH]/UI:[NR]/S:[UC]/C:[NLH]/I:[NLH]/A:[NLH]") {
        Write-Error "Invalid CVSS v3.1 string format"
        return
    }

    # Split the string into metrics and values
    $values = $CVSSString.Split("/")[1..8] | ForEach-Object {$_.Split(":")[1]}

    # Define the weight tables for each metric
    $AVWeights = @{
        N = 0.85
        A = 0.62
        L = 0.55
        P = 0.2
    }

    $ACWeights = @{
        L = 0.77
        H = 0.44
    }

    $PRWeights = @{
        N = @{
            U = 0.85
            C = 0.85
        }
        L = @{
            U = 0.62
            C = 0.68
        }
        H = @{
            U = 0.27
            C = 0.5
        }
    }

    $UIWeights = @{
        N = 0.85
        R = 0.62
    }

    $CWeights = @{
        N = 0
        L = 0.22
        H = 0.56
    }

    $IWeights = @{
        N = 0
        L = 0.22
        H = 0.56
    }

    $AWeights = @{
        N = 0
        L = 0.22
        H = 0.56
    }

    # Calculate the impact sub-score using the formula from the CVSS specification
    $ISSBase = 1 - ((1 - $CWeights[$values[5]]) * (1 - $IWeights[$values[6]]) * (1 - $AWeights[$values[7]]))

    # Adjust the impact sub-score based on the scope metric value using the formula from the CVSS specification
    if ($values[4] -eq "U") {
        $ISSFinal = 6.42 * $ISSBase
    } else {
        $ISSFinal = 7.52 * ($ISSBase - 0.029) - 15 * [Math]::Pow(($ISSBase - 0.02),15)
    }

    # Calculate the exploitability sub-score using the formula from the CVSS specification
    $ESSFinal = 8.22 * $AVWeights[$values[0]] * $ACWeights[$values[1]] * $prweights[$values[2]][$values[4]] * $UIWeights[$values[3]]

    # Calculate the base score using the formula from the CVSS specification
    if ($ISSFinal -le 0) {
        $BaseScoreFinal = 0
    }
    elseif ($values[4] -eq "U") {
        $BaseScoreFinal = [math]::Min([math]::Round(($ISSFinal + $ESSFinal),1),10)
    }
    else {
        $BaseScoreFinal = [math]::Min([math]::Round((($ISSFinal + $ESSFinal) * 1.08),1),10)
    }

    # Return the base score as output
    return $BaseScoreFinal
}

function ConvertTo-Version {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VersionString
    )
    # Split the string by dot or any non-digit character
    $parts = $VersionString -split '[\.\D]+'
    # Create a new string with the parts
    return ($parts -join '.')
}

function Get-HighVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)][string]$High,
        [Parameter(Mandatory=$true)][string]$Compare
    )
    #compares 2 Version objects and returns the 'newer' one
    #-gt doesn't work with empty strings, so need to use "UNSET" to indicate ""
    if ($High -eq "") {
        $High = "UNSET"
    }
    if ($Compare -eq "") {
        $Compare = "UNSET"
    }

    if ($Compare -ne "UNSET") {
        if ($High -eq "UNSET") {
            $High = $Compare
        } elseif ($High -ne "Unresolved version") {
            try {
                #sometimes the version string can't be cast correctly
                if ([System.Version]$Compare -gt [System.Version]$High) {
                    $High = $Compare
                }
            } catch {
                try {
                    $Compare2 = ConvertTo-Version($Compare)
                    if ([System.Version]$Compare2 -gt [System.Version]$High) {
                        $High = $Compare2
                    }
                } catch {
                    $High = "Unresolved version"
                }
            }
        }
    } else {
        $High = "Unresolved version"
    }

    Return $High
}

function PrintLicenses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object[]]$alllicenses
    )

    $licstr = ""
    $LowRisk = ""
    $MedRisk = ""
    $HighRisk = ""

    #Low Risk licenses generally do not require any action / attribution to include or modify the code
    $LowRiskLicenses = @("MIT", "Apache-2.0", "ISC", "BSD-4-Clause", "BSD-3-Clause", "BSD-2-Clause", "BSD-1-Clause", "BSD-4-Clause-UC", "Unlicense", "Zlib", "Libpng", "Wtfpl-2.0", "OFL-1.1", "Edl-v10", "CCA-4.0", "0BSD", "CC0-1.0", "BSD-2-Clause-NetBSD", "Beerware", "PostgreSQL", "OpenSSL", "W3C", "HPND", "curl", "NTP", "WTFPL")
    #Medium Risk licenses require some action in order to use or modify the code in a deritive work
    $MedRiskLicenses = @("EPL-2.0", "MPL-1.0", "MPL-1.1", "MPL-2.0", "EPL-1.0", "CDDL-1.1", "AFL-2.1", "CPL-1.0", "CC-BY-4.0", "Artistic-2.0", "CC-BY-3.0", "AFL-3.0", "BSL-1.0", "OLDAP-2.8", "Python-2.0", "Ruby")
    #High Risk licenses often require actions that we may not be able to take, like applying a copyright on the deritive work or applying the same license to the deritive work
    $HighRiskLicenses = @("LGPL-2.0-or-later", "LGPL-2.1-or-later", "GPL-2.0-or-later", "GPL-2.0-only", "GPL-3.0-or-later", "GPL-2.0+", "GPL-3.0+", "LGPL-2.0", "LGPL-2.0+", "LGPL-2.1", "LGPL-2.1+", "LGPL-3.0", "LGPL-3.0+", "GPL-2.0", "CC-BY-3.0-US", "CC-BY-SA-3.0", "GFDL-1.2", "GFDL-1.3", "GPL-3.0", "GPL-1.0", "GPL-1.0+", "IJG", "AGPL-3.0", "CC-BY-SA-4.0")

    #determine all the license risk categories
    foreach ($lic in $alllicenses) {
        if ($LowRiskLicenses.Contains($lic)) {
            $LowRisk += $lic + "   "
        } elseif ($MedRiskLicenses.Contains($lic)) {
            $MedRisk += $lic + "   "
        } elseif ($HighRiskLicenses.Contains($lic)) {
            $HighRisk += $lic + "   "
        } else {
            $licstr += $lic + "   "
        }
    }

    #Print out all unique licenses found in the SBOM
    Write-Output "------------------------------------------------------------" | Out-File -FilePath $outfile -Append
    Write-Output "-   Low Risk Licenses found in this SBOM:  $LowRisk" | Out-File -FilePath $outfile -Append
    Write-Output "-   Medium Risk Licenses found in this SBOM:  $MedRisk" | Out-File -FilePath $outfile -Append
    Write-Output "-   High Risk Licenses found in this SBOM:  $HighRisk" | Out-File -FilePath $outfile -Append
    Write-Output "-   Unmapped Licenses found in this SBOM:  $licstr" | Out-File -FilePath $outfile -Append
    Write-Output "------------------------------------------------------------" | Out-File -FilePath $outfile -Append
}

function PrintVulnerabilities {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object[]]$allcomponents,
        [Parameter(Mandatory=$true)][object[]]$componentLocations
    )

    foreach($component in $allcomponents) {
        # Print the component name and version
        Write-Output "------------------------------------------------------------" | Out-File -FilePath $outfile -Append
        Write-Output "-   Component: $($component.name) $($component.version)" | Out-File -FilePath $outfile -Append
        Write-Output "------------------------------------------------------------" | Out-File -FilePath $outfile -Append

        foreach ($vuln in $component.Vulns) {
            # Print the vulnerability details
            # some vulnerabilities do not return a summary or fixed version
            Write-Output "Vulnerability: $($vuln.ID)" | Out-File -FilePath $outfile -Append
            Write-Output "Source: $($vuln.Source)" | Out-File -FilePath $outfile -Append
            if ($null -ne $($vuln.Summary)) {
                Write-Output "Summary: $($vuln.Summary)" | Out-File -FilePath $outfile -Append
            }
            Write-Output "Details:  $($vuln.Details)" | Out-File -FilePath $outfile -Append
            Write-Output "Fixed Version:  $($vuln.Fixed)" | Out-File -FilePath $outfile -Append
            if ($vuln.ScoreURI -ne "") {
                Write-Output "Score page:  $($vuln.ScoreURI)" | Out-File -FilePath $outfile -Append
            }

            if ($vuln.Score -ne "") {
                write-output "CVSS Breakdown:               $($vuln.Score)" | Out-File -FilePath $outfile -Append
                write-output "CVSS Attack Vector:           $($vuln.AV)" | Out-File -FilePath $outfile -Append
                write-output "CVSS Attack Complexity:       $($vuln.AC)" | Out-File -FilePath $outfile -Append
                write-output "CVSS Privileges Required:     $($vuln.PR)" | Out-File -FilePath $outfile -Append
                write-output "CVSS User Interaction:        $($vuln.UI)" | Out-File -FilePath $outfile -Append
                write-output "CVSS Scope:                   $($vuln.S)" | Out-File -FilePath $outfile -Append
                write-output "CVSS Confidentiality Impact:  $($vuln.C)" | Out-File -FilePath $outfile -Append
                write-output "CVSS Integrity Impact:        $($vuln.I)" | Out-File -FilePath $outfile -Append
                write-output "CVSS Availability Impact:     $($vuln.A)" | Out-File -FilePath $outfile -Append
                write-output "CVSS Severity:                $($vuln.Severity)" | Out-File -FilePath $outfile -Append
            }

            Write-Output "License info:  $($vuln.pkglicenses.license.id)" | Out-File -FilePath $outfile -Append
            Write-Output "" | Out-File -FilePath $outfile -Append
        }

        #In case the last package has multiple fixed versions, print the high water mark for fixed versions after all have been evaluated
        if ($component.Recommendation -ne "UNSET") {
            Write-Output "##############" | Out-File -FilePath $outfile -Append
            Write-Output "-   Recommended Version to upgrade to that addresses all $($component.name) $($component.version) vulnerabilities: $($component.Recommendation)" | Out-File -FilePath $outfile -Append
            Write-Output "##############" | Out-File -FilePath $outfile -Append
        }
    
    }

    # Now print out all components with vulnerabilities and where they were found
    Write-Output "=========================================================" | Out-File -FilePath $outfile -Append
    write-output "= List of all components with vulnerabilities and their SBOM file" | Out-File -FilePath $outfile -Append
    Write-Output "=========================================================" | Out-File -FilePath $outfile -Append
    Write-Output $componentLocations | Sort-Object -Property component, version | Format-Table | Out-File -FilePath $outfile -Append

}

function Get-VersionFromPurl {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)][string]$purl
    )

    if ($purl -like "*@*") {
        $parts = $purl.Split("@")
        return $parts[1]
    } else {
        return ""
    }
}

function Get-NameFromPurl {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)][string]$purl
    )

    if ($purl -like "*@*") {
        $parts = $purl.Split("@")
        $pieces = $parts[0].split("/")
        $name = $pieces.Count - 1
        return $pieces[$name]
    } else {
        return ""
    }
}
function Get-VulnList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][PSObject]$purls,
        [Parameter(Mandatory=$true)][string]$outfile,
        [Parameter(Mandatory=$true)][boolean]$ListAll
    )
    # this function reads through a list of purls and queries the OSV DB using the purl of each component to find all vulnerabilities per component.
    # for each vulnerability, it will collect the summary, deatils, vuln id, fixed version, link to CVSS score calculator, and license info
    # at the end of the component, as well as the recommended upgrade version if all vulnerabilities have been addressed in upgrades
    $fixedHigh = "UNSET"

    foreach ($purl in $purls) {
        # Build the JSON body for the OSV API query
        $body = @{
            "version" = Get-VersionFromPurl($purl)
            "package" = @{
                "purl" = $purl
            }
        } | ConvertTo-Json

        # Invoke the OSV API with the JSON body and save the response
        try {
            $response = Invoke-WebRequest -uri "https://api.osv.dev/v1/query" -Method POST -Body $body -UseBasicParsing -ContentType 'application/json'
        } catch {
            Write-Output "StatusDescription:" $_.Exception.Message
        }

        # Check if the response has any vulnerabilities
        if ($response.Content.length -gt 2) {
            $name = Get-NameFromPurl($purl)
            $version = Get-VersionFromPurl($purl)

            # build new object to store all properties
            $component = [PSCustomObject]@{
                Name = $name
                Version = $version
                Recommendation = ""
                Vulns = [System.Collections.ArrayList]@()
            }

            $vulns = $response.Content | ConvertFrom-Json

            # Loop through each vulnerability in the response
            foreach ($vulnerability in $vulns.vulns) {

                # build new object to store all properties
                $vuln = [PSCustomObject]@{
                    ID = $vulnerability.id
                    Summary = $vulnerability.summary
                    Details = $vulnerability.details
                    Source = "OSV"
                    Fixed = ""
                    Score = ""
                    AV = ""
                    AC = ""
                    PR = ""
                    UI = ""
                    S = ""
                    C = ""
                    I = ""
                    A = ""
                    ScoreURI = ""
                    Severity = ""
                }

                #build uri string to display calculated score and impacted areas
                if ($vulnerability | Get-Member "Severity") {
                    $vuln.Score = $vulnerability.severity[0].score
                    $vuln.AV = $vulnerability.severity[0].score.split("/")[1].split(":")[1]
                    $vuln.AC = $vulnerability.severity[0].score.split("/")[2].split(":")[1]
                    $vuln.PR = $vulnerability.severity[0].score.split("/")[3].split(":")[1]
                    $vuln.UI = $vulnerability.severity[0].score.split("/")[4].split(":")[1]
                    $vuln.S = $vulnerability.severity[0].score.split("/")[5].split(":")[1]
                    $vuln.C = $vulnerability.severity[0].score.split("/")[6].split(":")[1]
                    $vuln.I = $vulnerability.severity[0].score.split("/")[7].split(":")[1]
                    $vuln.A = $vulnerability.severity[0].score.split("/")[8].split(":")[1]

                    if ($vulnerability.severity.score.contains("3.0")) {
                        #CVSS 3.0
                        $scoreuri = "https://www.first.org/cvss/calculator/3.0#"
                        $vuln.ScoreURI = $scoreuri + $vulnerability.severity.score
                    } elseif ($vulnerability.severity.score.contains("3.1")) {
                        #CVSS 3.1
                        $scoreuri = "https://www.first.org/cvss/calculator/3.1#"
                        $vuln.ScoreURI = $scoreuri + $vulnerability.severity.score
                        $vuln.Score = Convert-CVSSStringToBaseScore $vulnerability.severity.score
                    } else {
                        #if this string shows up in any output file, need to build a new section for the new score version
                        $vuln.ScoreURI = "UPDATE CODE FOR THIS CVSS SCORE TYPE -> $vulnerability.severity.score"
                    }
                }

                #there can be multiple fixed versions, some based on hashes in the repo, you don't want that one
                foreach ($affected in $vulnerability.affected.ranges) {
                    try {
                        if (($affected.type -ne "GIT") -and ($null -ne $affected.events[1].fixed)) {
                            $fixed = $affected.events[1].fixed
                        }
                    } catch {
                        $fixed = "UNSET"
                    }
                }

                if (($fixed -eq "") -or ($null -eq $fixed)) {
                    $fixed = "UNSET"
                }
                $vuln.Fixed = $fixed
                $fixedHigh = Get-HighVersion -High $fixedHigh -Compare $fixed
                $component.Recommendation = $fixedHigh
                $component.Vulns.add($vuln) | Out-Null
            }

            #we only want to track components with vulnerabilities once, so only add components that we haven't seen yet in the big list
            if (Compare-Object -Ref $allvulns -Dif $component -Property Name, Version | Where-Object SideIndicator -eq '=>') {
                $allvulns.Add($component) | Out-Null
                $loc = [PSCustomObject]@{
                  "component" = $component.name;
                  "version" = $component.version;
                }
                foreach ($found in ($componentLocations | Where-Object { ($_.component -eq $loc.component) -and ($_.version -eq $loc.version)})) {
                    if (Compare-Object -Ref $vulnLocations -Dif $found -Property component, version, file | Where-Object SideIndicator -eq '=>') {
                        $vulnLocations.add($found) | Out-Null
                    }
                }
             } elseif (Compare-Object -Ref $componentLocations -Dif $component -Property component, version, file | Where-Object SideIndicator -eq '=>') { #but we need to know everywhere that component is found so each project can be fixed
                $loc = [PSCustomObject]@{
                    "component" = $component.name;
                    "version" = $component.version;
                }
                foreach ($found in ($componentLocations | Where-Object { ($_.component -eq $loc.component) -and ($_.version -eq $loc.version)})) {
                    if (Compare-Object -Ref $vulnLocations -Dif $found -Property component, version, file | Where-Object SideIndicator -eq '=>') {
                        $vulnLocations.add($found) | Out-Null
                    }
                }
            }

        } else {
            if ($ListAll) {
                Write-Output "OSV found no vulnerabilities for $purl licensed with $($pkglicenses.license.id)" | Out-File -FilePath $outfile -Append
            }
        }
    }

}

function Get-SBOMType {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)][string]$SBOM
    )

    if ($SBOM -like "*CycloneDX*") {
        Return "CycloneDX"
    } elseif ($SBOM -like "*SPDX*") {
        Return "SPDX"
    } else {
        Return "Unsupported"
    }

}

function Get-CycloneDXComponentList {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)][PSObject]$SBOM,
        [Parameter(Mandatory=$true)][PSObject]$allLicenses
    )

    $purlList = @()

    foreach ($package in $SBOM.components) {
        $type = $package.type
        $pkgLicenses = $package.licenses

        $found = $false
        #Pull out all the unique licenses found in the SBOM as you go. The full list will be printed together in the report.
        foreach ($license in $pkgLicenses) {
            foreach ($complicense in $allLicenses) {
                if ($complicense -eq $license.license.id) {
                    $found = $true
                }
            }
            if (!($found)) {
                if ($null -ne $license.license.id) {
                    $allLicenses += $license.license.id
                }
            } else {
                $found = $false
            }
        }

        if ($type -eq "library" -or $type -eq "framework") {
            # Get the component purl
            if ($package.purl -notin $allpurls) {
                $purlList += $package.purl
                $loc = [PSCustomObject]@{
                    "component" = Get-NameFromPurl -purl $package.purl;
                    "version" = Get-VersionFromPurl -purl $package.purl;
                    "file" = $file
                  }
                  $componentLocations.Add($loc) | Out-Null

            }
        } elseif ($type -eq "operating-system") {
            #OSV does not return good info on Operating Systems, just need to report OS and version for investigation
            $name = $package.name
            $version = $package.version
            $desc = $package.description

            # Print the OS name and version
            Write-Output "------------------------------------------------------------" | Out-File -FilePath $outfile -Append
            Write-Output "-   OS Name:  $name" | Out-File -FilePath $outfile -Append
            Write-Output "-   OS Version: $version" | Out-File -FilePath $outfile -Append
            Write-Output "-   OS Descriptiom:  $desc" | Out-File -FilePath $outfile -Append
            Write-Output "------------------------------------------------------------" | Out-File -FilePath $outfile -Append
        } else {
            #If this pops on the output, need to add code to query OSV for this ecosystem
            Write-Output "Not capturing $type"
        }
    }

    if ($PrintLicenseInfo) {
        Write-Output "------------------------------------------------------------" | Out-File -FilePath $outfile -Append
        Write-Output "-   SBOM File:  $file" | Out-File -FilePath $outfile -Append

        PrintLicenses($allLicenses)
    }

    Return $purlList
}

function Get-SPDXComponentList {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)][PSObject]$SBOM,
        [Parameter(Mandatory=$true)][PSObject]$allLicenses
    )

    $purlList = @()

    foreach ($package in $SBOM.packages) {
        $decLicense = $package.licenseDeclared
        $conLicense = $package.licenseConcluded

        $found = $false
        #Pull out all the unique licenses found in the SBOM as you go. The full list will be printed together in the report.
        foreach ($complicense in $allLicenses) {
            if (($complicense -eq $decLicense) -and ($decLicense -ne "NOASSERTION") -and ($null -ne $decLicense)) {
                $found = $true
            }
        }

        if (!($found) -and ($null -ne $decLicense)) {
            $allLicenses += $decLicense
        } else {
            $found = $false
        }

        $found = $false
        foreach ($complicense in $allLicenses) {
            if (($complicense -eq $conLicense) -and ($conLicense -ne "NOASSERTION") -and ($null -ne $conLicense)) {
                $found = $true
            }
        }

        if (!($found) -and ($null -ne $conLicense)) {
            $allLicenses += $conLicense
        } else {
            $found = $false
        }

        foreach ($refType in $package.externalRefs) {
            if ($refType.referenceType -eq "purl") {
                # Get the component purl
                if ($refType.referenceLocator -notin $allpurls) {
                    $purlList += $refType.referenceLocator
                    $loc = [PSCustomObject]@{
                        "component" = Get-NameFromPurl -purl $refType.referenceLocator;
                        "version" = Get-VersionFromPurl -purl $refType.referenceLocator;
                        "file" = $file
                      }
                      $componentLocations.Add($loc) | Out-Null

                }
            }
        }

    }

    if ($PrintLicenseInfo) {
        Write-Output "------------------------------------------------------------" | Out-File -FilePath $outfile -Append
        Write-Output "-   SBOM File:  $file" | Out-File -FilePath $outfile -Append

        PrintLicenses($allLicenses)
    }

    Return $purlList
}

function SBOMResearcher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$SBOMPath, #Path to a directory of SBOMs, or path to a single SBOM
        [Parameter(Mandatory=$true)][string]$wrkDir, #Directory where reports will be written, do NOT make it the same as $SBOMPath
        [Parameter(Mandatory=$false)][boolean]$ListAll=$false, #flag to write all components found in report, even if no vulnerabilities found
        [Parameter(Mandatory=$false)][boolean]$PrintLicenseInfo=$false #flag to print license info in report
    )

    #Begin main script
    if (get-item $wrkDir) {
       #dir exists
    } else {
        mkdir $wrkDir
    }

    $allLicenses = @()
    $allpurls = @()
    $allVulns=[System.Collections.ArrayList]@()
    $componentLocations=[System.Collections.ArrayList]@()
    $vulnLocations=[System.Collections.ArrayList]@()


    $argType = Get-Item $SBOMPath
    if ($argType.PSIsContainer) {
        #directory
        $outfile = $wrkDir + "\" + $argType.Parent.Name + "_report.txt"
        Write-Output "SBOMResearcher Report for Project: $($argType.Parent)" | Out-File -FilePath $outfile
        Write-Output "=====================================================================================" | Out-File -FilePath $outfile -Append
        Write-Output "" | Out-File -FilePath $outfile -Append

        #call Get-Vulns with each file in the directory
        #if files other than sboms are in the directory, this could cause errors
        #that's why it's best not to have the output dir the same as the sbom dir
        foreach ($file in $argtype.GetFiles()) {
            $SBOM = Get-Content -Path $file.fullname | ConvertFrom-Json
            $SBOMType = Get-SBOMType -SBOM $SBOM
            switch ($SBOMType) {
                "CycloneDX" { $allpurls += Get-CycloneDXComponentList -SBOM $SBOM -allLicenses $allLicenses }
                "SPDX" { $allpurls += Get-SPDXComponentList -SBOM $SBOM -allLicenses $allLicenses }
                "Unsupported" { Write-Output "This SBOM type is not supported" | Out-File -FilePath $outfile -Append }
            }
        }
            if ($null -ne $allpurls) {
                Get-VulnList -purls $allpurls -outfile $outfile -ListAll $ListAll
            }

            $allVulns | ConvertTo-Json -Depth 5 | Out-Null

            PrintVulnerabilities -allcomponents $allVulns -componentLocations $vulnLocations

        } else {
            #file
            $outfile = $wrkDir + "\" + $argtype.name.replace(".json","") + "_report.txt"
            Write-Output "Vulnerabilities found for Project: $($argtype.name)" | Out-File -FilePath $outfile
            Write-Output "=====================================================================================" | Out-File -FilePath $outfile -Append
            Write-Output "" | Out-File -FilePath $outfile -Append

            $SBOM = Get-Content -Path $SBOMPath | ConvertFrom-Json
            $SBOMType = Get-SBOMType -SBOM $SBOM
            $allpurls = @()
            switch ($SBOMType) {
                "CycloneDX" { $allpurls = Get-CycloneDXComponentList -SBOM $SBOM -allLicenses $allLicenses }
                "SPDX" { $allpurls = Get-SPDXComponentList -SBOM $SBOM -allLicenses $allLicenses }
                "Unsupported" { Write-Output "This SBOM type is not supported" | Out-File -FilePath $outfile -Append }
            }
            if ($null -ne $allpurls) {
                Get-VulnList -purls $allpurls -outfile $outfile -ListAll $ListAll
            }
            $allVulns | ConvertTo-Json -Depth 5 | Out-Null

            PrintVulnerabilities -allcomponents $allVulns -componentLocations $vulnLocations
    }
}

#SBOMResearcher -SBOMPath "C:\Temp\SBOMResearcher\sboms" -wrkDir "C:\Temp\SBOMResearcher\reports" -PrintLicenseInfo $true
