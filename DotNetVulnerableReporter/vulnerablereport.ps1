using module './Helpers.psm1'

[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try
{
    [string]$projectPattern = Get-VstsInput -Name projects -Default "**/*.sln"
    [bool]$includeTransitive = Get-VstsInput -Name includeTransitive -AsBool
    [bool]$failOnVulnerable = Get-VstsInput -Name failOnVulnerable -AsBool
    [string]$source = Get-VstsInput -Name source # I only use this for debug

    $projects = Find-VstsMatch -Pattern $projectPattern

    foreach($currentProject in $projects)
    {
        $transitiveArg = ""
        if ($includeTransitive)
        {
            $transitiveArg = "--include-transitive"
        }

        $sourceArg = ""
        if ($source)
        {
            $sourceArg = "--source $source"
        }

        $dotnetArgs = "list $currentProject package --vulnerable $transitiveArg $sourceArg";
        $vulnerableOutput = Invoke-VstsTool -FileName dotnet -Arguments $dotnetArgs;
        $currentReport = Get-DotNetVulnerablilityReport -OutputLines $vulnerableOutput

        if ($currentReport[1])
        {
            $outputLocation = Write-ReportMarkdownFile $currentReport[1]
            Write-VstsUploadSummary -Path $outputLocation
        }
    }

    # TODO: Handle cases with more than one project in the pattern
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}

