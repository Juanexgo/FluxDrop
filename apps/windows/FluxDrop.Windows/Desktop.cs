using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Input;
using System.Diagnostics;
using FluxDrop.Core;
namespace FluxDrop.Windows;
public sealed class Preferences {
 public string Language {get;set;}="es";public string Theme {get;set;}="system";public string Destination {get;set;}=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),"FluxDrop");public Options Options {get;set;}=new();public bool History {get;set;}=true;public bool Notify {get;set;}public int Concurrency {get;set;}=2;public int Hotkey {get;set;}=0x20;public uint Modifiers {get;set;}=3;public string RightClick {get;set;}="off";public int WidgetSize {get;set;}=380;public string[] Favorites {get;set;}=["png","jpg","webp","pdf","zip","json"];public List<Recipe> Recipes {get;set;}=[];public List<WatchRule> Watches {get;set;}=[];
 public static string Root=>Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"FluxDrop");public static string PathName=>Path.Combine(Root,"settings.json");public void Save()=>Config.Write(PathName,this);public static Preferences Load()=>Config.Read<Preferences>(PathName)??new();
}
public sealed record WatchRule(string Source,string Destination,Recipe Recipe,bool Enabled=true);
public sealed class DesktopIntegration:IDisposable {
 const int HotkeyId=0x4FD;readonly nint hwnd;readonly HwndSource source;readonly Action show;Hook? mouseCallback;nint hook;
 [UnmanagedFunctionPointer(CallingConvention.Winapi)]delegate nint Hook(int code,nint message,nint data);
 [DllImport("user32.dll",SetLastError=true)]static extern bool RegisterHotKey(nint h,int id,uint modifiers,uint key);
 [DllImport("user32.dll")]static extern bool UnregisterHotKey(nint h,int id);
 [DllImport("user32.dll",SetLastError=true)]static extern nint SetWindowsHookEx(int id,Hook callback,nint module,uint thread);
 [DllImport("user32.dll")]static extern bool UnhookWindowsHookEx(nint hook);
 [DllImport("user32.dll")]static extern nint CallNextHookEx(nint hook,int code,nint message,nint data);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]static extern nint GetModuleHandle(string? name);
 public DesktopIntegration(Window window,Action show){this.show=show;hwnd=new WindowInteropHelper(window).EnsureHandle();source=HwndSource.FromHwnd(hwnd);source.AddHook(Messages);}
 nint Messages(nint h,int msg,nint w,nint l,ref bool handled){if(msg==0x312&&w==HotkeyId){show();handled=true;}return 0;}
 public bool Configure(Preferences preferences){UnregisterHotKey(hwnd,HotkeyId);if(!RegisterHotKey(hwnd,HotkeyId,preferences.Modifiers|0x4000,(uint)preferences.Hotkey))return false;if(hook!=0){UnhookWindowsHookEx(hook);hook=0;}if(preferences.RightClick!="off"){mouseCallback=(code,message,data)=>{if(code>=0&&message==0x205&&(preferences.RightClick=="always"||Keyboard.Modifiers.HasFlag(ModifierKeys.Control)))Application.Current.Dispatcher.BeginInvoke(show);return CallNextHookEx(hook,code,message,data);};hook=SetWindowsHookEx(14,mouseCallback,GetModuleHandle(null),0);if(hook==0)throw new IOException("Windows no pudo registrar el gesto global.");}return true;}
 public void Dispose(){UnregisterHotKey(hwnd,HotkeyId);source.RemoveHook(Messages);if(hook!=0)UnhookWindowsHookEx(hook);}
 public static void Reveal(string path){if(Directory.Exists(path))Process.Start(new ProcessStartInfo("explorer.exe"){ArgumentList={path},UseShellExecute=false});else if(File.Exists(path))Process.Start(new ProcessStartInfo("explorer.exe"){ArgumentList={"/select,",path},UseShellExecute=false});else throw new FileNotFoundException("El resultado se movió o se eliminó.");}
 public static void Terminal(string path){string dir=Directory.Exists(path)?path:Path.GetDirectoryName(path)!;Process.Start(new ProcessStartInfo("cmd.exe"){WorkingDirectory=dir,UseShellExecute=true});}
}
public sealed class WatchService:IDisposable {
 readonly List<FileSystemWatcher> watchers=[];readonly Dictionary<string,(long Size,DateTime Time)> seen=new(StringComparer.OrdinalIgnoreCase);readonly Dictionary<string,CancellationTokenSource> pending=new(StringComparer.OrdinalIgnoreCase);readonly Action<string,WatchRule> ready;readonly Action<string> error;
 public WatchService(IEnumerable<WatchRule> rules,Action<string,WatchRule> ready,Action<string> error){this.ready=ready;this.error=error;foreach(var rule in rules.Where(r=>r.Enabled)){try{if(SafeFiles.Within(rule.Destination,rule.Source)||string.Equals(Path.GetFullPath(rule.Destination),Path.GetFullPath(rule.Source),StringComparison.OrdinalIgnoreCase))throw new IOException("La carpeta de salida debe estar fuera de la carpeta vigilada.");SafeFiles.Input(rule.Source);var w=new FileSystemWatcher(rule.Source){IncludeSubdirectories=false,NotifyFilter=NotifyFilters.FileName|NotifyFilters.Size|NotifyFilters.LastWrite};w.Created+=(_,e)=>Schedule(e.FullPath,rule);w.Changed+=(_,e)=>Schedule(e.FullPath,rule);w.Renamed+=(_,e)=>Schedule(e.FullPath,rule);w.Error+=(_,_)=>error("Se perdieron eventos de la carpeta vigilada. Pausa y vuelve a activar la regla.");w.EnableRaisingEvents=true;watchers.Add(w);}catch(Exception ex){error(ex.Message);}}}
 void Schedule(string file,WatchRule rule){lock(pending){if(pending.Remove(file,out var old)){old.Cancel();old.Dispose();}var source=new CancellationTokenSource();pending[file]=source;_ = Stable(file,rule,source);}}
 async Task Stable(string path,WatchRule rule,CancellationTokenSource source){try{for(int tries=0;tries<30;tries++){await Task.Delay(2000,source.Token);if(!File.Exists(path)||Path.GetFileName(path).StartsWith('.'))return;SafeFiles.Input(path);var before=new FileInfo(path);var stamp=(before.Length,before.LastWriteTimeUtc);await Task.Delay(2000,source.Token);var after=new FileInfo(path);if(after.Length!=stamp.Length||after.LastWriteTimeUtc!=stamp.LastWriteTimeUtc)continue;using(File.Open(path,FileMode.Open,FileAccess.Read,FileShare.Read)){}lock(seen){if(seen.TryGetValue(path,out var previous)&&previous==stamp)return;seen[path]=stamp;}ready(path,rule);return;}error("El archivo sigue cambiando: no se procesó.");}catch(OperationCanceledException){}catch(Exception ex){error(ex.Message);}finally{lock(pending){if(pending.TryGetValue(path,out var current)&&current==source){pending.Remove(path);source.Dispose();}}}}
 public void Dispose(){foreach(var w in watchers)w.Dispose();lock(pending){foreach(var s in pending.Values)s.Cancel();pending.Clear();}}
}
