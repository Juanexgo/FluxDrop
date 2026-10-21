# FluxDrop para Windows

La misma familia de producto y repositorio que macOS, con interfaz nativa WPF/C# y motores locales de Windows. No es una web envuelta ni ejecuta el binario de Mac.

Windows 11 22H2 o posterior, x64. .NET 10 se incluye en el instalador; no necesita Homebrew, Python ni una instalación previa de .NET. La distribución es de desarrollo y no lleva firma Authenticode. SmartScreen puede mostrar un aviso de editor desconocido; no desactives protecciones globalmente.

Desarrollo: `dotnet build apps/windows/FluxDrop.Windows -c Release`. En Mac puede compilarse con EnableWindowsTargeting, pero las pruebas de WPF/PDF/WinRT requieren Windows. El workflow Windows ejecuta pruebas allí antes de empaquetar.

Atajo predeterminado Ctrl+Alt+Space. El widget puede recibir archivos directamente y ejecutar sectores con clic o soltado. Clic derecho opcional, con Ctrl o siempre, sin consumir el menú contextual del sistema; puede solaparse con él. No intercepta la selección de Explorer ni promete capturar archivos antes de soltarlos. Escape cierra. Mover requiere revisión explícita y el mismo volumen. Las conversiones conservan originales.

El historial guarda rutas, operaciones, opciones y resultados en `%LOCALAPPDATA%/FluxDrop`; contraseñas PDF no se persisten. Puede borrarse y desactivarse. No hay analítica ni comprobación de actualizaciones. Procesamiento offline; OCR requiere que Windows tenga instalado el idioma elegido. Instalar idiomas es una acción separada en Configuración de Windows.

## Diferencias que se deben publicar

No acreditar paridad total de formatos con macOS: ImageIO y VideoToolbox no existen en Windows. Imágenes WIC: JPEG/PNG/TIFF/BMP de un fotograma; salida WebP con motor. HEIC/AVIF y decodificación WebP requieren ampliar y verificar los motores. Exportación de imagen elimina metadatos siempre, transforma orientación y color a sRGB y aplana transparencia JPEG a blanco. PDFsharp 6.2.4 (MIT) maneja páginas; Windows.Data.Pdf rasteriza y Windows.Media.Ocr reconoce texto. Extracción de texto PDF existente todavía no incluida. MP4/MOV usan MPEG-4 Part 2 + AAC, no H.264. No hay aceleración hardware ni tone mapping HDR. OCR y el gesto físico deben validarse en equipos Windows reales con los idiomas instalados.

Presets son recetas de un paso; recetas versionadas admiten solo IDs registrados y opciones conocidas, sin comandos. Las recetas JSON de macOS no se importan automáticamente. Carpetas vigiladas no recorren subcarpetas, esperan estabilidad y acceso exclusivo de lectura, deduplican eventos y requieren destino fuera del origen. Ningún detector puede demostrar que un productor terminó de escribir si libera el archivo entre escrituras largas.

## Distribución y dependencias

FFmpeg 9.0.2 LGPL, sin GPL/nonfree/red; LAME 4.0 LGPL, Opus 1.6.1 BSD y libwebp 1.6.0 BSD. Fuentes exactas, configuración y script incluidos junto a los ejecutables. PDFsharp-WPF se fija en 6.2.4 MIT; no actualizar a 6.5+ sin revisar el cambio a AGPL/comercial. Markdig 0.41.3 BSD-2-Clause, YamlDotNet 16.3.0 MIT, runtime .NET MIT y avisos redistribuibles. No se descargan motores durante conversiones. Firma Authenticode requiere un certificado y proveedor de firma propios; no se incluyen claves.
