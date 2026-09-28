[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory=$true)][string]$SourceRoot)
$ErrorActionPreference='Stop'
$source=(Resolve-Path -LiteralPath $SourceRoot).Path
$manifest=Get-Content -LiteralPath (Join-Path $source 'browser-prototype\manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($manifest.host_permissions).Count -ne 1 -or $manifest.host_permissions[0] -ne 'http://127.0.0.1/*') {
    throw 'This installer authorizes only local browser fixture pages.'
}
if (@(Compare-Object @('nativeMessaging','scripting') @($manifest.permissions)).Count -ne 0) {
    throw 'Unexpected extension permissions.'
}
$publicKey=[Convert]::FromBase64String($manifest.key)
$sha=[Security.Cryptography.SHA256]::Create()
try {$digest=$sha.ComputeHash($publicKey)} finally {$sha.Dispose()}
$hex=([BitConverter]::ToString($digest)).Replace('-','').ToLowerInvariant().Substring(0,32)
$alphabet='abcdefghijklmnop'
$id=-join ($hex.ToCharArray() | ForEach-Object {$alphabet[[Convert]::ToInt32($_.ToString(),16)]})
$declared=(Get-Content -LiteralPath (Join-Path $source 'browser-prototype\extension-id.txt') -Raw).Trim()
if ($id -ne $declared) {throw 'Public extension identity mismatch.'}
$archiveHash=(Get-Content -LiteralPath (Join-Path $source '.source-archive-sha256') -Raw).Trim()
if ($archiveHash -notmatch '^[a-f0-9]{64}$') {throw 'Missing source archive identity.'}
$hostSource=Join-Path $source 'OpenDictate.BrowserHost\bin\Release\net10.0-windows'
if (!(Test-Path (Join-Path $hostSource 'OpenDictate.BrowserHost.exe'))) {throw 'Browser host is not built.'}
$destination=Join-Path $env:LOCALAPPDATA ('OpenDictatePrototype\BrowserBridge\'+$archiveHash.Substring(0,12))
$registry='HKCU:\Software\Google\Chrome\NativeMessagingHosts\de.opendictate.prototype'
if (Test-Path $destination) {throw 'Browser package target exists; preserve and inspect it before updating.'}
if (Test-Path $registry) {throw 'Native messaging registration already exists; preserve and inspect it.'}
$origin='chrome-extension://'+$id+'/'
Write-Output ('Extension: '+$manifest.name)
Write-Output ('Page access: '+$manifest.host_permissions[0])
Write-Output ('Local package: '+$destination)
Write-Output ('Per-user registration: '+$registry)
if (!$PSCmdlet.ShouldProcess($destination,'Copy the bounded browser test package and register its local host for this user')) {return}
$extension=Join-Path $destination 'extension'
$hostDestination=Join-Path $destination 'host'
New-Item -ItemType Directory -Path $extension,$hostDestination | Out-Null
Get-ChildItem -LiteralPath $hostSource -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $hostDestination }
foreach ($name in @('manifest.json','background.js','content.js','insertion-core.js','extension-id.txt')) {
    Copy-Item -LiteralPath (Join-Path $source ('browser-prototype\'+$name)) -Destination $extension
}
[IO.File]::WriteAllText((Join-Path $hostDestination 'allowed-origin.txt'),$origin)
$hostManifest=Join-Path $destination 'native-host.json'
$hostJson=@{name='de.opendictate.prototype';description='OpenDictate local browser prototype';path=(Join-Path $hostDestination 'OpenDictate.BrowserHost.exe');type='stdio';allowed_origins=@($origin)} | ConvertTo-Json
[IO.File]::WriteAllText($hostManifest,$hostJson,(New-Object Text.UTF8Encoding($false)))
New-Item -Path $registry -Force | Out-Null
Set-Item -Path $registry -Value $hostManifest
@{SourceArchive=$archiveHash;ExtensionId=$id;ExtensionDirectory=$extension;HostManifest=$hostManifest;Registry=$registry} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'installation.json') -Encoding UTF8
Write-Output ('Host registered. Extension files ready for the approved isolated Chrome profile: '+$extension)
