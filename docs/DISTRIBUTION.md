# Distribución directa

1. Ejecutar build de motores y app Release. Ejecutar pruebas finales; revisar docs/TEST-RESULTS.md.
2. `scripts/package-dmg.sh` crea DMG con FluxDrop.app y enlace Applications, más SHA-256. Por sí solo produce una compilación de desarrollo ad hoc; no publicar como estable.
3. Para distribución: certificado Developer ID Application y membresía Apple Developer del propietario. Crear perfil de notarytool en Keychain. Exportar DEVELOPER_ID con nombre de identidad y NOTARY_PROFILE con nombre de perfil (no contraseña). Ejecutar scripts/sign-and-notarize.sh. Firma helpers y app con hardened runtime, somete app/DMG, exige Accepted, adjunta tickets y valida Gatekeeper.
4. Publicar DMG y notas en alojamiento HTTPS del propietario. Preparar candidato conforme packages/release-manifest/schema.json con versión, fecha, macOS mínimo, arquitecturas, URL, tamaño y SHA-256.
5. `node scripts/publish-manifest.mjs candidate.json build/releases/notarization-proof.json` descarga de nuevo el artefacto publicado y exige tamaño/checksum y notas accesibles antes de modificar stable.json. No usar prueba de notarización de otro archivo.
6. Reconstruir/publicar web desde el mismo estado de fuente. El botón está deshabilitado con release:null; no enlaza una descarga ficticia.

El script solo prepara el flujo; las credenciales y resultados reales son requisitos externos. Nunca guardar certificados, claves privadas, passwords o tokens en Git. No se ha configurado un canal beta.

## Actualizaciones

Sparkle evaluado, no incorporado en esta versión. Requiere feed HTTPS, firma Ed25519 y claves privadas protegidas, junto a firma/notarización. No basta con comparar versiones en JSON. Antes de incorporarlo se deben probar dos versiones, firma inválida, fallo de red y actualización desde DMG montado. [Documentación de Sparkle](https://sparkle-project.org/documentation/).

## Mac App Store

No es el canal de este bundle. Requeriría sandbox, bookmarks security-scoped, revisión de carpetas vigiladas, integración del helper, firma de tienda y revisión de licencias. No reutilizar este empaquetado asumiendo compatibilidad. [Notarización Apple para distribución directa](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
