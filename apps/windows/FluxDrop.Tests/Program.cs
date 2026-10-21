using System.Formats.Tar;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using FluxDrop.Core;

var root = Path.Combine(Path.GetTempPath(), "fluxdrop-core-tests-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);
int passed = 0;
async Task Test(string name, Func<Task> f)
{
    await f();
    Console.WriteLine("PASS " + name);
    passed++;
}
void Check(bool value)
{
    if (!value)
        throw new Exception("Assertion failed.");
}
async Task Reject(Func<Task> f)
{
    try
    {
        await f();
    }
    catch (Exception ex)
        when (ex
                is IOException
                    or ArgumentException
                    or FormatException
                    or JsonException
                    or YamlDotNet.Core.YamlException
                    or NotSupportedException
                    or OperationCanceledException
        )
    {
        return;
    }
    throw new Exception("Input unexpectedly accepted.");
}
var engine = new PortableEngine();
var input = Path.Combine(root, "café & $ prueba.json");
await File.WriteAllTextAsync(input, "{\"a\":[1,true,\"niño\"]}");
var hash = await SafeFiles.Hash(input, default);
async Task<Result> Run(string id, string[] files, Options? o = null) =>
    await engine.ExecuteAsync(new(id, files, root, o ?? new()), null, default);
try
{
    await Test(
        "JSON formatting and minification reopen",
        async () =>
        {
            foreach (var id in new[] { "jsonPretty", "jsonMinify" })
            {
                var r = await Run(id, [input]);
                Check(
                    DataEngine.Json(await File.ReadAllTextAsync(r.Outputs[0]))!.ToJsonString()
                        == DataEngine.Json(await File.ReadAllTextAsync(input))!.ToJsonString()
                );
            }
        }
    );
    await Test(
        "Duplicate JSON keys rejected",
        () => Reject(() => Task.Run(() => DataEngine.Json("{\"x\":1,\"x\":2}")))
    );
    await Test(
        "YAML JSON exact scalar roundtrip",
        async () =>
        {
            var y = await Run("jsonYAML", [input]);
            var j = await Run("yamlJSON", y.Outputs);
            Check(
                DataEngine.Json(await File.ReadAllTextAsync(j.Outputs[0]))!.ToJsonString()
                    == DataEngine.Json(await File.ReadAllTextAsync(input))!.ToJsonString()
            );
        }
    );
    await Test(
        "YAML alias rejected",
        () =>
            Reject(() => Task.Run(() => DataEngine.Convert("yamlJSON", "a: &a [1]\nb: *a", new())))
    );
    await Test(
        "YAML timestamps rejected",
        () => Reject(() => Task.Run(() => DataEngine.Convert("yamlJSON", "a: 2026-10-21", new())))
    );
    await Test(
        "CSV quoted newline Unicode and delimiter roundtrip",
        async () =>
        {
            string csv = Path.Combine(root, "tabla.csv");
            string text = "name,note\r\n\"niño\",\"a,b\nline\"\r\n";
            await File.WriteAllTextAsync(csv, text);
            var j = await Run("csvJSON", [csv]);
            var c = await Run("jsonCSV", j.Outputs);
            Check(
                DataEngine.Csv(await File.ReadAllTextAsync(c.Outputs[0]), ',')[1][1] == "a,b\nline"
            );
            var t = await Run("csvTSV", [csv]);
            var c2 = await Run("tsvCSV", t.Outputs);
            Check(DataEngine.Csv(await File.ReadAllTextAsync(c2.Outputs[0]), ',')[1][0] == "niño");
        }
    );
    await Test(
        "Malformed CSV rejected",
        () => Reject(() => Task.Run(() => DataEngine.Csv("a,b\n\"unclosed", ',')))
    );
    await Test(
        "CSV heterogeneous rows rejected",
        () => Reject(() => Task.Run(() => DataEngine.Csv("a,b\nx", ',')))
    );
    await Test(
        "JSON nontext values rejected for CSV",
        () => Reject(() => Task.Run(() => DataEngine.Convert("jsonCSV", "[{\"x\":1}]", new())))
    );
    await Test(
        "Markdown blocks active HTML",
        () =>
            Task.Run(() =>
            {
                var (_, html) = DataEngine.Convert(
                    "markdownHTML",
                    "# Hola\n<script>alert(1)</script>",
                    new()
                );
                Check(!html.Contains("<script>"));
                Check(html.Contains("<h1>Hola</h1>"));
            })
    );
    await Test(
        "Unique output collisions and original integrity",
        async () =>
        {
            var a = await Run("jsonPretty", [input]);
            var b = await Run("jsonPretty", [input]);
            Check(a.Outputs[0] != b.Outputs[0]);
            Check(await SafeFiles.Hash(input, default) == hash);
        }
    );
    await Test(
        "Empty and malformed data rejected",
        async () =>
        {
            string f = Path.Combine(root, "empty.json");
            await File.WriteAllTextAsync(f, "");
            await Reject(() => Run("jsonPretty", [f]));
            await File.WriteAllTextAsync(f, "{broken");
            await Reject(() => Run("jsonPretty", [f]));
        }
    );
    foreach (var type in new[] { "zip", "tar", "gzip" })
        await Test(
            type + " roundtrip bytes",
            async () =>
            {
                var archive = await Run(type + "Create", [input]);
                var extract = await Run(type + "Extract", archive.Outputs);
                string file = Directory.Exists(extract.Outputs[0])
                    ? Directory
                        .GetFiles(extract.Outputs[0], "*", SearchOption.AllDirectories)
                        .Single()
                    : extract.Outputs[0];
                Check(await SafeFiles.Hash(file, default) == hash);
            }
        );
    await Test(
        "ZIP traversal rejects and no partial output",
        async () =>
        {
            string file = Path.Combine(root, "traversal.zip");
            using (var zip = ZipFile.Open(file, ZipArchiveMode.Create))
            {
                var e = zip.CreateEntry("../escape.txt");
                using var w = new StreamWriter(e.Open());
                w.Write("no");
            }
            await Reject(() => Run("zipExtract", [file]));
            Check(!File.Exists(Path.Combine(root, "escape.txt")));
            Check(!Directory.EnumerateDirectories(root, ".fluxdrop-*").Any());
        }
    );
    await Test(
        "ZIP symlink rejected",
        async () =>
        {
            string f = Path.Combine(root, "link.zip");
            using (var zip = ZipFile.Open(f, ZipArchiveMode.Create))
            {
                var e = zip.CreateEntry("link");
                e.ExternalAttributes = unchecked((int)0xA1FF0000);
                using var w = new StreamWriter(e.Open());
                w.Write("outside");
            }
            await Reject(() => Run("zipExtract", [f]));
        }
    );
    await Test(
        "TAR traversal rejected",
        async () =>
        {
            string f = Path.Combine(root, "traversal.tar");
            await using (var s = File.Create(f))
            {
                await using var tar = new TarWriter(s);
                using var data = new MemoryStream(Encoding.UTF8.GetBytes("bad"));
                await tar.WriteEntryAsync(
                    new PaxTarEntry(TarEntryType.RegularFile, "../outside") { DataStream = data }
                );
            }
            await Reject(() => Run("tarExtract", [f]));
        }
    );
    await Test(
        "Windows ADS reserved and backslash archive paths rejected",
        async () =>
        {
            foreach (
                var name in new[] { "C:/escape", "x:stream", "..\\escape", "CON.txt", "a/../b" }
            )
                await Reject(() => Task.Run(() => SafeFiles.ExtractName(name)));
        }
    );
    await Test(
        "Cancellation does not publish",
        async () =>
        {
            using var c = new CancellationTokenSource();
            c.Cancel();
            int count = Directory.GetFiles(root).Length;
            await Reject(() =>
                engine.ExecuteAsync(new("jsonPretty", [input], root, new()), null, c.Token)
            );
            Check(Directory.GetFiles(root).Length == count);
        }
    );
    await Test(
        "Rename preview detects collisions",
        () =>
            Reject(() =>
                Task.Run(() => PortableEngine.RenamePreview(["/a/x.txt", "/b/x.txt"], new()))
            )
    );
    await Test(
        "Rename makes verified copies",
        async () =>
        {
            var r = await Run(
                "renameCopy",
                [input],
                new Options { Prefix = "copia-", Number = true }
            );
            Check(await SafeFiles.Hash(Directory.GetFiles(r.Outputs[0]).Single(), default) == hash);
        }
    );
    await Test(
        "Duplicate content report does not delete",
        async () =>
        {
            string copy = Path.Combine(root, "copy.json");
            File.Copy(input, copy);
            var r = await Run("duplicates", [input, copy]);
            var groups = JsonSerializer.Deserialize<string[][]>(
                await File.ReadAllTextAsync(r.Outputs[0])
            )!;
            Check(groups.Length == 1 && groups[0].Length == 2 && File.Exists(copy));
        }
    );
    await Test(
        "Queue restart marks incomplete work interrupted",
        () =>
            Task.Run(() =>
            {
                string store = Path.Combine(root, "queue.json");
                Config.Write(
                    store,
                    new[]
                    {
                        new Job
                        {
                            Request = new("jsonPretty", [input], root, new()),
                            State = JobState.Running,
                        },
                    }
                );
                var q = new JobQueue(engine, store);
                Check(q.Snapshot()[0].State == JobState.Interrupted);
            })
    );
    await Test(
        "Recipes reject commands and incompatible steps",
        async () =>
        {
            await Reject(() =>
                Task.Run(() =>
                    new Recipe(1, "no", [new("shell", new())]).Validate(engine.Capabilities)
                )
            );
            await Reject(() =>
                Task.Run(() =>
                    new Recipe(1, "bad", [new("csvTSV", new()), new("jsonMinify", new())]).Validate(
                        engine.Capabilities
                    )
                )
            );
        }
    );
    await Test(
        "nested recipe passwords are not persisted",
        () =>
            Task.Run(() =>
            {
                var recipe = new Recipe(
                    1,
                    "private",
                    [new("jsonPretty", new Options { Password = "never-persist" })]
                );
                var options = new Options
                {
                    Password = "never-persist",
                    RecipeJson = JsonSerializer.Serialize(recipe, Config.Json),
                };
                Check(
                    !JsonSerializer
                        .Serialize(options.WithoutPasswords(), Config.Json)
                        .Contains("never-persist")
                );
            })
    );
    await Test(
        "invalid nonfinite media options rejected",
        () => Reject(() => Task.Run(() => new Options { Start = double.NaN }.Validate()))
    );
    await Test(
        "queue executes and reports verified output",
        async () =>
        {
            var q = new JobQueue(engine, Path.Combine(root, "live-queue.json"));
            var job = q.Add(new("jsonPretty", [input], root, new()));
            for (int i = 0; i < 100 && job.State is JobState.Pending or JobState.Running; i++)
                await Task.Delay(20);
            Check(job.State == JobState.Complete && job.Outputs.Length == 1);
            DataEngine.Json(await File.ReadAllTextAsync(job.Outputs[0]));
        }
    );
    Console.WriteLine($"RESULT {passed} passed, 0 failed");
    return 0;
}
finally
{
    Directory.Delete(root, true);
}
