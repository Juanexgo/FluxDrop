# Componentes y avisos

- Swift y frameworks Apple: SDK del sistema; no se redistribuye el SDK.
- libarchive del sistema `/usr/lib/libarchive.2.dylib`: licencia BSD; enlazado dinámicamente, no se incorpora un ejecutable externo. Declaraciones C mínimas en Sources/CArchive.
- Yams 6.2.2, MIT, con libyaml incorporado (MIT): aviso completo en third-party/Yams-LICENSE.txt y licencia de libyaml del checkout copiada al paquete.
- FFmpeg 9.0.2 y ffprobe: compilación propia sin GPL, nonfree, autodetect ni red. Se habilitan VideoToolbox, AudioToolbox y zlib del sistema. Configuración y versiones exactas en build/engines/{buildconf,version,license}.txt. Fuente original, LICENSE.md y COPYING.LGPLv2.1 se incluyen en Resources/ThirdParty del bundle. `scripts/build-ffmpeg.sh` permite reconstruir y sustituir los ejecutables; una app modificada necesita volver a firmarse localmente.
- Astro y TypeScript son herramientas de la web. El inventario exacto está fijado en package-lock.json; no se incorporan en el bundle nativo.

La compilación concreta de FFmpeg debe revisarse antes de venta: obligaciones LGPL, licencias de componentes y patentes de códecs dependen del uso y jurisdicción. No se afirma una autorización comercial universal. No se incluye x264/x265 ni una descarga binaria de terceros. [Criterios oficiales de FFmpeg](https://ffmpeg.org/legal.html).

Marca, textos y panel de FluxDrop son propios. La referencia visual aportada se usó para la idea de interacción circular, sin reutilizar marca ni recursos de Tangerine.
