function Get-WebClient {
    [CmdletBinding()]
    [OutputType([System.Net.WebClient])]
    param(
        [bool]$useDefaultCredentials
    )

    # When debugging locally, this variable can be set to use personal access token.
    $debugpat = $env:PAT

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $webclient = new-object System.Net.WebClient
    $webclient.Encoding = [System.Text.Encoding]::UTF8

    if ([System.Convert]::ToBoolean($useDefaultCredentials) -eq $true) {
        Write-Verbose "Using default credentials"
        $webclient.UseDefaultCredentials = $true
    }
    elseif ([string]::IsNullOrEmpty($debugpat) -eq $false) {
        $encodedPat = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$debugpat"))
        $webclient.Headers.Add("Authorization", "Basic $encodedPat")
    }
    else {
        Write-Verbose "Using SystemVssConnection personal access token (requires pipeline permission)"
        $vstsEndpoint = Get-VstsEndpoint -Name SystemVssConnection -Require
        $webclient.Headers.Add("Authorization" ,"Bearer $($vstsEndpoint.auth.parameters.AccessToken)")
    }

    return $webclient
}

function Invoke-GetCommand {
    [CmdletBinding()]
    param
    (
        $uri,
        $usedefaultcreds
    )

    $webclient = Get-WebClient $usedefaultcreds
    Write-Verbose "Calling $uri"
    $webclient.DownloadString($uri)
}

function Wait-ForTask {
    param (
        [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        $task
    )

    process {
        while (-not $task.AsyncWaitHandle.WaitOne(200)) { }
        $task.GetAwaiter().GetResult()
    }
}

function Invoke-Download
 {
    [CmdletBinding()]
    param
    (
        $downloadUri,
        $destination,
        $usedefaultcreds
    )
    $webclient = Get-WebClient $usedefaultcreds
    Write-Verbose "Downloading file from ($downloadUri) to path ($destination) "

    try {
        $webclient.DownloadFileTaskAsync($downloadUri, $destination) | Wait-ForTask
    }
    catch {
        Write-Error $_.Exception.InnerException.InnerException
    }
}

function Get-BuildArtifacts
{
    param
    (
        [Parameter(Mandatory=$true)]$tfsUri,
        [Parameter(Mandatory=$true)]$teamproject,
        [Parameter(Mandatory=$true)]$buildid,
        $usedefaultcreds
    )

    $buildUrl = "$collectionUrl/$teamproject/_apis/build/builds/$buildId"  
    $uri = "$buildUrl/artifacts?api-version=7.0"
    
    Write-Verbose "Getting artifact information from $uir"
    $jsondata = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds | ConvertFrom-Json
    $jsondata.value
}

function Get-Release {

    param
    (
        $tfsUri,
        $teamproject,
        $releaseid,
        $usedefaultcreds
    )

    Write-Verbose "Getting details of release [$releaseid] from server [$tfsUri/$teamproject]"

    $rmtfsUri = Convert-ToReleaseAPIURL -uri $tfsUri

    # This is an old API call, but leaving it to provide historic TFS support
    $uri = "$($rmtfsUri)/$($teamproject)/_apis/release/releases/$($releaseid)?api-version=7.0"

    Write-Verbose "Using the URL [ $uri ]"
    $result = Invoke-GetCommand -uri $uri -usedefaultcreds $usedefaultcreds
    
    $jsondata = $result | ConvertFrom-Json
    return $jsondata
}

function Convert-ToReleaseAPIURL {
    [OutputType([string])]
    param
    (
         [string]$uri
    )

    Write-Verbose "Converting URL for API from $uri "
    # Fixup VisualStudio.com API untill they fix it so its not a separate URL
    $uri = $uri -replace ".visualstudio.com", ".vsrm.visualstudio.com/defaultcollection"

    # Fixup dev.azure.com API untill they fix it so its not a separate URL
    $uri = $uri -replace "dev.azure.com", "vsrm.dev.azure.com"
    Write-Verbose "Converting URL for API to $uri "
    return $uri
}