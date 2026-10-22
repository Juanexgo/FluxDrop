# Publicación independiente de ChatGPT

App y web viven juntas en el repositorio FluxDrop. La app está en apps/macos y la web estática en apps/web. El código se conserva privado inicialmente. No se suben claves al árbol Git. Excepción explícita para esta entrega: el DMG de desarrollo verificado se versiona en apps/web/public/downloads para servirlo desde Vercel sin exponer el repositorio privado. Su checksum y estado ad hoc/sin notarizar se validan en cada build. El canal estable sigue separado. Un release futuro de GitHub puede alojar el DMG, checksum y notas; la publicación estable exige antes firma Developer ID y notarización verificadas.

## Vercel

Importar Juanexgo/FluxDrop, con Root Directory `apps/web`, framework Astro, Node 24.x, Install `npm ci`, Build `npm run build`, Output `dist`. Habilitar el acceso a archivos fuera de la raíz para copiar la matriz canónica de packages/release-manifest. La app macOS no se compila ni ejecuta en Vercel.

`apps/web/vercel.json` declara build y cabeceras de seguridad. Astro genera un sitio estático sin adaptador de servidor. La URL canónica se obtiene de SITE_URL si se configura, o de VERCEL_PROJECT_PRODUCTION_URL; al usar un dominio propio, actualizar SITE_URL al origen HTTPS real. No se conserva un dominio de ChatGPT como fallback.

La integración Git de Vercel permite reconstruir desde main y crear previews desde ramas. Los permisos de esa integración se autorizan en la cuenta del titular. No poner tokens en el repositorio. Las credenciales de firma Apple no se necesitan para alojar la web.

## Publicación verificada

Repositorio privado: https://github.com/Juanexgo/FluxDrop , rama main. Incluye app, web, scripts, fixtures, documentación y workflow Web checks. El workflow pasó en GitHub Actions.

Web pública: https://fluxdrop-ruby.vercel.app . Proyecto `fluxdrop` del equipo `juanexgos-projects`. Importación mediante la sesión web autorizada del titular; el conector API todavía devuelve 403 y no se han ampliado sus permisos. La primera publicación desde fa94bf4919f2f57c21412fb406d858706989ae6b completó; se verificaron HTTP 200 de ocho páginas y formats.js, canonical del nuevo dominio, CSP/nosniff, búsqueda FLAC con una fila y estado de descarga estable.

La descarga de desarrollo usa un manifiesto separado `development.json`: archivo real, tamaño, SHA-256, arquitectura y estado de firma explícitos. El build falla si el binario falta o su tamaño/hash difiere. No se activa stable.json para esta entrega ad hoc. Las actualizaciones de main se despliegan por la integración Git de Vercel.

Documentación oficial: https://docs.astro.build/en/guides/deploy/vercel/ y https://vercel.com/docs/monorepos .

## Windows 0.4.0-dev

El mismo repositorio incluye apps/windows. Producción e31d6ef ofrece EXE Windows 11 22H2+ x64 y fuentes de motores, manteniendo el DMG Mac 0.3. El EXE permanece sin firma Authenticode. Ambas descargas Windows se verificaron completas por HTTPS con tamaño/SHA-256; ver WINDOWS-TEST-RESULTS.md. Para futuras versiones se recomienda alojamiento de artefactos separado del historial Git; esta entrega usa los archivos estáticos comprobados en public/downloads.
