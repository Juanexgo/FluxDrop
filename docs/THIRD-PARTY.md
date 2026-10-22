# Componentes y avisos

- Swift y frameworks Apple: SDK del sistema; no se redistribuye el SDK.
- libarchive del sistema `/usr/lib/libarchive.2.dylib`: licencia BSD; enlazado dinámicamente, no se incorpora un ejecutable externo. Declaraciones C mínimas en Sources/CArchive.
- Yams 6.2.2, MIT, con libyaml incorporado (MIT): aviso completo en third-party/Yams-LICENSE.txt y licencia de libyaml del checkout copiada al paquete.
- FFmpeg 9.0.2 y ffprobe: compilación propia sin GPL, nonfree, autodetect ni red. Se habilitan VideoToolbox, AudioToolbox y zlib del sistema. Configuración y versiones exactas en build/engines/{buildconf,version,license}.txt. Fuente original, LICENSE.md y COPYING.LGPLv2.1 se incluyen en Resources/ThirdParty del bundle. `scripts/build-ffmpeg.sh` permite reconstruir y sustituir los ejecutables; una app modificada necesita volver a firmarse localmente.
- Astro y TypeScript son herramientas de la web. El inventario exacto está fijado en package-lock.json; no se incorporan en el bundle nativo.

La compilación concreta de FFmpeg debe revisarse antes de venta: obligaciones LGPL, licencias de componentes y patentes de códecs dependen del uso y jurisdicción. No se afirma una autorización comercial universal. No se incluye x264/x265 ni una descarga binaria de terceros. [Criterios oficiales de FFmpeg](https://ffmpeg.org/legal.html).

Marca, textos y panel de FluxDrop son propios. La referencia visual aportada se usó para la idea de interacción circular, sin reutilizar marca ni recursos de Tangerine.

- libwebp 1.6.0, código C incorporado estáticamente. Fuente oficial fijada en commit `4fa21912338357f89e4fd51cf2368325b59e9bd9`; subconjunto y SHA-256 por archivo en `apps/macos/Vendor/WebP/UPSTREAM.json`. Licencia BSD y concesión de patentes originales en `third-party/WebP-{COPYING,PATENTS,AUTHORS}.txt`, también incluidas en el bundle. No requiere Homebrew ni descarga al convertir. Fuente: https://chromium.googlesource.com/webm/libwebp/

## Audio incorporado en 0.3

FFmpeg 9.0.2 se reconstruyó con `--enable-libmp3lame --enable-libopus`, conservando `--disable-gpl --disable-nonfree --disable-network --disable-autodetect`. LAME 4.0: biblioteca estática, frontend y decoder deshabilitados, LGPL 2 o posterior; avisos COPYING y LICENSE originales incluidos. SHA-256 del tar oficial: 3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb. libopus 1.6.1: biblioteca estática, sin documentación ni programas extra, avisos BSD y concesiones de patentes upstream incluidos; SHA-256 6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1. Los tar originales de ambos se distribuyen con FFmpeg en Resources/ThirdParty. Sin modificaciones al código de los motores. La app no enlaza con FFmpeg: ejecuta helpers sustituibles con argumentos estructurados. El script permite reconstruir los ejecutables con bibliotecas modificadas; no se prohíbe la ingeniería inversa necesaria para depurar cambios.

`pkg-config` es una herramienta de compilación, no se incorpora al producto ni se necesita en el Mac del usuario. Configuración y dependencias dinámicas reales en los archivos buildconf/linkage incluidos. Revisión comercial de la compilación concreta sigue pendiente.


## Inventario de Windows 0.4

- .NET 10 Desktop Runtime, WPF/WinForms/WinRT: MIT y avisos redistribuibles recogidos del paquete utilizado por el runner; instalación autocontenida.
- PDFsharp-WPF **6.2.4**, MIT; fijado antes del cambio AGPL/comercial de 6.5. Aviso original exacto incluido.
- PdfPig **0.1.13**, Apache-2.0; commit baeac0d0c344e543ed8b277eac3edd8f8b9c1ac4. LICENSE y NOTICES exactos incluidos.
- YamlDotNet **16.3.0**, MIT; Markdig **0.41.3**, BSD-2-Clause. Avisos originales incluidos.
- Microsoft.Extensions.Logging.Abstractions / DependencyInjection.Abstractions: transitivos de PDFsharp, MIT; versiones efectivas se muestran en el log del workflow y avisos se copian del paquete restaurado.
- FFmpeg **9.0.2**, LGPL 2.1+; LAME **4.0**, LGPL 2+; Opus **1.6.1**, BSD; libwebp **1.6.0**, BSD/PATENTS. Compilación Windows diferente de Apple: sin VideoToolbox/AudioToolbox/GPL/nonfree/red; fuentes con hashes y configuración exacta en ZIP público correspondiente. Sustitución por ejecutables compatibles permitida.
- Tesseract **5.5.3**, Apache-2.0; Leptonica **1.87.0**, BSD. Compilación estática, sin curl/libarchive, entrada BMP. Archivos originales con hash; modificación reproducida en script: corrección de mayúsculas de `Ws2_32` para MinGW/Linux.
- tessdata_fast eng/spa, Apache-2.0, commit **87416418657359cb625c412a48b6e1d6d41c29bd**. Modelos opcionales en instalador; licencia conservada; reconocimiento local.
- Inno Setup **6**, compilador disponible en runner Windows; retiene avisos en el instalador. No es un motor ni se ejecuta durante conversiones. Los logs indican su versión exacta.

GCC/MinGW, CMake, pkg-config y CSharpier 1.3.0 son herramientas de compilación/formato; no se instalan en el equipo del usuario. Los ejecutables MinGW se inspeccionan para dependencias; las licencias de runtime/compiler se deben volver a revisar si cambia la configuración. No hay obligación de Homebrew para usuarios de Windows ni Mac.

Render PDF final: PDFtoImage 5.4.0 (MIT), SkiaSharp 4.150.1 (MIT y avisos nativos) y bblanchon.PDFium.Win32 152.0.7961. DLL Windows comparada byte a byte con release chromium/7961; SHA-256, args.gn, VERSION y todas las licencias transitivas se incluyen en ThirdParty. V8 y XFA desactivados. Se reemplazó Windows.Data.Pdf al reproducirse un cierre anómalo en el runner; no se ignora un exit code por haber producido un PNG. La aceptación final exige salida limpia de la app instalada.
