# Publicación independiente de ChatGPT

App y web viven juntas en el repositorio FluxDrop. La app está en apps/macos y la web estática en apps/web. El código se conserva privado inicialmente. No se suben instaladores ni claves al árbol Git. Un release futuro de GitHub puede alojar el DMG, checksum y notas; la publicación estable exige antes firma Developer ID y notarización verificadas.

## Vercel

Importar Juanexgo/FluxDrop, con Root Directory `apps/web`, framework Astro, Node 24.x, Install `npm ci`, Build `npm run build`, Output `dist`. Habilitar el acceso a archivos fuera de la raíz para copiar la matriz canónica de packages/release-manifest. La app macOS no se compila ni ejecuta en Vercel.

`apps/web/vercel.json` declara build y cabeceras de seguridad. Astro genera un sitio estático sin adaptador de servidor. La URL canónica se obtiene de SITE_URL si se configura, o de VERCEL_PROJECT_PRODUCTION_URL; al usar un dominio propio, actualizar SITE_URL al origen HTTPS real. No se conserva un dominio de ChatGPT como fallback.

La integración Git de Vercel permite reconstruir desde main y crear previews desde ramas. Los permisos de esa integración se autorizan en la cuenta del titular. No poner tokens en el repositorio. Las credenciales de firma Apple no se necesitan para alojar la web.

## Estado y bloqueo de acceso

La conexión GitHub está disponible. La conexión Vercel devuelve 403 al acceder al equipo `juanexgos-projects` (team_AceprCWSAdzqMKKOkdCEIYig). El titular debe reconectar Vercel con acceso a ese equipo. No hay CLI de Vercel autenticada localmente como alternativa. No se declara el nuevo sitio publicado hasta recibir READY y verificar HTTP real.

La web de ChatGPT anterior sigue disponible mientras se completa la nueva publicación. El manifiesto estable sigue release:null y no ofrece una descarga ficticia.

Documentación oficial: https://docs.astro.build/en/guides/deploy/vercel/ y https://vercel.com/docs/monorepos .
