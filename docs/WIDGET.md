# Widget configurable

Abre FluxDrop → Ajustes (⌘,) → Widget, o pulsa el icono de ajustes del propio widget.

- Tamaño: 240–400 puntos, en pasos de 20.
- Apariencia: sistema, clara u oscura.
- Acento: coral, naranja, azul, verde o violeta.
- Opacidad: 85–100 %. Etiquetas y pista del gesto opcionales.
- Favoritos primero y cerrar después de ejecutar configurables.
- Restablecer apariencia conserva la configuración de activación.

## Clic derecho en todo el Mac

Activa «Abrir con clic derecho en cualquier parte del Mac» y elige clic derecho solo, Opción + clic derecho o Control + clic derecho. El gesto elegido sustituye el menú contextual mientras la opción está activa. Los demás modificadores pasan al sistema. Se consume la pareja down/up, nunca un mouse-up ajeno. Dentro del widget no se vuelve a abrir recursivamente. El menú de FluxDrop permite desactivar la captura global.

El indicador de estado informa si el tap está activo, necesita permisos o no está disponible. Se intenta crear primero un tap solo de ratón; no se exige Accesibilidad de forma incondicional. Si falla, el botón de permisos solicita autorización de macOS de forma incremental. No se conceden permisos automáticamente. Si macOS desactiva el tap por intervención del usuario, la opción se apaga.

La implementación utiliza CGEvent.tapCreate de sesión y CFRunLoop del hilo principal, con máscara limitada a rightMouseDown/rightMouseUp. No sintetiza eventos ni intercepta un arrastre global. Durante un arrastre mantiene el panel no activador; al abrir con clic derecho normal puede tomar foco para teclado. El panel se coloca en la pantalla del cursor y se limita al área visible. Esta geometría requiere aún una prueba física con varios monitores.

## Archivos y acciones

Añade archivos con +, desde la ventana, abriéndolos con FluxDrop o arrastrándolos al sector. El clic derecho no obtiene automáticamente los archivos seleccionados en Finder. Los sectores usan los motores reales y la cola existente. Flechas y Retorno eligen/ejecutan cuando el widget tiene foco; Escape cierra. La búsqueda y la ventana principal permiten acceder al resto de herramientas.

Los ajustes se validan y persisten como JSON versionado en UserDefaults (`widget.settings.v1`). Una configuración incompatible recupera los valores iniciales. La captura global está desactivada por defecto.

## Evidencia

Consulta TEST-RESULTS.md para separar compilación y pruebas de configuración de la validación visual y del evento global real. No se considera verificado un tap global solo porque compile o porque pase su máquina de estados.

API oficial: [CGEvent.tapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)).
