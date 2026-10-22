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


## Edición Windows (0.4)

Monorepo compartido, no un binario compartido: SwiftUI/AppKit continúan en macOS; `apps/windows/FluxDrop.slnx` contiene Core (.NET portable), Windows (WPF/WinRT) y Tests (harness ejecutable). Se mantiene una matriz de capacidades Windows independiente: ninguna prueba de ImageIO acredita WIC ni se heredan sus rutas de formatos.

`PortableEngine` maneja datos, comprimidos, renombrado como copias e informes SHA-256. `WindowsEngine` coordina imágenes WIC/libwebp, PDFsharp/PdfPig/PDFium, Tesseract y procesos FFmpeg, además de recetas. `JobQueue` persiste estados, marca trabajos incompletos como interrumpidos y limita concurrencia. Los estados de pausa solo afectan pendientes. Toda publicación usa temporales en el destino y nombres únicos; no sobrescribe originales. `ProcessRunner` usa ArgumentList, drena stdout/stderr con límites, comprueba exit code y cancela el árbol del proceso. No hay shell concatenada ni descargas durante trabajos.

WPF ofrece ventana, widget radial con geometría real de hit testing, controles accesibles por teclado, temas y recursos ES/EN. Win32 RegisterHotKey detecta conflictos; el hook opcional de clic derecho observa el gesto sin bloquear los menús de Windows. FileSystemWatcher trabaja solo en raíces elegidas, sin recursión, con estabilidad, deduplicación y destino separado. Windows Share entrega archivos únicamente a un destino elegido por el usuario.

La web Astro usa manifiestos Mac y Windows separados. El workflow Windows prueba motores y UI en runner Windows, instala y desinstala el EXE; solo después se publica el artefacto. Los ZIP correspondientes de motores se ofrecen junto a los instaladores, con checksums. La identidad MSIX no se requiere: OCR usa Tesseract porque Windows.Media.Ocr no admite este canal sin identidad de paquete.

Render PDF final: PDFtoImage 5.4.0 (MIT), SkiaSharp 4.150.1 (MIT y avisos nativos) y bblanchon.PDFium.Win32 152.0.7961. DLL Windows comparada byte a byte con release chromium/7961; SHA-256, args.gn, VERSION y todas las licencias transitivas se incluyen en ThirdParty. V8 y XFA desactivados. Se reemplazó Windows.Data.Pdf al reproducirse un cierre anómalo en el runner; no se ignora un exit code por haber producido un PNG. La aceptación final exige salida limpia de la app instalada.
