# Distribución directa

1. Ejecutar build de motores y app Release. Ejecutar pruebas finales; revisar docs/TEST-RESULTS.md.
2. `scripts/package-dmg.sh` crea DMG con FluxDrop.app y enlace Applications, más SHA-256. Por sí solo produce una compilación de desarrollo ad hoc; no publicar como estable.
3. Para distribución: certificado Developer ID Application y membresía Apple Developer del propietario. Crear perfil de notarytool en Keychain. Exportar DEVELOPER_ID con nombre de identidad y NOTARY_PROFILE con nombre de perfil (no contraseña). Ejecutar scripts/sign-and-notarize.sh. Firma helpers y app con hardened runtime, somete app/DMG, exige Accepted, adjunta tickets y valida Gatekeeper.
4. Publicar DMG y notas en alojamiento HTTPS del propietario. Preparar candidato conforme packages/release-manifest/schema.json con versión, fecha, macOS mínimo, arquitecturas, URL, tamaño y SHA-256.
5. `node scripts/publish-manifest.mjs candidate.json build/releases/notarization-proof.json` descarga de nuevo el artefacto publicado y exige tamaño/checksum y notas accesibles antes de modificar stable.json. No usar prueba de notarización de otro archivo.
6. Reconstruir/publicar web desde el mismo estado de fuente. El botón está deshabilitado con release:null; no enlaza una descarga ficticia.

El script solo prepara el flujo; las credenciales y resultados reales son requisitos externos. Nunca guardar certificados, claves privadas, passwords o tokens en Git. No se ha configurado un canal beta.

## Actualizaciones

Sparkle evaluado, no incorporado en esta versión. Requiere feed HTTPS, firma Ed25519 y claves privadas protegidas, junto a firma/notarización. No basta con comparar versiones en JSON. Antes de incorporarlo se deben probar dos versiones, firma inválida, fallo de red y actualización desde DMG montado. [Documentación de Sparkle](https://sparkle-project.org/documentation/).

## Mac App Store

No es el canal de este bundle. Requeriría sandbox, bookmarks security-scoped, revisión de carpetas vigiladas, integración del helper, firma de tienda y revisión de licencias. No reutilizar este empaquetado asumiendo compatibilidad. [Notarización Apple para distribución directa](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).


## Windows directo

Workflow `Windows engines` produce FFmpeg/ffprobe x64 LGPL desde fuentes con hash y sin GPL/nonfree/red. Workflow `Windows OCR engines` compila Tesseract/Leptonica estáticos y fija los modelos eng/spa por commit. `Windows build and verification` recibe los dos run IDs, ejecuta pruebas en Windows, publica .NET self-contained, genera un instalador por usuario con Inno Setup 6 y verifica instalación, ejecución instalada y desinstalación.

Artefactos separados: EXE para instalar; ZIP con fuentes exactas, configuración, licencias y scripts de motores. El instalador conserva avisos y el enlace a esas fuentes; no necesita ese ZIP para funcionar. Se publican ambos antes de activar el manifiesto `windows.json`, que lleva requisitos, fecha, versión, tamaño, SHA-256 y firma real. `publish-windows-download.mjs` prepara las entradas después de comprobar los artefactos. La web vuelve a comprobar tamaño y SHA-256 al compilar.

Windows 0.4 es de desarrollo, **sin Authenticode**. SmartScreen puede advertir o bloquear. Para una distribución firmada se requiere un certificado/proveedor de firma válido del titular, proteger sus claves fuera del repositorio, firmar binarios/instalador, timestamp y comprobar `Get-AuthenticodeSignature` y `signtool verify /pa`. La firma no garantiza reputación SmartScreen inmediata. No instalar certificados raíz propios ni desactivar SmartScreen como procedimiento de distribución. No se ha comprado ni solicitado un certificado.

## PKG y MSI (2026-10-22)

`scripts/package-pkg.sh` crea un asistente PKG macOS ES/EN para la app completa ya construida y firmada ad hoc. Destinos por usuario o sistema. Developer ID Installer sería necesario para firmar el paquete; no confundir firma de app con firma de PKG. `scripts/publish-macos-pkg.mjs` solo publica el artefacto verificado y su hash. El DMG previo se conserva como archivo histórico.

`scripts/package-windows-msi.ps1` genera un MSI autocontenido con WiX 5.0.2/UI 5.0.2: por usuario, motores locales, OCR y escritorio opcionales, acceso Inicio, reparación y desinstalación Windows Installer. Los ejecutables internos son parte normal de la app; la descarga principal es un paquete MSI. Una instalación anterior de Inno/EXE debe retirarse desde Aplicaciones para evitar conflictos. Authenticode sigue pendiente; no se llama estable a ninguna entrega.

La prueba real de instalación y los límites constan en INSTALLER-TEST-RESULTS.md.

Los nuevos PKG/MSI se alojan en GitHub Releases público (Juanexgo/FluxDrop-Releases), separado del repositorio privado de fuentes. Los manifiestos solo aceptan URLs de ese repositorio y extensiones PKG/MSI correctas; un build estático valida esquema/enlaces y los artefactos locales conservados. Ejecutar `node scripts/verify-installer-downloads.mjs` en la publicación para descargar completos los artefactos remotos y validar formato, bytes, SHA-256 y sidecars; no se presenta un mero HEAD como comprobación de integridad.
