# Lo que falta para un lanzamiento profesional

La compilación y 39 pruebas automatizadas no convierten esta entrega de desarrollo en un release estable.

## Antes de distribuir a clientes

1. Completar la prueba manual del widget configurable: guardado tras reinicio, clic derecho en Finder y otras apps, variantes de modificadores, desactivación que restaura el menú, arrastre, Escape/teclado, varios monitores y VoiceOver. La última sesión perdió la conexión del controlador visual.
2. Probar macOS 14, permisos denegados, destino lleno, lotes grandes y estabilidad prolongada. Intel no se anuncia sin build y prueba propios. Registrar fixtures y rendimiento antes de publicar cifras.
3. Firma Developer ID Application, notarización, stapling y Gatekeeper aceptado. La entrega actual solo tiene firma ad hoc y Gatekeeper la rechaza. Requiere credenciales del titular en Keychain, nunca en GitHub.
4. Revisar obligaciones de la compilación exacta de FFmpeg, licencias y patentes para la distribución comercial.
5. Publicar DMG firmado, checksum y notas; validar el manifiesto y comprobar la descarga real antes de habilitar el botón de la web.
6. Incorporar capturas reales y una demostración de la versión final validada; revisión de textos ES/EN, accesibilidad y recuperación de errores. Usar dominio propio cuando el titular elija y registre uno.

## Después del lanzamiento inicial

Actualizador firmado (Sparkle evaluado, aún sin implementar) con prueba entre dos versiones, soporte y procedimiento de releases reproducible. Ampliar formatos solo con motor distribuible y pruebas representativas: AVIF depende del codificador ImageIO del sistema y necesita prueba en otras versiones de macOS. Revisar las restricciones de App Store por separado.

CI web verifica tipos, build, enlaces y manifiesto. No sustituye pruebas manuales nativas ni firma/notarización.

El titular confirmó que no tiene membresía Apple Developer. La firma/notarización queda bloqueada por ese requisito externo; no se presenta la compilación de desarrollo como estable.
