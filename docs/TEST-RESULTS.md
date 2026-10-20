# Resultados reales — 20 de octubre de 2026

## Verificado

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
- Web pública desplegada correctamente: https://fluxdrop-mac.juanjosecanulpasos.chatgpt.site . Fuente enviada al repositorio de Sites antes de guardar/desplegar la versión.

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
