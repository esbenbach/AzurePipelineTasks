class VulnerabilityReport {
    [bool]$VulnerabilityDetected
    [int]$Critical
    [int]$High
    [int]$Moderate
    [int]$UnknownSeverity
    [hashtable]$Vulnerabilities
}

class Vulnerability
{
    [string]$PackageName
    [bool]$IsTransitive
    [string]$Severity
    [string]$VersionWithVulnerability
    [string]$AdvisoryUrl
}

function Get-VulnerablePackage
{
    [OutputType([Vulnerability])]
    param(
        [Parameter()]
        [string]$line
    )
    
    $vulnerability = [Vulnerability]::new();
    $columns = $line.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries);
    $vulnerability.PackageName = $columns[1].Trim();
    $vulnerability.VersionWithVulnerability = $columns[2].Trim();
    $vulnerability.Severity = $columns[3].Trim();
    $vulnerability.AdvisoryUrl = $columns[4].Trim();

    return $vulnerability
}

function Write-ReportMarkdownFile
{
    param(
        [Parameter()]
        [VulnerabilityReport]$report,
        [Parameter()]
        [string]$filename = "vulnerabilityreport.md"
    )
    
    $outputfile = Join-Path -Path "$Env:BUILD_ARTIFACTSTAGINGDIRECTORY" -ChildPath $filename

    if ($null -eq $report -or !$report.VulnerabilityDetected)
    {
        $content = "# NO KNOWN VULNERABILITIES FOUND"
        Set-Content -Path $outputfile -Value $content
        
    }
    else 
    {
        $header = "# KNOWN VULNERABILITIES DETECTED IN DEPENDENCIES" + [Environment]::NewLine
        
        $summaryLine = @"

## **Critical**: $($report.Critical)
## **High**: $($report.High)
## **Moderate**: $($report.Moderate)

Projects with vulnerabilities:

"@
    
        $tableHeader = "| Package | Version | Severity | Advisory URL |" + [Environment]::NewLine
        $tableRowDelimiter = "|---------|---------|----------|--------------|" + [Environment]::NewLine
    
        $content = $header + $summaryLine
    
        foreach($key in $report.Vulnerabilities.Keys)
        {
            $projectHeader = @"

## $key

"@
            $content += $projectHeader
            $content += $tableHeader
            $content += $tableRowDelimiter
            
            foreach($vulnerable in $report.Vulnerabilities[$key])
            {
                $urlText = "[$($vulnerable.AdvisoryUrl)]($($vulnerable.AdvisoryUrl))";
                $vulnerableRow = "|$($vulnerable.PackageName)|$($vulnerable.VersionWithVulnerability)|$($vulnerable.Severity)|$urlText|" + [Environment]::NewLine
                $content += $vulnerableRow
            }
    
            $content += [Environment]::NewLine;
        }
    
        Set-Content -Path $outputfile -Value $content
    }
    
    return $outputfile
}

function Get-DotNetVulnerablilityReport
{
    [CmdletBinding()]
    [OutputType([VulnerabilityReport])]
    param
    (
        [Parameter()]
        [string[]]$OutputLines
    )
    
    Trace-VstsEnteringInvocation $MyInvocation -Parameter None
    
    $allProjects = @{};
    $leadingString = '   > ';
    $currentProjectName;

    $report = [VulnerabilityReport]::new();
    $report.VulnerabilityDetected = $false;

    foreach ($line in $OutputLines)
    {
        if ($line.StartsWith('Project '))
        {
            $vulnerabilities = @();
            $currentProjectName = $line.Split('`')[1];
            $allProjects.Add($currentProjectName, $vulnerabilities);
        }
        elseif ($line.StartsWith($leadingString))
        {
            $report.VulnerabilityDetected = $true;
            [Vulnerability]$vulnerable = Get-VulnerablePackage $line
            $allProjects[$currentProjectName] += $vulnerable;
            
            switch ($vulnerable.Severity)
            {
                "Critical" { $report.Critical += 1 }
                "Moderate" { $report.Moderate += 1}
                "High"     { $report.High += 1 }
                Default    { $report.UnknownSeverity += 1 }
            }
        }
    }

    $report.Vulnerabilities = $allProjects;
    return $report;
}

Export-ModuleMember -Function @(
        'Write-ReportMarkdownFile'
        'Get-VulnerablePackage'
        'Get-DotNetVulnerablilityReport'
)