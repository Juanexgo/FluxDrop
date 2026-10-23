# FluxDrop para Windows

La misma familia de producto y repositorio que macOS, con interfaz nativa WPF/C# y motores locales de Windows. No es una web envuelta ni ejecuta el binario de Mac.

Windows 11 22H2 o posterior, x64. .NET 10 se incluye en el instalador; no necesita Homebrew, Python ni una instalación previa de .NET. La distribución es de desarrollo y no lleva firma Authenticode. SmartScreen puede mostrar un aviso de editor desconocido; no desactives protecciones globalmente.

Desarrollo: `dotnet build apps/windows/FluxDrop.Windows -c Release`. En Mac puede compilarse con EnableWindowsTargeting, pero las pruebas de WPF/PDF/WinRT requieren Windows. El workflow Windows ejecuta pruebas allí antes de empaquetar.

Atajo predeterminado Ctrl+Alt+Space. El widget puede recibir archivos directamente y ejecutar sectores con clic o soltado. Clic derecho opcional, con Ctrl o siempre, sin consumir el menú contextual del sistema; puede solaparse con él. No intercepta la selección de Explorer ni promete capturar archivos antes de soltarlos. Escape cierra. Mover requiere revisión explícita y el mismo volumen. Las conversiones conservan originales.

El historial guarda rutas, operaciones, opciones y resultados en `%LOCALAPPDATA%/FluxDrop`; contraseñas PDF no se persisten. Puede borrarse y desactivarse. No hay analítica ni comprobación de actualizaciones. Procesamiento offline; OCR utiliza Tesseract y modelos tessdata_fast eng/spa seleccionables en el instalador (~8 MB). No requiere identidad MSIX ni descargas durante el trabajo. Configuración permite consultar su tamaño y eliminarlos; para restaurarlos se vuelve a ejecutar el instalador con OCR seleccionado.

## Diferencias que se deben publicar

No acreditar paridad total de formatos con macOS: ImageIO y VideoToolbox no existen en Windows. Imágenes WIC: JPEG/PNG/TIFF/BMP de un fotograma; salida WebP con motor. HEIC/AVIF requieren ampliar y verificar los motores. WebP se decodifica y exporta con FFmpeg/libwebp, rechazando animaciones. Exportación de imagen elimina metadatos siempre, transforma orientación y color a sRGB y aplana transparencia JPEG a blanco. PDFsharp 6.2.4 (MIT) maneja páginas; PDFium rasteriza y Tesseract 5.5.3 / Leptonica 1.87.0 reconocen texto. PdfPig 0.1.13 Apache-2.0 extrae texto existente, con contraseña y permisos de copia comprobados. MP4/MOV usan MPEG-4 Part 2 + AAC, no H.264. No hay aceleración hardware ni tone mapping HDR. La exactitud de OCR, lectores de pantalla y el gesto físico requieren pruebas manuales adicionales en equipos de usuario.

Presets son recetas de un paso; recetas versionadas admiten solo IDs registrados y opciones conocidas, sin comandos. Las recetas JSON de macOS no se importan automáticamente. Carpetas vigiladas no recorren subcarpetas, esperan estabilidad y acceso exclusivo de lectura, deduplican eventos y requieren destino fuera del origen. Ningún detector puede demostrar que un productor terminó de escribir si libera el archivo entre escrituras largas.

## Distribución y dependencias

FFmpeg 9.0.2 LGPL, sin GPL/nonfree/red; LAME 4.0 LGPL, Opus 1.6.1 BSD y libwebp 1.6.0 BSD. Configuración, avisos y scripts incluidos junto a los ejecutables. Los archivos fuente exactos se ofrecen como ZIP separado al lado del instalador en la misma web (enlace en engines/sources/SOURCES.txt). PDFsharp-WPF se fija en 6.2.4 MIT; no actualizar a 6.5+ sin revisar el cambio a AGPL/comercial. Markdig 0.41.3 BSD-2-Clause, YamlDotNet 16.3.0 MIT, runtime .NET MIT y avisos redistribuibles. No se descargan motores durante conversiones. Firma Authenticode requiere un certificado y proveedor de firma propios; no se incluyen claves.


Se eligió Tesseract para distribución directa después de comprobar en documentación oficial que Windows.Media.Ocr requiere identidad de paquete. No se oculta esa API detrás de un botón que falle en una instalación EXE. El build de Leptonica solo necesita entrada BMP; la app rasteriza PDF con Windows y convierte a BMP antes de reconocerlo. Tesseract/Leptonica se compilan estáticos sin libcurl ni libarchive. La única modificación a Tesseract es normalizar `Ws2_32` a `ws2_32` en CMake para MinGW/Linux; el script incluido reproduce ese cambio. Los modelos eng/spa de tessdata_fast se fijan al commit 87416418657359cb625c412a48b6e1d6d41c29bd y conservan licencia Apache-2.0.

Compartir usa el selector nativo de Windows y solo entrega los archivos a un destino elegido explícitamente. Esa app o servicio puede usar red; esto no forma parte del procesamiento local. Verificación manual del selector/entrega al destinatario pendiente.

Abre `apps/windows/FluxDrop.slnx` en Visual Studio con desarrollo de escritorio .NET 10, o usa el SDK de .NET. `scripts/build-windows.ps1` publica y prueba una app autocontenida con motores previamente compilados; no instala dependencias en el equipo del usuario. El workflow añade el empaquetado, las fuentes correspondientes y la prueba de instalación/desinstalación.


Referencias oficiales: [WinRT en escritorio .NET](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/winrt-apis-desktop-apps), [RegisterHotKey](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey), [Windows OCR y requisito de identidad](https://learn.microsoft.com/en-us/uwp/api/windows.media.ocr), [Windows Share para WPF](https://learn.microsoft.com/en-us/windows/apps/develop/windows-integration/integrate-sharesheet-send), [PDFsharp 6.2.4 MIT](https://www.nuget.org/packages/PDFsharp-WPF/6.2.4), [PdfPig](https://uglytoad.github.io/PdfPig/).

Render PDF final: PDFtoImage 5.4.0 (MIT), SkiaSharp 4.150.1 (MIT y avisos nativos) y bblanchon.PDFium.Win32 152.0.7961. DLL Windows comparada byte a byte con release chromium/7961; SHA-256, args.gn, VERSION y todas las licencias transitivas se incluyen en ThirdParty. V8 y XFA desactivados. Se reemplazó Windows.Data.Pdf al reproducirse un cierre anómalo en el runner; no se ignora un exit code por haber producido un PNG. La aceptación final exige salida limpia de la app instalada.

## Paquete MSI (2026-10-22)

La distribución principal pasa a MSI con asistente Windows Installer. Se genera con scripts/package-windows-msi.ps1 y WiX/UI 5.0.2 fijados desde NuGet. Features: núcleo obligatorio, OCR y escritorio opcionales; acceso Inicio, reparar y desinstalar. La prueba ejecutable vive en scripts/test-windows-msi.ps1. La fase MSI puede repetirse desde un payload previamente verificado con windows-msi.yml, que comprueba en la API de Actions que los pasos de núcleo y procesamiento nativo pasaron. No se confunde el MSI con el ejecutable FluxDrop.exe interno.

El instalador anterior Inno/EXE debe desinstalarse primero desde Aplicaciones; la condición de lanzamiento lo detecta. Los ajustes e historial permanecen en %LOCALAPPDATA%/FluxDrop. Desactiva inicio con sesión desde Ajustes antes de desinstalar si lo habías activado: esta versión MSI no elimina valores de inicio creados posteriormente por la app. Sin firma Authenticode; no se acredita navegación física del asistente por las pruebas silenciosas de msiexec.
