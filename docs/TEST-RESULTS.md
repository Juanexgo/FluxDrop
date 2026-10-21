# Resultados 0.2.0-dev — 20 de octubre de 2026

## Verificado en esta revisión

- Build Release de app completa con Swift 6 estricto: correcto. Incluye FFmpeg/ffprobe y libwebp estático.
- 34 pruebas XCTest, cero fallos y cero omitidas, 7.105 segundos de ejecución (no benchmark). Log: reports/native-tests.log.
- 36 rutas de imagen reales: JPEG, PNG, TIFF, HEIC, BMP y WebP como entradas y salidas. Cada exportación fue decodificada de nuevo, dimensiones 32 × 16 comprobadas y original comparado byte a byte. Fixture 80 × 40 generado en la prueba; incluye reexportaciones al mismo formato. Detalle reproducible en packages/release-manifest/image-routes.json y testAllImageExportRoutesAndOriginals. No equivale a 36 herramientas ni a cobertura universal de cada perfil/subtipo.
- WebP sin pérdida: estructura RIFF/WEBP y VP8L, alfa, rechazo de conservación de metadatos no soportada. Recorte: píxeles y dimensiones reales.
- PDF: orden, duplicación y rotación por página, reapertura, rechazo de ángulos inválidos y original conservado.
- Mover: rutas Unicode/espacios, colisiones previas, carrera de colisión y rollback. Gesto de arrastre: asignaciones únicas y máquina de estados de activación, sin acreditar permisos de macOS.
- Recorrido manual de la app: selector de archivos habilitado, apertura de imagen, recorte visual de mitad de ancho y alto, exportación a la cola con estado Verificado. Salida JPEG inspeccionada con sips: 320 × 180; original 640 × 360. Panel con selector Convertir/Editar/Archivos y seis acciones de archivo observado. Botón de estante invocado; su foco se corrigió posteriormente y no se volvió a acreditar visualmente.
- DMG 0.2: hdiutil verify, montado en solo lectura, firma ad hoc de app y helpers validada con codesign --verify --deep --strict, ffprobe ejecutado desde la imagen y desmontaje correcto. No se notarizó.

## Pendiente manual / externo

El controlador visual perdió la conexión al abrir Ajustes; un intento posterior de reconexión a la app agotó el tiempo de espera. La app compila, pero no se declara verificación interactiva final de preferencias, permisos ni gestos globales. Faltan arrastre desde Finder con los modificadores elegidos, clic derecho en otras apps, VoiceOver, varios monitores, persistencia por UI y recorrido completo de cada editor. Los controles de compartir solo abren el selector: no se envió ningún archivo.

No se ha probado físicamente macOS 14, Intel, equipo sin red, destino lleno o denegación real de permisos. Developer ID y notarización siguen pendientes. No hay evidencia para afirmar que FluxDrop sea más rápido o superior en todos los formatos que otra app. AVIF, MP3/Opus de salida, Office y actualizador firmado no están implementados.

Los registros históricos siguientes describen la revisión anterior y no sustituyen la evidencia 0.2. La comprobación de web y descarga 0.2 se registra por separado al publicar.

# Resultados reales — 20 de octubre de 2026

## Evidencia histórica 0.1

- macOS 26.3, Apple Silicon, Xcode 26.6/Swift 6.3.3.
- Build Debug y Release completados. Bundle completo con FFmpeg/ffprobe embebidos.
- 25 pruebas XCTest: 0 fallos, 0 omitidas; 8.993 segundos de ejecución (no benchmark).
- Imágenes: encoders disponibles, decode real, dimensiones, originales, colisiones, rutas Unicode/espacios, orientación, JPEG blanco, metadata GPS eliminada, crop/giro/marca de agua, entradas dañadas/vacías, cancelación previa.
- Cola: pendientes, pausa, lotes mixtos, reintento y recuperación de estados incompletos.
- PDF: páginas, unión, extracción, separación, raster PNG, texto generado, OCR y compresión reabierta.
- CSV/YAML: round trips y rechazo de alias/anclas, fechas, valores no finitos y duplicados. Corregida la vida útil del parser de Yams durante la validación de anchors.
- Multimedia: motores compilados, inspección, MP4/MOV/GIF/M4A/WAV/FLAC y unión; inspección de salida, duración de segmento y ancho; cancelación de un proceso realmente activo.
- ZIP/TAR/GZIP: round trip de bytes, validación de rutas peligrosas y rechazo de enlace de entrada. No equivale a una auditoría de todos los formatos maliciosos posibles.
- Recetas: composición, versión inválida, renombrado, error sin resultados parciales y conservación del original.
- Carpetas: SHA-256, preview/renombrado y estabilidad/deduplicación de eventos de watcher.
- DMG: hdiutil verify válido; montado en solo lectura; codesign --verify --deep --strict de app y helpers válido; ffprobe embebido ejecutado desde la imagen; desmontado correctamente.
- Web: Astro check sin errores/advertencias; build estático de 9 páginas; comprobación de enlaces locales, idioma, título, viewport y manifiesto. Recorrido en navegador de inicio, búsqueda FLAC (una fila también en producción) y descarga deshabilitada. El script de búsqueda se sirve como archivo externo compatible con CSP. Ancho de contenido igual al viewport a 390 y 1280 px. La matriz solo marca verificadas operaciones con cobertura representativa.
- Web pública desplegada correctamente: https://fluxdrop-ruby.vercel.app . Fuente enviada al repositorio de Sites antes de guardar/desplegar la versión.

- Widget configurable: cuatro pruebas nuevas validan persistencia mediante Codable, límites/versiones, coincidencia exacta de modificadores, parejas down/up y restablecimiento visual sin perder la activación. La app completa compila en Swift 6 estricto con el tap de sesión y la nueva vista.
- Recorrido manual previo a la sustitución final del panel: selección real de `coral ñ.png` desde el diálogo, conversión JPEG desde la ventana, estado Verificado, salida nueva inspeccionada con sips (640 × 360), arrastre de un resultado a la selección y visualización de la rueda anterior. Se corrigió la activación de diálogos y el botón principal que quedaba fuera del área visible.
- La compilación actual abrió la ventana principal y devolvió su árbol de accesibilidad con Añadir archivos, Convertir copias y cola. Esto no acredita aún todos los controles del widget.

## Implementado sin verificación visual final

Tras abrir la compilación actual, el controlador nativo perdió su conexión al intentar acceder a Ajustes (`native pipe closed before response`), incluso al reconectar/resetear. No se completó el recorrido visual del widget compacto final, sus ajustes interactivos ni el clic derecho global real. La prueba de la máquina de estados no demuestra que macOS autorice el tap ni que funcione en todas las apps. El estado de permisos se muestra en Ajustes y la opción global queda desactivada inicialmente.

Pendientes manuales: ajuste y persistencia a través de la UI, conversión desde el sector de la rueda final, gesto global en otra app con y sin modificadores, restauración del menú contextual al desactivar, arrastre desde Finder durante el gesto, teclado/VoiceOver, varios monitores y capturas reales del widget final. No se sustituyen esas capturas por mockups.

No se probó un Mac físicamente sin red, macOS 14, Intel, un volumen sin permisos ni un disco de destino lleno mediante conversiones. Se agotó el espacio durante el build Release; se limpiaron cachés temporales de este proyecto y el build posterior completó. No se eliminaron archivos del usuario.

## Distribución

Firma ad hoc validada. No hay certificado Developer ID Application disponible (solo identidad Apple Development). No se sometió a notarización. Gatekeeper se comprobó con spctl y devolvió rejected para esta firma ad hoc. El DMG de desarrollo no es el canal estable. stable.json conserva release:null. No se ejecutó una descarga pública del instalador estable porque todavía no existe.

Logs adjuntos: reports/native-tests.log, release-build.log, sign-check.log, dmg-verify.log y web-build.log. Los límites conocidos y pasos externos constan en LIMITATIONS.md y EXTERNAL-STEPS.md.

## Publicación independiente y descarga real

La web se publicó en https://fluxdrop-ruby.vercel.app desde GitHub. La revisión de desarrollo pasó Astro check, build de nueve páginas, enlaces, manifiestos y validación del binario durante build. GitHub Actions Web checks completó correctamente para f89e636. El despliegue de c433e8d figura como completado en Vercel. Se verificaron en el navegador el botón real de descarga, metadatos, SHA-256 y advertencia de firma ad hoc/sin notarización. Se descargó por HTTPS el DMG público: 35 719 951 bytes, SHA-256 efb28378da68a3e7ef3e365dc0d13bfb6bce6a7e8e72d9b3398524119eb9872b; coinciden exactamente con el manifiesto y el artefacto local verificado. Ver reports/public-download.json. stable.json permanece release:null.

## Web 0.2 — validación local

Astro check: cero errores, advertencias o hints. Build de producción: nueve páginas. scripts/check-web.mjs: enlaces internos, manifiestos estable/desarrollo, enlace y tamaño de instalador, unicidad de rutas e inclusión de la matriz de cobertura correctos. El build calcula el SHA-256 del DMG real y lo compara con development.json.
