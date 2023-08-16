[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

function ProcessArtifact($artifact)
{
    if ($artifact.resource.type -ne "PipelineArtifact")
    {
        Write-Debug "Skipping non-PipelineArtifact"
        return
    }

    # Createing full artifact name similar to ArtifactAlias\Drop - this allows us to have multiple artifact aliases with the same "Drop" name (typically Drop because nothing was overridden).
    $artifactFullName = join-path $linkedArtifact.alias $artifact.name 
    Write-Verbose "Matching artificats to download against $artifactFullName";

    if ($artifactsToDownload -contains $artifactFullName)
    {
        $dropDestination = join-path $artifactDestinationFolder $($linkedArtifact.definitionReference.definition.name)
        $null = New-Item $dropDestination -ItemType Directory -Force #The null assignment avoids the output
    
        $dropArchiveDestination = Join-path $dropDestination ("{0}.zip" -f $artifact.name)
        Invoke-Download -downloadUri "$($artifact.resource.downloadUrl)" -destination $dropArchiveDestination -usedefaultcreds $usedefaultcreds

        Write-Verbose "Extracting file from $dropArchiveDestination to $dropDestination"
        if ($expandArchive)
        {
            Expand-Archive -LiteralPath $dropArchiveDestination -DestinationPath $dropDestination -Force
            Remove-Item $dropArchiveDestination -Force
        }
    }
    else
    {
        Write-Debug "Skipping Build Artifact $($artifact.name) as it does not match anything";
    }
}

try
{
    [string]$artifactNames = Get-VstsInput -Name artifactNames
    [string]$artifactDestinationFolder = Get-VstsInput -Name artifactDestinationFolder 
    [bool]$expandArchive = Get-VstsInput -Name expandArchive  -AsBool

	# Source functions
	. "$PSScriptRoot/Helpers.ps1"

    if (!$artifactDestinationFolder)
    {
        $artifactDestinationFolder = "$Env:SYSTEM_ARTIFACTSDIRECTORY"
    }

    $artifactsToDownload = $artifactNames.Split(";")
    if ($VerbosePreference -ne 'SilentlyContinue')
    {
        Write-Verbose "Artifact path to download for:"
        $artifactsToDownload | ForEach-Object { Write-Verbose $_ }
    }

    # Get the build and release details
    $collectionUrl = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
    $teamproject = $env:SYSTEM_TEAMPROJECT
    $releaseId = $env:RELEASE_RELEASEID
    $usedefaultcreds = $false;

    ### When running locally - make sure to comment before pushing!
    #$collectionUrl = "https://dev.azure.com/infosoftas";
    #$teamproject = "S4";
    #$releaseId = 13834
    #$usedefaultcreds = $false;

    $releaseInfo = Get-Release -tfsUri $collectionUrl -teamproject $teamproject -releaseid $releaseId -usedefaultcreds $usedefaultcreds

    foreach ($linkedArtifact in $releaseInfo.artifacts | Where-Object { $_.type -eq 'Build' } )
    {
        $buildId = $linkedArtifact.definitionReference.version.id;   
        $buildArtifacts = Get-BuildArtifacts -tfsUri $collectionUrl -teamproject $teamproject -usedefaultcreds $usedefaultcreds -buildid $buildId
        
        foreach ($artifact in $buildArtifacts)
        {
            ProcessArtifact $artifact
        }
    }

    # Not really sure these are actually needed
    Write-VstsSetResult -Result Succeeded -Message "Download Artifact Completed"
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}