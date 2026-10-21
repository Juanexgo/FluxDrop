# Componentes y avisos

- Swift y frameworks Apple: SDK del sistema; no se redistribuye el SDK.
- libarchive del sistema `/usr/lib/libarchive.2.dylib`: licencia BSD; enlazado dinámicamente, no se incorpora un ejecutable externo. Declaraciones C mínimas en Sources/CArchive.
- Yams 6.2.2, MIT, con libyaml incorporado (MIT): aviso completo en third-party/Yams-LICENSE.txt y licencia de libyaml del checkout copiada al paquete.
- FFmpeg 9.0.2 y ffprobe: compilación propia sin GPL, nonfree, autodetect ni red. Se habilitan VideoToolbox, AudioToolbox y zlib del sistema. Configuración y versiones exactas en build/engines/{buildconf,version,license}.txt. Fuente original, LICENSE.md y COPYING.LGPLv2.1 se incluyen en Resources/ThirdParty del bundle. `scripts/build-ffmpeg.sh` permite reconstruir y sustituir los ejecutables; una app modificada necesita volver a firmarse localmente.
- Astro y TypeScript son herramientas de la web. El inventario exacto está fijado en package-lock.json; no se incorporan en el bundle nativo.

La compilación concreta de FFmpeg debe revisarse antes de venta: obligaciones LGPL, licencias de componentes y patentes de códecs dependen del uso y jurisdicción. No se afirma una autorización comercial universal. No se incluye x264/x265 ni una descarga binaria de terceros. [Criterios oficiales de FFmpeg](https://ffmpeg.org/legal.html).

Marca, textos y panel de FluxDrop son propios. La referencia visual aportada se usó para la idea de interacción circular, sin reutilizar marca ni recursos de Tangerine.

- libwebp 1.6.0, código C incorporado estáticamente. Fuente oficial fijada en commit `4fa21912338357f89e4fd51cf2368325b59e9bd9`; subconjunto y SHA-256 por archivo en `apps/macos/Vendor/WebP/UPSTREAM.json`. Licencia BSD y concesión de patentes originales en `third-party/WebP-{COPYING,PATENTS,AUTHORS}.txt`, también incluidas en el bundle. No requiere Homebrew ni descarga al convertir. Fuente: https://chromium.googlesource.com/webm/libwebp/

## Audio incorporado en 0.3

FFmpeg 9.0.2 se reconstruyó con `--enable-libmp3lame --enable-libopus`, conservando `--disable-gpl --disable-nonfree --disable-network --disable-autodetect`. LAME 4.0: biblioteca estática, frontend y decoder deshabilitados, LGPL 2 o posterior; avisos COPYING y LICENSE originales incluidos. SHA-256 del tar oficial: 3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb. libopus 1.6.1: biblioteca estática, sin documentación ni programas extra, avisos BSD y concesiones de patentes upstream incluidos; SHA-256 6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1. Los tar originales de ambos se distribuyen con FFmpeg en Resources/ThirdParty. Sin modificaciones al código de los motores. La app no enlaza con FFmpeg: ejecuta helpers sustituibles con argumentos estructurados. El script permite reconstruir los ejecutables con bibliotecas modificadas; no se prohíbe la ingeniería inversa necesaria para depurar cambios.

`pkg-config` es una herramienta de compilación, no se incorpora al producto ni se necesita en el Mac del usuario. Configuración y dependencias dinámicas reales en los archivos buildconf/linkage incluidos. Revisión comercial de la compilación concreta sigue pendiente.
