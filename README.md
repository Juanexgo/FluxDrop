# FluxDrop

Web pública: https://fluxdrop-ruby.vercel.app · [Descarga de desarrollo](https://fluxdrop-ruby.vercel.app/descarga/). macOS: firma ad hoc, sin notarización. Windows: instalador de desarrollo sin firma Authenticode. Cada sistema puede advertir o bloquear su apertura.

Utilidad nativa para macOS y Windows que transforma archivos localmente. SwiftUI/AppKit en Mac y C#/WPF en Windows, con motores propios de cada plataforma y FFmpeg compilado desde fuentes fijadas. Web estática Astro/TypeScript; nunca recibe archivos.

Estado: macOS 0.3.0-dev y Windows 0.4.0-dev. El estado de validación se encuentra en `docs/TEST-RESULTS.md` cuando termina la comprobación final. No equivale a una versión firmada y notarizada para distribución pública.

## Empezar en macOS

```sh
scripts/build-ffmpeg.sh
scripts/build-macos.sh
scripts/test-macos.sh
npm --prefix apps/web install
npm --prefix apps/web run build
scripts/package-pkg.sh
```

Abrir `apps/macos/Package.swift` en Xcode y seleccionar el esquema FluxDrop. El script crea el bundle completo con sus motores; ejecutar el producto SwiftPM directamente no incorpora los ejecutables multimedia. macOS 14 mínimo, compilación actual Apple Silicon. No requiere Homebrew en el equipo del usuario.

En Ajustes → Widget puedes cambiar tamaño (240–400 pt), tema, color, transparencia, etiquetas, favoritos y cierre tras una acción. La activación global es opcional: clic derecho, ⌥ + clic derecho o ⌃ + clic derecho. Sustituye el menú contextual solo para el gesto elegido y puede desactivarse. La selección del Finder no se importa automáticamente. Consulta [Widget y activación](docs/WIDGET.md).

El atajo inicial ⌃⌥D muestra el widget junto al cursor; también se abre desde la barra de menú. Arrastrar al sector de un formato o añadir archivos desde la ventana. Los resultados se guardan como copias con nombres únicos. Los originales solo se mueven o renombran mediante acciones explícitas con revisión y los duplicados solo se envían a Papelera tras selección y confirmación.

- [Desarrollo](docs/DEVELOPMENT.md)
- [Arquitectura](docs/ARCHITECTURE.md)
- [Formatos y límites](docs/FORMATS.md)
- [Distribución](docs/DISTRIBUTION.md)
- [Privacidad](docs/PRIVACY.md)
- [Licencias](docs/THIRD-PARTY.md)
- [Pruebas](docs/TESTING.md)
- [Limitaciones](docs/LIMITATIONS.md)
- [Avances](docs/PROGRESS.md)

`apps/macos`: app Swift, motores y pruebas; `apps/windows`: app WPF, núcleo y pruebas; `apps/web`: sitio; `packages/release-manifest`: capacidades y canal estable; `scripts`: build y releases; `fixtures`: entradas pequeñas reproducibles.

## Publicación y lanzamiento

[GitHub y alojamiento independiente](docs/PUBLICATION.md) · [Pendientes para un release profesional](docs/RELEASE-READINESS.md). El repositorio incluye app y web. El workflow Web checks ejecuta validación de tipos, build, enlaces y manifiesto.

## Versión 0.2

Tres modos del widget: Convertir, Editar y Archivos. Recorte visual de imágenes, montaje visual de páginas PDF, reproducción/recorte multimedia y acceso a compresión. Exportación JPEG/PNG/TIFF/HEIC/BMP/WebP: 36 rutas comprobadas con fixtures, incluyendo reexportaciones al mismo formato. Esto mide rutas de imagen, no herramientas ni todas las combinaciones posibles del producto. 34 pruebas XCTest pasaron; ver evidencia y límites en docs/TEST-RESULTS.md.

## Revisión 0.3

MP3 y Opus con motores incluidos, AVIF condicionado a ImageIO disponible, paginación de acciones, intercambio de teclas, verificación multimedia completa y ocho fixtures de seguridad de comprimidos. 39 pruebas pasaron; 49 rutas de imagen verificadas en macOS 26.3. El titular no tiene membresía Apple Developer: firma Developer ID y notarización siguen pendientes. Ver docs/TEST-RESULTS.md.

Comprobación final ampliada: 43 pruebas pasaron sobre el código 0.3; todas las operaciones registradas tienen cobertura representativa. No equivale a validar todos los archivos posibles ni los gestos globales pendientes.


## Windows

La app nativa de Windows vive en `apps/windows` dentro de este mismo monorepo. No es necesario separar repositorios: cada sistema conserva su interfaz, motores, pruebas y artefactos; la web y los manifiestos se mantienen juntos. Windows 11 22H2+ x64, C#/WPF y .NET 10 autocontenido. [Desarrollo, diferencias y distribución](docs/WINDOWS.md).

- `dotnet run --project apps/windows/FluxDrop.Tests -c Release`: pruebas portables del núcleo.
- `dotnet build apps/windows/FluxDrop.Windows -c Release`: compilación; en Mac no ejecuta WPF.
- Workflow `Windows engines`: compila FFmpeg/LAME/Opus/WebP desde fuentes fijadas para Windows.
- Workflow `Windows build and verification`: usa el run de motores, prueba en Windows, publica self-contained, crea MSI y comprueba instalación, ejecución, reparación y desinstalación.
- Manifiesto independiente `packages/release-manifest/windows.json`; una descarga nula nunca se presenta como un instalador disponible. La distribución Windows de desarrollo no tiene firma Authenticode. macOS ofrece ahora un PKG con asistente; el DMG anterior se conserva como archivo histórico. Ver docs/INSTALLER-TEST-RESULTS.md.
