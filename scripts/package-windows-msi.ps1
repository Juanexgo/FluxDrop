param([string]$PublishDirectory = "$PSScriptRoot/../build/windows-publish", [string]$OutputDirectory = "$PSScriptRoot/../build/windows-installer")
$ErrorActionPreference = 'Stop'
$publish = (Resolve-Path $PublishDirectory).Path
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$out = (Resolve-Path $OutputDirectory).Path
if (!(Test-Path "$publish/FluxDrop.exe")) { throw 'Publish the self-contained app first' }
Copy-Item "$PSScriptRoot/WiX-5.0.2-LICENSE.txt" "$publish/ThirdParty/WiX-5.0.2-LICENSE.txt" -Force
function EscapeXml([string]$v) { [System.Security.SecurityElement]::Escape($v) }
$builder = [System.Text.StringBuilder]::new()
[void]$builder.AppendLine(@'
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs" xmlns:ui="http://wixtoolset.org/schemas/v4/wxs/ui">
<Package Name="FluxDrop" Manufacturer="FluxDrop" Version="0.4.0" Language="1034" Scope="perUser" UpgradeCode="862EDC84-6A3A-42E8-BA8D-965612D535E6">
<MajorUpgrade DowngradeErrorMessage="Ya tienes una versión más reciente de FluxDrop." />
<MediaTemplate EmbedCab="yes" CompressionLevel="high" />
<Property Id="OSBUILD"><RegistrySearch Id="WindowsCurrentBuild" Root="HKLM" Key="SOFTWARE\Microsoft\Windows NT\CurrentVersion" Name="CurrentBuildNumber" Type="raw" /></Property>
<Launch Condition="Installed OR (VersionNT64 AND OSBUILD &gt;= 22621)" Message="FluxDrop requiere Windows 11 22H2 o posterior, x64." />
<Property Id="LEGACYEXE"><RegistrySearch Id="LegacyExe" Root="HKCU" Key="Software\Microsoft\Windows\CurrentVersion\Uninstall\{B523C2B2-C06D-4D28-A27B-220242F1E938}_is1" Name="UninstallString" Type="raw" /></Property>
<Launch Condition="Installed OR NOT LEGACYEXE" Message="Desinstala primero la versión EXE de FluxDrop desde Configuración > Aplicaciones. Tus ajustes e historial se conservan." />
<Property Id="ARPCOMMENTS" Value="Versión de desarrollo sin firma. Procesamiento local." />
<Property Id="ARPURLINFOABOUT" Value="https://fluxdrop-ruby.vercel.app/windows/" />
<Icon Id="AppIcon" SourceFile="$(var.RepoRoot)\apps\windows\FluxDrop.Windows\Assets\FluxDrop.ico" />
<Property Id="ARPPRODUCTICON" Value="AppIcon" />
<StandardDirectory Id="LocalAppDataFolder"><Directory Id="ProgramsDir" Name="Programs"><Directory Id="INSTALLFOLDER" Name="FluxDrop" /></Directory></StandardDirectory>
<StandardDirectory Id="ProgramMenuFolder"><Directory Id="StartMenuDir" Name="FluxDrop" /></StandardDirectory>
<StandardDirectory Id="DesktopFolder" />
<DirectoryRef Id="StartMenuDir"><Component Id="Shortcuts" Guid="0ACAB56A-9A2C-40B3-97A9-F2BD75CA7406">
<Shortcut Id="StartMenuShortcut" Name="FluxDrop" Target="[INSTALLFOLDER]FluxDrop.exe" WorkingDirectory="INSTALLFOLDER" Icon="AppIcon" Advertise="no" />
<RemoveFolder Id="RemoveStartMenuDir" On="uninstall" />
<RegistryValue Root="HKCU" Key="Software\FluxDrop\Installer" Name="StartMenu" Type="integer" Value="1" KeyPath="yes" />
</Component></DirectoryRef>
<DirectoryRef Id="DesktopFolder"><Component Id="DesktopShortcut" Guid="40CEBA82-1032-499F-B845-CF4273550271">
<Shortcut Id="DesktopLink" Name="FluxDrop" Target="[INSTALLFOLDER]FluxDrop.exe" WorkingDirectory="INSTALLFOLDER" Icon="AppIcon" Advertise="no" />
<RegistryValue Root="HKCU" Key="Software\FluxDrop\Installer" Name="Desktop" Type="integer" Value="1" KeyPath="yes" />
</Component></DirectoryRef>
'@)
$core = [System.Collections.Generic.List[string]]::new(); $ocr = [System.Collections.Generic.List[string]]::new()
$index=0
foreach($f in (Get-ChildItem $publish -Recurse -File | Sort-Object FullName)) {
 $relative = [IO.Path]::GetRelativePath($publish,$f.FullName)
 $parent = Split-Path $relative -Parent
 $id = 'Payload'+$index; $index++
 $sub = if($parent){' Subdirectory="'+(EscapeXml $parent)+'"'}else{''}
 [void]$builder.AppendLine('<DirectoryRef Id="INSTALLFOLDER"><Component Id="'+$id+'" Guid="*"'+$sub+'><File Id="File'+$index+'" Source="'+(EscapeXml $f.FullName)+'" KeyPath="yes" /></Component></DirectoryRef>')
 if($relative -like 'engines\tessdata\*'){$ocr.Add($id)}else{$core.Add($id)}
}
[void]$builder.AppendLine('<Feature Id="Core" Title="FluxDrop y motores locales" Level="1" AllowAbsent="no" AllowAdvertise="no"><ComponentRef Id="Shortcuts" />')
foreach($id in $core){[void]$builder.AppendLine('<ComponentRef Id="'+$id+'" />')}
[void]$builder.AppendLine('</Feature><Feature AllowAdvertise="no" Id="OCR" Title="OCR local español e inglés (~8 MB)" Level="1">')
foreach($id in $ocr){[void]$builder.AppendLine('<ComponentRef Id="'+$id+'" />')}
[void]$builder.AppendLine('</Feature><Feature AllowAdvertise="no" Id="Desktop" Title="Acceso directo en el escritorio" Level="2"><ComponentRef Id="DesktopShortcut" /></Feature>')
[void]$builder.AppendLine('<ui:WixUI Id="WixUI_FeatureTree" /><WixVariable Id="WixUILicenseRtf" Value="$(var.RepoRoot)\scripts\installer-notice.rtf" /></Package></Wix>')
$wxs=Join-Path $out 'FluxDrop.wxs';[IO.File]::WriteAllText($wxs,$builder.ToString())
$root=(Resolve-Path "$PSScriptRoot/..").Path
& "$root/build/wix-tools/wix.exe" build $wxs -arch x64 -ext WixToolset.UI.wixext -culture es-ES -d "RepoRoot=$root" -o "$out/FluxDrop-0.4.0-windows-x64-dev.msi"
if($LASTEXITCODE -ne 0){throw 'MSI build failed'}
Get-FileHash "$out/FluxDrop-0.4.0-windows-x64-dev.msi" -Algorithm SHA256
