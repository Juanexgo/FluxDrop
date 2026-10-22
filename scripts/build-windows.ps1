param([string]$EngineDirectory = "$PSScriptRoot/../build/windows-engines", [switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path "$PSScriptRoot/..").Path
if (-not $IsWindows) { throw 'Run on Windows 11 with .NET 10 SDK. A Mac can cross-compile the csproj but cannot run the WPF checks.' }
foreach($tool in @('ffmpeg.exe','ffprobe.exe','tesseract.exe')) { if(!(Test-Path "$EngineDirectory/$tool")) { throw "Missing $tool. Build pinned engines with the documented GitHub workflows; no engine is downloaded by the app." } }
$canonical = "$taskRoot/build/windows-engines"
if((Resolve-Path $EngineDirectory).Path -ne (Resolve-Path $canonical -ErrorAction SilentlyContinue).Path){New-Item -ItemType Directory -Force $canonical | Out-Null;Copy-Item "$EngineDirectory/*" $canonical -Recurse -Force}
Push-Location $taskRoot
try {
  if(!$SkipTests){dotnet run --project apps/windows/FluxDrop.Tests -c Release;if($LASTEXITCODE -ne 0){throw 'Core tests failed'}}
  dotnet publish apps/windows/FluxDrop.Windows -c Release -r win-x64 --self-contained true -p:DebugType=embedded -o build/windows-publish
  if($LASTEXITCODE -ne 0){throw 'Publish failed'}
  if(!$SkipTests){$p=Start-Process build/windows-publish/FluxDrop.exe -ArgumentList '--self-test','--test-output',"$taskRoot/build/windows-qa" -PassThru -Wait;if($p.ExitCode -ne 0){throw 'Windows tests failed; inspect build/windows-qa/windows-results.json'}}
  Write-Host 'Verified app in build/windows-publish. See docs/WINDOWS.md for installer and signing.'
} finally {Pop-Location}
