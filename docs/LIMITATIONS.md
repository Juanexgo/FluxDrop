# Limitaciones conocidas

Esta entrega no equivale a haber completado todos los formatos posibles del documento inicial. No se ocultan los límites detrás de controles simulados.

- AVIF de salida no disponible; MP3/Opus de salida tampoco se anuncian. PDF a Office fuera de alcance inicial.
- Firma Developer ID, notarización, publicación de instalador estable y actualizador firmado requieren pasos externos. Sparkle evaluado, no implementado.
- Arm64 construido; Intel y macOS 14 necesitan verificación propia.
- El widget aparece con un atajo registrado (tres combinaciones disponibles), con activación adicional por modificador durante arrastre (opcional), o con el gesto de clic derecho global opcional y configurable. La captura depende de la autorización de macOS; no importa la selección de Finder automáticamente. La selección de sectores se sugiere por extensión; el motor valida contenido real al ejecutar. Un lote mixto produce resultado o error explícito por archivo; no hay omisión silenciosa.
- Pausar cola afecta tareas pendientes. ImageIO y algunas llamadas PDFKit no se interrumpen dentro de una única llamada.
- Panel no intercepta arrastres globales ni lee el origen antes de que entren en él. Restricciones de apps origen y Spaces deben verificarse manualmente.
- OCR produce texto; PDF rasterizado pierde elementos interactivos. HDR multimedia rechazado; imágenes se rasterizan a 8 bits.
- Destinos de archivos requieren hardlinks para publicación sin sobrescritura: APFS/HFS+; exFAT no está soportado por ese mecanismo.
- Carpetas vigiladas usan diez segundos de estabilidad: una copia que se detenga más tiempo podría procesarse prematuramente. No se recorren subcarpetas; archivos fallidos requieren reintento manual. Se ignoran nombres con -fluxdrop.
- Renombrar copias es el último paso recomendado de receta. Límites conservadores de CSV/YAML/archivos se documentan en FORMATS.
- Cierre forzado puede dejar temporales; las tareas incompletas se marcan interrumpidas. No hay limpieza indiscriminada ni reanudación automática de motores.
