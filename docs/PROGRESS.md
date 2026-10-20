# Registro de avances

- Fase 1: base SwiftUI/AppKit, menú, panel, hotkey público, motor de imágenes y cola. Pruebas iniciales representativas realizadas.
- Fase 2: PDFKit/Vision, FFmpeg/ffprobe propios, progreso, cancelación, presets/historial y preview Quick Look.
- Fase 3: recetas versionadas, watcher, CSV/JSON/YAML/Markdown, libarchive seguro, renombrado y duplicados.
- Fase 4: páginas Astro, matriz canónica, manifiesto validado, DMG y scripts Developer ID/notarytool. Publicación estable dependiente de credenciales y artefacto público.
- Corrección de referencia: el menú circular corresponde a la app; la web conserva identidad propia.
- Según instrucción del usuario, la revisión integral se concentró al final de la implementación. Se corrigieron errores de concurrencia/accessibility, YAML y empaquetado encontrados.
- Revisión final: 21 tests aprobados; Release y DMG verificados. La automatización visual quedó bloqueada por el controlador del entorno. Ver TEST-RESULTS.md para evidencia y pendientes, sin declarar todo el alcance verificado.

- Widget configurable: sustituido el panel rectangular por rueda flotante compacta. Ajustes de tamaño, tema, acento, opacidad, etiquetas, pista, favoritos y cierre; persistencia versionada local. Activación global opcional con botón derecho solo/Opción/Control mediante API pública. Estado real de permisos y desactivación accesible desde menú.
- Comprobación de esta revisión: Release completo y DMG generado/verificado; 25 XCTest sin fallos (8.993 s). Recorrido manual de conversión de la ventana y arrastre de resultados completado antes de la última sustitución del panel. El controlador de pantalla perdió conexión después; el gesto global y los ajustes visuales finales siguen pendientes de prueba manual.

- Publicación independiente: app y web subidas al repositorio privado Juanexgo/FluxDrop en main. Añadido workflow web con acciones fijadas a commits y permisos mínimos, configuración Vercel y política de cabeceras. El build de nueve páginas y la validación local pasaron. Despliegue Vercel pendiente por 403 de acceso al equipo juanexgos-projects, solicitado al titular reconectar la integración.
