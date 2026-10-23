$ErrorActionPreference = 'Stop'
$setup = (Get-ChildItem build/windows-installer/*.msi).FullName
$target = "$env:LOCALAPPDATA/Programs/FluxDrop"
$p = Start-Process msiexec.exe -ArgumentList '/i',"`"$setup`"",'/qn','/norestart','/l*v',"`"$env:GITHUB_WORKSPACE/build/msi-install.log`"" -PassThru -Wait
if ($p.ExitCode -notin @(0,3010)) { Get-Content build/msi-install.log -Tail 80; throw "MSI install failed: $($p.ExitCode)" }
if (!(Test-Path "$env:APPDATA/Microsoft/Windows/Start Menu/Programs/FluxDrop/FluxDrop.lnk")) { throw 'Start menu shortcut missing' }
$p = Start-Process "$target/FluxDrop.exe" -ArgumentList '--self-test','--test-output',"$env:GITHUB_WORKSPACE/build/installed-qa" -PassThru -Wait
Get-Content build/installed-qa/windows-results.json
if ($p.ExitCode -ne 0) { throw 'Installed app tests failed' }
$p = Start-Process msiexec.exe -ArgumentList '/fa',"`"$setup`"",'/qn','/norestart' -PassThru -Wait
if ($p.ExitCode -notin @(0,3010)) { throw 'MSI repair failed' }
$p = Start-Process msiexec.exe -ArgumentList '/x',"`"$setup`"",'/qn','/norestart' -PassThru -Wait
if ($p.ExitCode -notin @(0,3010)) { throw 'MSI uninstall failed' }
if (Test-Path "$target/FluxDrop.exe") { throw 'MSI left the application executable after uninstall' }
if (Test-Path "$env:APPDATA/Microsoft/Windows/Start Menu/Programs/FluxDrop/FluxDrop.lnk") { throw 'MSI left its shortcut after uninstall' }
Get-FileHash $setup -Algorithm SHA256 | Format-List
