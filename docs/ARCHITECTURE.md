# Arquitectura

AppModel coordina selección y destino; JobQueue pertenece al MainActor y serializa trabajos persistidos. Cada motor es un actor. Las operaciones tienen identificadores cerrados ToolID y opciones Codable: las recetas importadas no admiten comandos de shell. Recipe.validate limita versión, longitud y compatibilidad de categorías entre pasos.

ImageIO/CGImage realiza decode y rasterizado; PDFKit manipula páginas; Vision reconoce texto local; CoreText genera PDF; Yams analiza YAML; libarchive procesa ZIP/TAR/GZIP en streaming; FFmpeg usa Process con argumentos estructurados, sin shell y sin red habilitada en su compilación.

WorkflowEngine encadena salidas dentro de un temporal privado del mismo volumen. Una salida se publica sin reemplazar nombres existentes mediante link; directorios de resultados mediante renamex_np RENAME_EXCL. Los errores limpian el temporal con defer. Se consulta espacio disponible antes de empezar; errores de escritura posteriores también fallan. No se elimina un original después de un error. La cola usa estados reales; pausa significa no iniciar el siguiente trabajo, nunca congelar ficticiamente el motor.

Progreso: recuento real de páginas/archivos o posición temporal FFmpeg; estado indeterminado donde no hay métrica. Cancelación cooperativa entre llamadas nativas; procesos externos reciben terminación y se espera su salida. FFmpeg usa hilos propios, no comandos hijos arbitrarios.

Panel rápido: NSPanel no activante y flotante con coordenadas del monitor que contiene el cursor. Carbon RegisterEventHotKey recibe el atajo global sin event tap ni permiso de Accesibilidad. NSDraggingDestination recibe archivos únicamente cuando el arrastre entra en la vista. No se intercepta el arrastre global ni se inspeccionan archivos antes de entrar. La tecla Shift sola no está implementada: no equivale a un hotkey registrable con modificadores. Flujo alternativo siempre disponible: abrir panel y arrastrar o añadir archivos.

WatchScanner visita solo hijos directos del directorio autorizado, ignora enlaces, ocultos y nombres de resultado; espera tamaño/mtime estables diez segundos. Persiste firmas de archivos vistos. Destino separado. No usa recursión global del disco. Distribución directa sin sandbox; bookmarks mínimos y acceso del usuario, sin solicitar Full Disk Access.

Referencias: [NSPanel](https://developer.apple.com/documentation/appkit/nspanel), [ImageIO](https://developer.apple.com/documentation/imageio), [PDFKit](https://developer.apple.com/documentation/pdfkit), [Vision](https://developer.apple.com/documentation/vision).

## Widget y gesto configurable

FluxWidgetConfiguration pertenece a FluxCore y valida la configuración versionada. WidgetPreferences coordina persistencia local, apariencia y activación. WidgetView sustituye el panel rectangular por una rueda y una barra compacta. GlobalRightClick instala un tap público de sesión solo para botón derecho, limitado al run loop principal; RightClickGate decide la pareja de eventos que se consume. Ningún evento de teclado ni contenido externo se registra. PanelController adapta tamaño/tema/opacidad y posición a la pantalla del cursor.
