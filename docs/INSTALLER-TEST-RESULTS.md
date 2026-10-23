# Instaladores nativos — 2026-10-22

## macOS PKG

`FluxDrop-0.3.0-arm64-dev.pkg`, construido con pkgbuild/productbuild de Apple a partir de la misma app 0.3.0 verificada. macOS 14+, arm64. Asistente ES/EN, destinos Aplicaciones del usuario o del sistema. Sin scripts de instalación, servicios, extensiones ni lanzamiento automático. No relocaliza instalaciones al buscar otras copias de la app. Respeta versiones superiores y reemplaza atómicamente el bundle al actualizar.

Verificado en este Mac: estructura XAR y payload; firma ad hoc de la app antes/después; los 31 archivos extraídos e instalados son idénticos por SHA-256 al bundle original. `installer -dominfo` y `-showChoicesXML` acreditan selección habilitada y ambos dominios. Instalación real con `installer -pkg … -target CurrentUserHomeDirectory` en `~/Applications/FluxDrop.app`; recibo `~/Library/Receipts/local.fluxdrop.installer.plist`, versión 0.3.0; registro de Installer finaliza instalación correctamente. ffmpeg/ffprobe instalados ejecutan y declaran 9.0.2. No había app previa en ese destino.

46 579 745 bytes, SHA-256 `9f0fbe0994863ccdbd65260b76fc19bb22bf4c56ae1183cb4d385c9971c18421`.

`pkgutil --check-signature`: sin firma del paquete. App con firma ad hoc, sin notarización. No se dispone de membresía Apple Developer; Developer ID Installer/Application y notarización siguen pendientes. La instalación CLI local no demuestra que Gatekeeper acepte un paquete descargado. No se desactivaron protecciones. El controlador UI expiró al solicitar abrir la app instalada; no se acredita apertura visual ni navegación manual del asistente. No se verificó instalación del sistema con administrador ni una actualización sobre una versión previa.

## Windows MSI

113 447 948 bytes, SHA-256 `e64ab8c04156b415cd1675c07fdc261d9d69e956cc347d4d612f9537e7ad5eca`. Paquete OLE/Windows Installer, no EXE renombrado. Sin firma aplicada en el pipeline. Se aloja como asset de GitHub Releases en Juanexgo/FluxDrop-Releases porque supera los 100 MiB de un archivo en Git; la app y web permanecen en el monorepo privado.

Aceptación aprobada: [run 39877218730](https://github.com/Juanexgo/FluxDrop/actions/runs/39877218730), commit baafbe0. MSI construido en Windows; instalación silenciosa por usuario con msiexec, acceso en Inicio comprobado, 27 pruebas de la app instalada aprobadas con salida limpia, reparación /fa y desinstalación /x correctas. Se comprobó que no quedaran ejecutable ni acceso Inicio. El payload proviene de 39876883396: 29 pruebas de núcleo y 27 nativas pasaron; ese run falló únicamente al compilar el MSI por un atributo de WiX 3 incompatible con WiX 5, posteriormente corregido. No se acredita un recorrido manual del asistente ni todas las combinaciones de features. El MSI conserva la aplicación nativa y todos sus motores; no es un enlace a un EXE ni un bootstrapper que descargue componentes. OCR y acceso de escritorio son features seleccionables. Un componente obligatorio crea acceso en Inicio. No modifica datos de usuario al desinstalar. Detecta la distribución Inno anterior y pide desinstalarla explícitamente antes de continuar para evitar dos administradores de instalación sobre la misma carpeta.

WiX 5.0.2 y UI 5.0.2 fijados desde NuGet; licencia MS-RL incluida. Esta versión histórica no añade contratos de mantenimiento de WiX 6+. No se contrató soporte ni pagos. Fuente exacta: https://github.com/wixtoolset/wix/tree/aa65968c419420d32e3e1b647aea0082f5ca5b78 . La validación y seguridad de futuras versiones de WiX debe revisarse antes de un lanzamiento estable.

## Publicación de los artefactos

https://github.com/Juanexgo/FluxDrop-Releases/releases/tag/v0.4-installers es una prerelease pública con PKG, MSI, sus checksums y licencia WiX. `node scripts/verify-installer-downloads.mjs` descargó ambos paquetes completos por HTTPS sin autenticación: formato XAR/OLE correcto, tamaños, SHA-256 y sidecars coincidentes. El código de ambas plataformas y la web siguen en Juanexgo/FluxDrop; el repositorio nuevo contiene únicamente distribución y avisos.
