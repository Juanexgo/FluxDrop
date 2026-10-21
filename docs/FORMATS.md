# Matriz de formatos

La matriz legible por máquina es `packages/release-manifest/capabilities.json`. La página /formatos se genera de ella. El campo verification diferencia comprobación real y pendiente. La presencia de una interfaz no acredita compatibilidad.

## Imágenes

ImageIO acepta imágenes raster reconocidas por el sistema. Exportaciones expuestas: JPEG, PNG, TIFF, BMP y HEIC solo si CGImageDestinationCopyTypeIdentifiers incluye su encoder. Se rechazan entradas multipágina/animadas; máximo 100 MP y lado 32768. Redimensionado a lado máximo hasta 16384, sin ampliar; crop proporcional, giros de 90°, reflejos, marcas de texto/imagen. JPEG aplana sobre blanco. Se normaliza orientación; raster RGB de 8 bits conservando el espacio compatible. HDR/profundidad superior no se conserva. Metadatos EXIF/IPTC/GPS se eliminan por defecto. Iconset exige imagen cuadrada de al menos 1024. WebP se exporta mediante libwebp 1.6.0 incorporado desde fuente: con pérdida o sin pérdida, sRGB de 8 bits, transparencia, máximo 16383 por lado y eliminación de metadatos obligatoria. AVIF usa ImageIO si anuncia un codificador disponible; se comprobó en macOS 26.3, no en macOS 14. La matriz image-routes.json registra 49 rutas de imagen efectivamente ejecutadas (siete entradas × siete salidas), incluidas reexportaciones al mismo formato; no demuestra todos los subtipos, perfiles ni animaciones.

## PDF

PDFKit: unir, extraer/reordenar rangos, separar, rotar, PNG por página, imágenes a PDF, texto existente. Vision OCR local produce TXT (no PDF con capa OCR). Compresión raster de 36–300 DPI: pierde texto seleccionable, vectores, formularios y enlaces; no garantiza menor tamaño. Máximo 10 000 páginas y 80 MP por render. Archivos cifrados necesitan contraseña y permiten extracción solo si sus permisos lo autorizan. No se ofrece PDF a Office.

## Multimedia

FFprobe inspecciona streams reales. Entradas decodificables de FFmpeg, no todas las combinaciones de extensiones y códecs. MP4 usa H.264 VideoToolbox con software permitido y AAC; MOV usa MPEG-4 y AAC. Salidas de audio: AAC/M4A, PCM/WAV, FLAC, MP3 (LAME 4.0) y Opus/Ogg (libopus 1.6.1). MP3/Opus admiten mono o estéreo y rechazan multicanal; Opus remuestrea a 48 kHz. GIF hasta 60 s, ancho máximo 960, 1–30 fps. Recorte temporal, resolución, quitar audio, metadatos, tamaño aproximado con informe final. Subtítulos SRT/VTT como pista mov_text, no quemados en el vídeo. HDR PQ/HLG se rechaza. Normalización single-pass loudnorm -16 LUFS, -1.5 dBTP, LRA11. Unión recodifica explícitamente a PCM 48 kHz estéreo.

## Datos y comprimidos

Texto máximo 16 MiB. UTF-8, UTF-16 o Latin-1 de entrada, UTF-8 de salida. CSV/TSV conserva campos como cadenas; cabeceras únicas para objetos JSON; no convierte silenciosamente números o estructuras anidadas en texto. YAML → JSON rechaza alias, anclas, claves complejas/duplicadas, timestamps y números no finitos o fuera de rango. Markdown HTML: títulos, párrafos, listas y bloques de código; HTML literal escapado. Markdown PDF: subconjunto Foundation/CoreText, sin recursos remotos.

ZIP/TAR/GZIP por libarchive. GZIP recibe un solo archivo. Extracción: máximo 10 000 entradas, 1 GiB expandido, relación máxima 200:1 con margen de 16 MiB. Rechaza rutas absolutas, traversal, enlaces, tipos especiales y nombres duplicados. Carpetas: SHA-256 en streaming, renombrado con preview y colisiones, organización por extensión en copias.

Multimedia verifica códec, duración y decodifica toda la salida. El intervalo de duración admite tolerancia por retardo/paquetes de códec; no es una promesa de exactitud a nivel de muestra para formatos con pérdida.
