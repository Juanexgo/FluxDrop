using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace FluxDrop.Core;

public enum JobState
{
    Pending,
    Running,
    Complete,
    Failed,
    Cancelled,
    Interrupted,
}

public sealed class Job : INotifyPropertyChanged
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Request Request { get; set; } = new("", [], "", new());
    public JobState State { get; set; } = JobState.Pending;
    public string[] Outputs { get; set; } = [];
    public string Error { get; set; } = "";
    public double? Progress { get; set; }
    public DateTimeOffset Created { get; set; } = DateTimeOffset.Now;
    public string Display =>
        Request.Operation
        + " · "
        + string.Join(", ", Request.Inputs.Select(Path.GetFileName))
        + " · "
        + State
        + (Progress.HasValue ? " " + (Progress.Value * 100).ToString("0") + "%" : "")
        + (Error.Length > 0 ? " · " + Error : "");
    public event PropertyChangedEventHandler? PropertyChanged;

    public void Changed() =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Display)));
}

public sealed class JobQueue
{
    readonly IEngine engine;
    readonly string store;
    readonly SemaphoreSlim gate = new(1, 1);
    readonly List<Job> jobs = [];
    readonly Dictionary<Guid, CancellationTokenSource> running = [];
    readonly SynchronizationContext? context = SynchronizationContext.Current;
    public bool Paused { get; private set; }
    public bool KeepHistory { get; set; } = true;
    public int Concurrency { get; set; } = 2;
    public event Action? Changed;

    public JobQueue(IEngine engine, string store)
    {
        this.engine = engine;
        this.store = store;
        foreach (var job in Config.Read<List<Job>>(store) ?? [])
        {
            if (job.State is JobState.Running or JobState.Pending)
            {
                job.State = JobState.Interrupted;
                job.Error = "Interrumpido al cerrar la app. Reintenta explícitamente.";
            }
            jobs.Add(job);
        }
        Save();
    }

    public Job[] Snapshot()
    {
        lock (jobs)
            return jobs.ToArray();
    }

    void Notify(Job? j = null)
    {
        void Apply(object? _)
        {
            j?.Changed();
            Changed?.Invoke();
        }
        if (context != null)
            context.Post(Apply, null);
        else
            Apply(null);
    }

    void Save()
    {
        lock (jobs)
            Config.Write(
                store,
                jobs.Where(j => KeepHistory || j.State is JobState.Pending or JobState.Running)
                    .Select(j => new Job
                    {
                        Id = j.Id,
                        Request = j.Request with { Options = j.Request.Options.WithoutPasswords() },
                        State = j.State,
                        Outputs = j.Outputs,
                        Error = j.Error,
                        Created = j.Created,
                    })
                    .ToList()
            );
    }

    public Job Add(Request request) => AddMany([request])[0];

    public Job[] AddMany(IEnumerable<Request> requests)
    {
        var added = new List<Job>();
        foreach (var request in requests)
        {
            request.Options.Validate();
            if (!engine.Capabilities.Any(c => c.Id == request.Operation))
                throw new ArgumentException("Operación desconocida.");
            if (request.Inputs.Length is < 1 or > 10000 || added.Count >= 10000)
                throw new ArgumentException("Máximo 10 000 entradas por lote.");
            foreach (var path in request.Inputs)
                SafeFiles.Input(path);
            added.Add(new Job { Request = request });
        }
        lock (jobs)
            jobs.AddRange(added);
        Save();
        Notify();
        _ = Pump();
        return added.ToArray();
    }

    public void PausePending(bool value)
    {
        Paused = value;
        Notify();
        if (!value)
            _ = Pump();
    }

    public void Cancel(Guid id)
    {
        lock (jobs)
        {
            if (running.TryGetValue(id, out var c))
                c.Cancel();
            var j = jobs.FirstOrDefault(j => j.Id == id);
            if (j?.State == JobState.Pending)
                j.State = JobState.Cancelled;
        }
        Save();
        Notify();
    }

    public void CancelAll()
    {
        lock (jobs)
        {
            foreach (var source in running.Values)
                source.Cancel();
            foreach (var job in jobs.Where(j => j.State == JobState.Pending))
                job.State = JobState.Cancelled;
        }
        Save();
        Notify();
    }

    public void Retry(Guid id)
    {
        var j = Snapshot().First(x => x.Id == id);
        if (j.State is not (JobState.Failed or JobState.Cancelled or JobState.Interrupted))
            return;
        Add(j.Request);
    }

    public void ClearHistory()
    {
        lock (jobs)
            jobs.RemoveAll(j => j.State is not (JobState.Pending or JobState.Running));
        Save();
        Notify();
    }

    async Task Pump()
    {
        await gate.WaitAsync();
        try
        {
            while (!Paused)
            {
                Job? next;
                CancellationTokenSource source;
                lock (jobs)
                {
                    if (running.Count >= Math.Clamp(Concurrency, 1, 4))
                        break;
                    next = jobs.FirstOrDefault(j => j.State == JobState.Pending);
                    if (next == null)
                        break;
                    source = new();
                    running[next.Id] = source;
                    next.State = JobState.Running;
                }
                Save();
                Notify(next);
                _ = Task.Run(() => Run(next, source));
            }
        }
        finally
        {
            gate.Release();
        }
    }

    async Task Run(Job job, CancellationTokenSource source)
    {
        try
        {
            var p = new Progress<double?>(x =>
            {
                job.Progress = x;
                Notify(job);
            });
            var result = await engine.ExecuteAsync(job.Request, p, source.Token);
            job.Outputs = result.Outputs;
            job.Error = result.Detail;
            job.Progress = 1;
            job.State = JobState.Complete;
        }
        catch (OperationCanceledException)
        {
            job.State = JobState.Cancelled;
            job.Progress = null;
        }
        catch (Exception ex)
        {
            job.State = JobState.Failed;
            job.Error =
                ex is UnauthorizedAccessException
                    ? "Sin permisos. Elige otra carpeta de destino."
                    : ex.Message;
            job.Progress = null;
        }
        finally
        {
            lock (jobs)
                running.Remove(job.Id);
            source.Dispose();
            Save();
            Notify(job);
            await Pump();
        }
    }
}
