# Guía de pruebas

Ejecutar scripts/test-macos.sh en Mac. Los tests usan fixtures temporales pequeños y reabren/decodifican salidas; no basta con fileExists. La suite cubre imágenes, conservación, colisiones, orientación/transparencia, cancelación previa, cola/reinicio, CSV/YAML, PDF/OCR, archivos, recetas, renombrado, duplicados, watchers y conversiones multimedia mediante los helpers construidos.

Generar fixtures visuales con `swift scripts/generate-fixtures.swift fixtures`. Pruebas manuales finales: abrir bundle completo, seleccionar imagen, convertir y revelar resultado, panel radial por atajo, soltar archivos desde Finder, Escape, selección mixta, destinos, presets, historial. Registrar qué se ejecutó, resultados y límites en TEST-RESULTS.md.

Matriz de dispositivos pendiente fuera de este Mac: macOS mínimo, Intel si se añade, múltiples monitores, VoiceOver con usuario, permisos TCC, disco realmente lleno, pérdida de energía y gran volumen de datos. No simular estos casos como si se hubieran probado físicamente. El código limita recursos pero eso no acredita resistencia universal.

Web: npm run check, npm run build; verificar enlaces de dist, manifiesto nulo y inválidos, móvil/escritorio, foco, contraste básico, reduced motion. Para una release pública descargar instalador publicado y comparar SHA-256; si release:null, esa prueba no aplica todavía.

No hay afirmaciones públicas de rendimiento: los tiempos de tests son de fixtures sintéticos, no benchmarks representativos.
