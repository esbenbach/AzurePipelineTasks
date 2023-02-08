$env:BUILD_SOURCESDIRECTORY = "C:\Code\repos\s4\Framework"
$env:INPUT_PROJECTS = "**\SampleService.sln"
$env:INPUT_INCLUDETRANSITIVE = "true"
$env:INPUT_FAILONVULNERABLE = "false"
$env:INPUT_SOURCE = "https://api.nuget.org/v3/index.json"

$env:SYSTEM_DefaultWorkingDirectory = "C:\Code\repos\s4\Framework"
$env:SYSTEM_CULTURE = "en-GB"
$env:BUILD_ARTIFACTSTAGINGDIRECTORY = "C:\temp\randomcrap"

Write-Debug $PSScriptRoot
Set-Location $PSScriptRoot

Import-Module ./ps_modules/VstsTaskSdk
Invoke-VstsTaskScript -ScriptBlock { . ./vulnerablereport.ps1 }