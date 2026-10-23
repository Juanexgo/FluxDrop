#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${FLUXDROP_APP_OUTPUT:-/private/tmp/fluxdrop-package/FluxDrop.app}"
OUT="${FLUXDROP_RELEASE_OUTPUT:-$ROOT/build/releases}"
[ -d "$APP" ] || { echo 'Build the complete app with its engines first' >&2; exit 1; }
codesign --verify --deep --strict "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
mkdir -p "$OUT"
STAGE="$(mktemp -d /private/tmp/fluxdrop-pkg.XXXXXX)"
cleanup() {
  python3 - "$STAGE" <<'PY_CLEAN'
from pathlib import Path
import sys,shutil
p=Path(sys.argv[1])
if p.parent==Path('/private/tmp') and p.name.startswith('fluxdrop-pkg.') and not p.is_symlink():shutil.rmtree(p)
PY_CLEAN
}
trap cleanup EXIT
mkdir -p "$STAGE/root/Applications" "$STAGE/resources/es.lproj" "$STAGE/resources/en.lproj"
ditto --norsrc --noextattr "$APP" "$STAGE/root/Applications/FluxDrop.app"
pkgbuild --analyze --root "$STAGE/root" "$STAGE/components.plist"
python3 - "$STAGE/components.plist" <<'PY'
import sys,plistlib
p=sys.argv[1]
with open(p,'rb') as f:d=plistlib.load(f)
def configure(items):
 for x in items:
  x['BundleIsRelocatable']=False;x['BundleIsVersionChecked']=True;x['BundleOverwriteAction']='upgrade'
  configure(x.get('ChildBundles',[]))
configure(d)
with open(p,'wb') as f:plistlib.dump(d,f)
PY
pkgbuild --root "$STAGE/root" --component-plist "$STAGE/components.plist" --identifier local.fluxdrop.installer --version "$VERSION" --install-location / --ownership recommended "$STAGE/FluxDrop-component.pkg"
cat > "$STAGE/Distribution.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
<title>FluxDrop</title>
<options customize="never" require-scripts="false" hostArchitectures="arm64" />
<domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="true" />
<volume-check><allowed-os-versions><os-version min="14.0" /></allowed-os-versions></volume-check>
<welcome file="welcome.html" mime-type="text/html" />
<conclusion file="conclusion.html" mime-type="text/html" />
<choices-outline><line choice="app" /></choices-outline>
<choice id="app" visible="false" title="FluxDrop"><pkg-ref id="local.fluxdrop.installer" /></choice>
<pkg-ref id="local.fluxdrop.installer" version="$VERSION" onConclusion="none">FluxDrop-component.pkg</pkg-ref>
</installer-gui-script>
XML
cat > "$STAGE/resources/es.lproj/welcome.html" <<'HTML'
<!doctype html><html lang="es"><meta charset="utf-8"><body style="font-family:-apple-system"><h1>Instalar FluxDrop</h1><p>El asistente copiará FluxDrop y sus motores locales a Aplicaciones. Puedes instalar para tu usuario o para todos los usuarios del Mac.</p><p>macOS 14 o posterior · Apple Silicon.</p><p>Versión de desarrollo: el paquete no está firmado con Developer ID Installer ni notarizado. La aplicación tiene firma ad hoc. macOS puede bloquear la instalación o apertura.</p><p>Cierra FluxDrop antes de actualizar. Se conservan los ajustes y el historial. No se instalan servicios, extensiones ni tareas en segundo plano.</p></body></html>
HTML
cat > "$STAGE/resources/es.lproj/conclusion.html" <<'HTML'
<!doctype html><html lang="es"><meta charset="utf-8"><body style="font-family:-apple-system"><h1>FluxDrop está instalado</h1><p>Abre FluxDrop desde la carpeta Aplicaciones elegida durante la instalación. Añade archivos y selecciona una carpeta de salida.</p><p>Para desinstalar, cierra la app y envíala a la Papelera. El historial y los ajustes se administran desde la app. No se han modificado tus archivos.</p></body></html>
HTML
cat > "$STAGE/resources/en.lproj/welcome.html" <<'HTML'
<!doctype html><html lang="en"><meta charset="utf-8"><body style="font-family:-apple-system"><h1>Install FluxDrop</h1><p>This wizard installs FluxDrop and its offline engines in Applications, for your account or all users. Requires macOS 14 and Apple Silicon.</p><p>Development package: unsigned and not notarized; the app is ad hoc signed. macOS may block installation or launch.</p><p>Quit FluxDrop before updating. Settings and history are preserved. No background services or system extensions are installed.</p></body></html>
HTML
cat > "$STAGE/resources/en.lproj/conclusion.html" <<'HTML'
<!doctype html><html lang="en"><meta charset="utf-8"><body style="font-family:-apple-system"><h1>FluxDrop is installed</h1><p>Open FluxDrop from the Applications folder you selected. Add files and select an output folder.</p><p>To uninstall, quit the app and move it to Trash. Manage history and settings inside the app.</p></body></html>
HTML
PKG="$OUT/FluxDrop-$VERSION-arm64-dev.pkg"
productbuild --distribution "$STAGE/Distribution.xml" --package-path "$STAGE" --resources "$STAGE/resources" "$PKG"
pkgutil --payload-files "$PKG" > "$PKG.payload.txt"
(cd "$OUT" && shasum -a 256 "$(basename "$PKG")") > "$PKG.sha256"
echo "$PKG"
