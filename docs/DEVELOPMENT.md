# Desarrollo en Mac

Entorno de implementación: macOS 26.3, Xcode 26.6, Swift 6.3.3, arm64. El mínimo macOS 14 permite Observation y ContentUnavailableView; no se afirma validación en macOS 14 ni Intel sin ejecutarla allí.

Instalar Xcode desde Apple y seleccionar sus herramientas. Abrir `apps/macos/Package.swift`: SwiftPM resuelve Yams 6.2.2 fijado. Build con `scripts/build-macos.sh`; `CONFIGURATION=debug` habilita Debug. Los scripts copian fuente a `/private/tmp` para evitar invalidaciones y atributos de iCloud Documents durante la compilación y firma. El bundle canónico se genera en `/private/tmp/fluxdrop-package/FluxDrop.app`, y se copia a `build/FluxDrop.app`.

FFmpeg: `scripts/build-ffmpeg.sh` descarga únicamente fuente oficial fijada por SHA-256, compila e incorpora FFmpeg/ffprobe. Esa descarga sucede durante desarrollo, nunca durante conversiones. Las herramientas finales se resuelven dentro del bundle, no mediante PATH. La firma local es ad hoc y no es Developer ID.

Web: Node compatible con Astro 6, `npm ci` desde apps/web, `npm run dev`. `npm run build` sincroniza la matriz/manifiesto canónicos y genera dist. La variable opcional SITE_URL establece canonical; no es un secreto. Versionar package-lock.json y Package.resolved. No versionar build, node_modules, certificados ni llaveros.

Textos nativos: Resources/en.lproj y es.lproj/Localizable.strings. `tr` resuelve el bundle de recursos SwiftPM empaquetado. No cambiar el idioma global del Mac para probar; arrancar una instancia aislada con AppleLanguages para una comprobación localizada.
