# FluxDrop

Web pública: https://fluxdrop-ruby.vercel.app · [Descarga de desarrollo](https://fluxdrop-ruby.vercel.app/descarga/). Firma ad hoc, sin notarización de Apple; macOS puede bloquear la apertura.

Utilidad nativa de macOS para transformar archivos localmente. SwiftUI/AppKit, motores Apple, libarchive del sistema y FFmpeg compilado desde fuente. Web estática Astro/TypeScript; nunca recibe archivos.

Estado: versión de desarrollo 0.1.0. El estado de validación se encuentra en `docs/TEST-RESULTS.md` cuando termina la comprobación final. No equivale a una versión firmada y notarizada para distribución pública.

## Empezar

```sh
scripts/build-ffmpeg.sh
scripts/build-macos.sh
scripts/test-macos.sh
npm --prefix apps/web install
npm --prefix apps/web run build
scripts/package-dmg.sh
```

Abrir `apps/macos/Package.swift` en Xcode y seleccionar el esquema FluxDrop. El script crea el bundle completo con sus motores; ejecutar el producto SwiftPM directamente no incorpora los ejecutables multimedia. macOS 14 mínimo, compilación actual Apple Silicon. No requiere Homebrew en el equipo del usuario.

En Ajustes → Widget puedes cambiar tamaño (240–400 pt), tema, color, transparencia, etiquetas, favoritos y cierre tras una acción. La activación global es opcional: clic derecho, ⌥ + clic derecho o ⌃ + clic derecho. Sustituye el menú contextual solo para el gesto elegido y puede desactivarse. La selección del Finder no se importa automáticamente. Consulta [Widget y activación](docs/WIDGET.md).

El atajo inicial ⌃⌥D muestra el widget junto al cursor; también se abre desde la barra de menú. Arrastrar al sector de un formato o añadir archivos desde la ventana. Los resultados se guardan como copias con nombres únicos. Los originales se renombran solamente en la operación explícita de carpetas y los duplicados solo se envían a Papelera tras selección y confirmación.

- [Desarrollo](docs/DEVELOPMENT.md)
- [Arquitectura](docs/ARCHITECTURE.md)
- [Formatos y límites](docs/FORMATS.md)
- [Distribución](docs/DISTRIBUTION.md)
- [Privacidad](docs/PRIVACY.md)
- [Licencias](docs/THIRD-PARTY.md)
- [Pruebas](docs/TESTING.md)
- [Limitaciones](docs/LIMITATIONS.md)
- [Avances](docs/PROGRESS.md)

`apps/macos`: app, motores, pruebas; `apps/web`: sitio; `packages/release-manifest`: capacidades y canal estable; `scripts`: build y releases; `fixtures`: entradas pequeñas reproducibles.

## Publicación y lanzamiento

[GitHub y alojamiento independiente](docs/PUBLICATION.md) · [Pendientes para un release profesional](docs/RELEASE-READINESS.md). El repositorio incluye app y web. El workflow Web checks ejecuta validación de tipos, build, enlaces y manifiesto.
