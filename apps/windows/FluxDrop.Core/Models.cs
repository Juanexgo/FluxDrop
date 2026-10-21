using System.Text.Json;
namespace FluxDrop.Core;
public sealed record Options {
 public string RecipeJson {get;init;}="";
 public string Format {get;init;}="png";
 public int MaxSide {get;init;}=1920;
 public int Quality {get;init;}=85;
 public int Rotate {get;init;}
 public bool Flip {get;init;}
 public bool StripMetadata {get;init;}=true;
 public string Watermark {get;init;}="";
 public string WatermarkImage {get;init;}="";
 public int CropX {get;init;}
 public int CropY {get;init;}
 public int CropWidth {get;init;}
 public int CropHeight {get;init;}
 public string Pages {get;init;}="";
 public string Password {get;init;}="";
 public int Dpi {get;init;}=144;
 public double Start {get;init;}
 public double Duration {get;init;}
 public int Bitrate {get;init;}=160;
 public int VideoBitrate {get;init;}=2400;
 public int TargetMB {get;init;}
 public string Subtitles {get;init;}="";
 public bool RemoveAudio {get;init;}
 public bool Normalize {get;init;}
 public char Delimiter {get;init;}=',';
 public bool Headers {get;init;}=true;
 public string Prefix {get;init;}="";
 public string Suffix {get;init;}="";
 public string Replace {get;init;}="";
 public string With {get;init;}="";
 public bool Number {get;init;}
 public string OcrLanguage {get;init;}="en-US";
 public void Validate(){if(MaxSide<0||MaxSide>8192||Quality<1||Quality>100||Dpi<36||Dpi>300||Start<0||Duration<0||Bitrate<32||Bitrate>320||VideoBitrate<128||VideoBitrate>50000||TargetMB<0||TargetMB>10000||Rotate%90!=0||CropX<0||CropY<0||CropWidth<0||CropHeight<0||Delimiter is '\r' or '\n' or '"'||Watermark.Length>500)throw new ArgumentException("Opciones fuera de los límites permitidos.");}
}
public sealed record Capability(string Id,string Category,string[] Extensions,string Output,bool Batch=false,bool Aggregate=false);
public sealed record Step(string Operation,Options Options);
public sealed record Recipe(int SchemaVersion,string Name,List<Step> Steps) {
 public void Validate(IReadOnlyList<Capability> capabilities){if(SchemaVersion!=1||string.IsNullOrWhiteSpace(Name)||Name.Length>120||Steps.Count is <1 or >12)throw new ArgumentException("Receta inválida.");Capability? previous=null;foreach(var step in Steps){step.Options.Validate();var cap=capabilities.FirstOrDefault(c=>c.Id==step.Operation)??throw new ArgumentException("Operación no disponible: "+step.Operation);if(previous!=null&&cap.Extensions.Length>0&&!cap.Extensions.Contains(previous.Output,StringComparer.OrdinalIgnoreCase)&&previous.Output!="image")throw new ArgumentException("Pasos incompatibles: "+previous.Id+" → "+cap.Id);previous=cap;}}
}
public sealed record Request(string Operation,string[] Inputs,string Destination,Options Options);
public sealed record Result(string[] Outputs,string Detail="");
public interface IEngine { IReadOnlyList<Capability> Capabilities {get;} Task<Result> ExecuteAsync(Request request,IProgress<double?>? progress,CancellationToken token); }
public static class Config {
 public static readonly JsonSerializerOptions Json=new(){WriteIndented=true,PropertyNameCaseInsensitive=false,MaxDepth=64};
 public static T? Read<T>(string path){try{return JsonSerializer.Deserialize<T>(File.ReadAllText(path),Json);}catch(IOException){return default;}catch(JsonException){return default;}}
 public static void Write<T>(string path,T data){Directory.CreateDirectory(Path.GetDirectoryName(path)!);string temp=path+".tmp-"+Guid.NewGuid().ToString("N");try{File.WriteAllText(temp,JsonSerializer.Serialize(data,Json));File.Move(temp,path,true);}finally{if(File.Exists(temp))File.Delete(temp);}}
}
