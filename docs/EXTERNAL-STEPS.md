# Pasos externos pendientes

1. Disponer de Developer ID Application del titular y perfil notarytool en Keychain. Ejecutar scripts/sign-and-notarize.sh; exigir Accepted, stapler y Gatekeeper reales.
2. Publicar el DMG notarizado y notas en HTTPS; ejecutar publish-manifest.mjs con prueba de notarización, URL, tamaño y SHA-256 exactos. Solo entonces activar descarga estable y publicar la nueva web.
3. Revisar licencias y patentes de la compilación concreta antes de venta.
4. Completar recorrido visual del panel radial, arrastre real, VoiceOver, monitores y macOS mínimo cuando el controlador de pantalla esté disponible.
5. Sparkle solo fue evaluado; para incorporarlo faltan claves Ed25519 protegidas, feed firmado e integración probada entre versiones. Intel no está construido ni anunciado.

El titular confirmó el 20 de octubre de 2026 que no tiene membresía Apple Developer. La compilación 0.3 se entrega como desarrollo ad hoc; no se realizó contratación ni pago. Antes de firma/notarización deberá disponer de membresía y crear un certificado Developer ID Application propio en el llavero.
