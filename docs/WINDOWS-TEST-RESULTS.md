# Verificación de Windows 0.4.0-dev

Fecha de trabajo: 2026-10-21 (America/Merida). Entorno local: macOS arm64 / .NET SDK 10.0.301; no se ejecuta WPF en Mac.

## Aceptación final aprobada

[Run Windows 39701573768](https://github.com/Juanexgo/FluxDrop/actions/runs/39701573768), commit `500c74fe62d9bb753c4cdd92938230d60aa41fca`: éxito. Runner Windows 2025 x64, .NET SDK 10.0.402 y runtime 10.0.13.

- 29 pruebas del núcleo y 27 pruebas nativas aprobadas.
- Instalador generado, instalado y probado: otras 27 pruebas aprobadas sobre la aplicación instalada, salida limpia y desinstalación correcta.
- Se reabrieron o decodificaron las salidas para comprobar dimensiones, páginas, transparencia, duración e integridad; no basta la existencia del archivo.
- Cobertura representativa: imágenes, PDF cifrado/render/OCR, multimedia, datos, archivos comprimidos seguros, recetas, cancelación del árbol de procesos y cola de 500 trabajos pendientes. Render de interfaz con fixtures en Windows.
- Motores FFmpeg/LAME/Opus/WebP compilados desde fuentes verificadas: run 39694595107, éxito. OCR Tesseract/Leptonica y modelos eng/spa: run 39697373976, éxito.

Instalador `FluxDrop-0.4.0-windows-x64-dev-setup.exe`: 91 605 779 bytes; SHA-256 `338974674c8d07331ed307a3d321b080e55488263a22fb15946ac483f6a72b1c`.
Fuentes de motores `FluxDrop-0.4.0-windows-engine-sources.zip`: 48 316 679 bytes; SHA-256 `bfbb88af2acfa57132171e30e13207f62188136328b3c7e6baaa51f754d03e86`. ZIP completo comprobado por CRC. Incluye fuentes de FFmpeg/LAME/Opus/WebP/Tesseract/Leptonica, configuración y scripts; la procedencia y licencias de PDFium se inventarían por separado en ThirdParty.

El directorio de certificados PE es (0, 0): **sin firma Authenticode**. Es una distribución de desarrollo, no una versión estable firmada. macOS 0.3 no se modificó.

## Casos que detectaron errores reales y sus correcciones

- PDFsharp no permite consultar PageCount después de guardar un documento: ahora se captura antes y se reabre el PDF guardado para verificarlo.
- Recorte de audio unido debe validarse contra la secuencia completa, no la primera entrada.
- FFmpeg Windows sin zlib no decodificaba PNG intermedio para WebP. Se usa BGRA sin compresión, preservando alfa y validando la transparencia en el roundtrip.
- Procesos externos no capturan el contexto UI; se drenan stdout/stderr y se mata el árbol al cancelar.
- El renderizador WinRT de PDF provocaba un fallo nativo al cerrar el proceso: sustituido por PDFium, comprobando salida limpia también después de instalar.
- El buffer BGRA de WebP se congela antes de cruzar continuaciones async para evitar acceso WPF desde otro hilo.
- Harness WPF usa el dispatcher real y cierra sus ventanas; no se ignoran códigos de salida anómalos.

## Pendientes manuales y alcance

No se acredita clic derecho físico durante un arrastre, selección global de Explorer, entrega de Windows Share, lectores de pantalla, varios monitores físicos, Windows 11 22H2 real, ARM64 nativo, disco lleno o denegación real de permisos. No se afirma firma Authenticode. HEIC/AVIF y H.264/hardware/HDR no se anuncian como soportados; MP4/MOV usan MPEG-4 Part 2. Duplicados genera informe SHA-256, sin eliminación. Recetas Mac y Windows no se importan automáticamente.

Los render PNG son capturas del contenido WPF ejecutado en un runner Windows con fixtures, no fotografías de una sesión de usuario ni una prueba de gestos físicos.
