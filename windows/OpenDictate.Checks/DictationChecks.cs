using OpenDictate.Core;

internal static class DictationChecks
{
    internal static async Task<int> RunAsync()
    {
        string root = Path.Combine(Path.GetTempPath(), "opendictate-flow-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            using var original = new PcmJournal(root);
            original.Append([1, 2, 3, 4]);
            byte[] wave = File.ReadAllBytes(original.ExportWave());
            var tests = new (string, Func<Task>)[]
            {
                ("Full recording-transcription-delivery chain", async () =>
                {
                    var order = new List<string>(); var flow = new DictationFlow();
                    var result = await flow.RunAsync(_ => { order.Add("record"); return Task.FromResult(wave); },
                        (audio, _) => { Check(audio.Span.SequenceEqual(wave)); order.Add("transcribe"); return Task.FromResult("Grüße 🧪"); },
                        (text, _) => { Check(text == "Grüße 🧪"); order.Add("deliver"); return Task.FromResult(TextDelivery.Completed); });
                    Check(result.Outcome == DictationOutcome.Delivered && order.SequenceEqual(new[] {"record", "transcribe", "deliver"}) && !flow.IsBusy);
                }),
                ("Empty and oversized responses never deliver", async () =>
                {
                    foreach (string text in new[] {" \n", new string('x', 16001)})
                    {
                        int deliveries = 0;
                        var result = await new DictationFlow().RunAsync(_ => Task.FromResult(wave), (_, _) => Task.FromResult(text),
                            (_, _) => { deliveries++; return Task.FromResult(TextDelivery.Completed); });
                        Check(deliveries == 0 && result.Text is null && result.Outcome != DictationOutcome.Delivered);
                    }
                }),
                ("Preparation and provider failures retain original", async () =>
                {
                    int deliveries = 0, requests = 0;
                    var result = await new DictationFlow().RunAsync(_ => Task.FromException<byte[]>(new IOException()),
                        (_, _) => { requests++; return Task.FromResult("fixture"); },
                        (_, _) => { deliveries++; return Task.FromResult(TextDelivery.Completed); });
                    Check(result.Outcome == DictationOutcome.Failed && requests == 0 && deliveries == 0);
                    result = await new DictationFlow().RunAsync(_ => Task.FromResult(wave),
                        (_, _) => Task.FromException<string>(new HttpRequestException()),
                        (_, _) => { deliveries++; return Task.FromResult(TextDelivery.Completed); });
                    Check(result.Outcome == DictationOutcome.Failed && deliveries == 0 && File.ReadAllBytes(original.RawPath).SequenceEqual(new byte[] {1, 2, 3, 4}));
                }),
                ("Malformed audio never reaches provider", async () =>
                {
                    int requests = 0;
                    var corrupted = wave.ToArray(); corrupted[24] ^= 1;
                    var result = await new DictationFlow().RunAsync(_ => Task.FromResult(corrupted),
                        (_, _) => { requests++; return Task.FromResult("fixture"); }, (_, _) => Task.FromResult(TextDelivery.Completed));
                    Check(result.Outcome == DictationOutcome.Failed && requests == 0);
                }),
                ("Cancelled uncooperative provider stays exclusive and cannot deliver", async () =>
                {
                    var flow = new DictationFlow(); var late = new TaskCompletionSource<string>(); int deliveries = 0;
                    var pending = flow.RunAsync(_ => Task.FromResult(wave), (_, _) => late.Task,
                        (_, _) => { deliveries++; return Task.FromResult(TextDelivery.Completed); });
                    Check(flow.Phase == DictationPhase.Transcribing && flow.Cancel() && flow.IsBusy);
                    bool rejected = false;
                    try { await flow.RunAsync(_ => Task.FromResult(wave), (_, _) => Task.FromResult("second"), (_, _) => Task.FromResult(TextDelivery.Completed)); }
                    catch (InvalidOperationException) { rejected = true; }
                    Check(rejected && !pending.IsCompleted); late.SetResult("late fixture");
                    Check((await pending).Outcome == DictationOutcome.Cancelled && deliveries == 0 && !flow.IsBusy);
                }),
                ("Cancellation during recording suppresses provider", async () =>
                {
                    var flow = new DictationFlow(); var recording = new TaskCompletionSource<byte[]>(); int requests = 0;
                    var pending = flow.RunAsync(_ => recording.Task, (_, _) => { requests++; return Task.FromResult("fixture"); }, (_, _) => Task.FromResult(TextDelivery.Completed));
                    Check(flow.Cancel() && flow.IsBusy); recording.SetResult(wave);
                    Check((await pending).Outcome == DictationOutcome.Cancelled && requests == 0 && File.Exists(original.RawPath));
                }),
                ("Rejected target retains text for manual delivery", async () =>
                {
                    var result = await new DictationFlow().RunAsync(_ => Task.FromResult(wave), (_, _) => Task.FromResult("fixture"), (_, _) => Task.FromResult(TextDelivery.Rejected));
                    Check(result.Outcome == DictationOutcome.ManualDelivery && result.Text == "fixture");
                }),
                ("Dispatch cannot cancel or replay and transport loss is uncertain", async () =>
                {
                    var flow = new DictationFlow(); var delivery = new TaskCompletionSource<TextDelivery>(); int deliveries = 0;
                    var pending = flow.RunAsync(_ => Task.FromResult(wave), (_, _) => Task.FromResult("fixture"),
                        (_, _) => { deliveries++; return delivery.Task; });
                    Check(flow.Phase == DictationPhase.Delivering && !flow.Cancel() && flow.IsBusy);
                    delivery.SetException(new IOException()); var result = await pending;
                    Check(result.Outcome == DictationOutcome.DeliveryUncertain && result.Text == "fixture" && deliveries == 1 && !flow.IsBusy);
                }),
                ("Shutdown cancellation rejects a late response", async () =>
                {
                    using var stop = new CancellationTokenSource(); var late = new TaskCompletionSource<string>(); int deliveries = 0;
                    var pending = new DictationFlow().RunAsync(_ => Task.FromResult(wave), (_, _) => late.Task,
                        (_, _) => { deliveries++; return Task.FromResult(TextDelivery.Completed); }, stop.Token);
                    stop.Cancel(); late.SetResult("late fixture");
                    Check((await pending).Outcome == DictationOutcome.Cancelled && deliveries == 0);
                })
            };
            int failures = 0;
            foreach (var (name, run) in tests)
            {
                try { await run(); Console.WriteLine("PASS " + name); }
                catch (Exception error) { failures++; Console.WriteLine("FAIL " + name + ": " + error.GetType().Name); }
            }
            Console.WriteLine($"{tests.Length - failures}/{tests.Length} dictation flow checks passed; no microphone or network.");
            return failures;
        }
        finally { Directory.Delete(root, true); }
    }
    private static void Check(bool condition) { if (!condition) throw new InvalidOperationException("Assertion failed."); }
}
