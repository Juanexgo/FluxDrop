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

- Vercel publicado desde la sesión web autorizada: https://fluxdrop-ruby.vercel.app . Verificación HTTP, cabeceras, canonical, búsqueda de formatos y página de descarga completada. Se añadió descarga de desarrollo real, separada del canal estable, con comprobación de tamaño y SHA-256 durante build. No se afirma firma Developer ID ni notarización.

- Descarga pública de desarrollo comprobada desde Vercel: DMG completo de 35 719 951 bytes y SHA-256 coincidente con el local. Página actualizada y observada con botón activo, versión 0.1.0-dev, requisitos y estado ad hoc/sin notarizar. La versión estable no se ha activado.

## 20 octubre — revisión 0.2

Completado build Release: tres modos del widget, activación opcional por modificador durante arrastre con tap pasivo, seis acciones de archivo, estante de referencias, mover con revisión y rollback, editores visuales de imagen/PDF/multimedia/compresión, BMP y WebP real (libwebp 1.6.0 BSD incorporado). Matriz de 36 rutas de imagen obtenida de ejecuciones reales; 34 XCTest pasaron. Recorte manual exportó 320 × 180 y cola Verificado. DMG verificado y firmado ad hoc. No se habilita canal estable ni se promete paridad de 275 rutas. Persisten pruebas manuales de permisos/gestos, mínimo macOS y firma/notarización externas.

0.2 publicado en GitHub/Vercel; CI web correcto, nueve rutas públicas y descarga completa con SHA-256 coincidente. Matriz y búsqueda revisadas en navegador.

## 20 octubre — revisión 0.3

Implementados MP3/Opus desde fuentes oficiales, AVIF condicionado a ImageIO, paginación real de rueda, intercambio de teclas, decodificación completa de verificación y corrección de recorte de audio unido. 39 pruebas finales pasaron, ocho fixtures hostiles rechazados y 49 rutas de imagen comprobadas en macOS 26.3. Conversión AVIF manual desde rueda: Verificado, 640 × 360. El titular confirmó que no tiene membresía Apple Developer; no se realizaron pagos ni notarización. Pendientes las comprobaciones manuales globales y hardware/OS alternativos.

Comprobación ampliada: 43 tests pasaron sobre el código de producción 0.3; iconset, PDF cifrado y operaciones PDF/datos/Markdown antes pendientes comprobadas. Estados y límites individuales de la matriz corregidos. Instalador y fuentes públicos descargados completos y checksum coincidente.

Añadida sección web de Acciones de archivos inspirada en la referencia aportada, con diseño e iconos propios, seis tarjetas y rueda explicativa. Ratón, Enter, estado accesible y anchos 390/1280 comprobados. Se identificó expresamente como representación, sin procesamiento web ni promesa de gesto global ya validado.

## 2026-10-21 · Windows nativo

Se añade apps/windows al monorepo sin reemplazar la app de Mac: solución .NET 10 con Core, WPF/WinRT y pruebas. Widget radial con sectores curvos, atajo global configurable y conflicto, clic derecho opcional no invasivo, ventana, bandeja, cola recuperable, recetas, vigilancia, historial y salida segura. Imágenes WIC/WebP, PDFsharp/PdfPig, render Windows, OCR Tesseract local, FFmpeg audio/vídeo, datos y comprimidos con límites.

Los motores Windows se compilan desde fuentes fijadas; se prepara instalador EXE autocontenido por usuario y ZIP separado de fuentes correspondientes. La página de descarga incorpora plataformas y manifiestos separados. No se habilita el enlace Windows antes de una aceptación completa del instalador. Evidencia y fallos reales corregidos: WINDOWS-TEST-RESULTS.md.

## Windows 0.4 — aceptación final, 2026-10-21

App nativa WPF, motores locales, instalador autocontenido y fuentes correspondientes completados. CI Windows 39701573768 aprobó 29 pruebas de núcleo, 27 nativas y otras 27 después de instalar; cierre y desinstalación correctos. Web incorpora descarga Windows separada de Mac, matriz real y capturas del runner. Distribución de desarrollo sin firma; límites y pruebas manuales pendientes en WINDOWS-TEST-RESULTS.md.

## Claridad de descargas — 2026-10-22

Ambas tarjetas identifican su instalador real: DMG para Mac y EXE para Windows, con instrucciones de instalación para cada sistema. Se conservan las versiones, binarios, checksums y avisos de firma existentes.

## Instaladores reales — 2026-10-22

Tras la aclaración del titular, se preparó PKG macOS y MSI Windows, no solo etiquetas. PKG instalado realmente en ~/Applications y comparado por SHA-256 (31 archivos). MSI aceptado en run 39877218730: instalación, 27 tests sobre app instalada, reparación, desinstalación y accesos. Wiki de pruebas y límites en INSTALLER-TEST-RESULTS.md. Nuevo repositorio público FluxDrop-Releases dedicado solo a artefactos y avisos; fuente Mac/Windows en el mismo monorepo anterior. Web ofrece los nuevos paquetes y conserva los avisos de firma pendientes.
