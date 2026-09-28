$ErrorActionPreference = 'Stop'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    & dotnet --version
    if ($LASTEXITCODE -ne 0) { throw 'The SDK from global.json is required.' }
    & dotnet run --project OpenDictate.Checks -c Release
    if ($LASTEXITCODE -ne 0) { throw 'Offline checks failed.' }
    & dotnet build OpenDictate.Prototype -c Release
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
    Write-Output 'Offline checks and Windows build passed. Interactive acceptance has not been run by this script.'
} finally { Pop-Location }

& dotnet build (Join-Path $PSScriptRoot '../OpenDictate.BrowserHost') -c Release
if ($LASTEXITCODE -ne 0) { throw 'Browser host build failed.' }

& dotnet build (Join-Path $PSScriptRoot '../OpenDictate.WindowsChecks') -c Release
if ($LASTEXITCODE -ne 0) { throw 'Windows protection checks build failed.' }
# Run this executable in the signed-in desktop; it uses only synthetic data and
# a fresh, isolated dummy credential, never the real OpenAI entry.
