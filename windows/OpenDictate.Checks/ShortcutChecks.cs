using System.Globalization;
using OpenDictate.Core;
using OpenDictate.Provider;
using static OpenDictate.Core.VirtualKey;

// Shortcut recognition, trigger decisions, the paste rule, settings and the
// indicator lines of the Windows app. Synthetic key events only.
internal static class ShortcutChecks
{
    internal static int Run()
    {
        var previous = CultureInfo.CurrentUICulture;
        CultureInfo.CurrentUICulture = new CultureInfo("de-DE");
        var tests = new (string, Action)[]
        {
            ("Ctrl+Win held begins after the deadline and ends on release, masking the Start menu", () =>
            {
                var gesture = new ShortcutGesture(ShortcutKey.CtrlWin);
                Check(gesture.KeyDown(LeftCtrl, 0) == default);
                var press = gesture.KeyDown(LeftWin, 10);
                Check(press.HoldDeadline is not null && press.MaskStartMenu && press.Gesture is null);
                Check(gesture.HoldDeadlineReached(press.HoldDeadline!.Value).Gesture == ShortcutGestureKind.HoldBegan);
                Check(gesture.KeyUp(LeftWin, 2000).Gesture == ShortcutGestureKind.HoldEnded);
                Check(gesture.KeyUp(LeftCtrl, 2010) == default);
            }),
            ("Ctrl+Win works in either order and with either side", () =>
            {
                foreach (var (first, second) in new[] { (RightWin, RightCtrl), (LeftWin, LeftCtrl), (RightCtrl, LeftWin) })
                {
                    var gesture = new ShortcutGesture(ShortcutKey.CtrlWin);
                    gesture.KeyDown(first, 0);
                    var press = gesture.KeyDown(second, 5);
                    Check(gesture.HoldDeadlineReached(press.HoldDeadline!.Value).Gesture == ShortcutGestureKind.HoldBegan);
                    Check(gesture.KeyUp(first, 900).Gesture == ShortcutGestureKind.HoldEnded);
                }
            }),
            ("A short press of Ctrl+Win does nothing; a short right Ctrl is a tap", () =>
            {
                var chord = new ShortcutGesture(ShortcutKey.CtrlWin);
                chord.KeyDown(LeftCtrl, 0); chord.KeyDown(LeftWin, 0);
                Check(chord.KeyUp(LeftWin, 100) == default && chord.KeyUp(LeftCtrl, 110) == default);
                var single = new ShortcutGesture(ShortcutKey.RightCtrl);
                var press = single.KeyDown(RightCtrl, 0);
                Check(press.HoldDeadline is not null && !press.MaskStartMenu);
                Check(single.KeyUp(RightCtrl, 120).Gesture == ShortcutGestureKind.Tap);
                single.KeyDown(RightCtrl, 1000);
                Check(single.KeyUp(RightCtrl, 1400) == default);
            }),
            ("Left Ctrl alone never triggers the right Ctrl shortcut", () =>
            {
                var gesture = new ShortcutGesture(ShortcutKey.RightCtrl);
                Check(gesture.KeyDown(LeftCtrl, 0) == default && gesture.KeyUp(LeftCtrl, 50) == default);
            }),
            ("Another key during the press keeps combinations such as Ctrl+Win+D working", () =>
            {
                var gesture = new ShortcutGesture(ShortcutKey.CtrlWin);
                gesture.KeyDown(LeftCtrl, 0);
                var press = gesture.KeyDown(LeftWin, 0);
                Check(gesture.KeyDown(0x44, 50) == default);
                Check(gesture.HoldDeadlineReached(press.HoldDeadline!.Value) == default);
                Check(gesture.KeyUp(0x44, 80) == default && gesture.KeyUp(LeftWin, 90) == default && gesture.KeyUp(LeftCtrl, 95) == default);
                var next = gesture.KeyDown(LeftCtrl, 1000);
                next = gesture.KeyDown(LeftWin, 1001);
                Check(gesture.HoldDeadlineReached(next.HoldDeadline!.Value).Gesture == ShortcutGestureKind.HoldBegan);
            }),
            ("Right Ctrl+C stays a copy and no tap", () =>
            {
                var gesture = new ShortcutGesture(ShortcutKey.RightCtrl);
                gesture.KeyDown(RightCtrl, 0); gesture.KeyDown(0x43, 30); gesture.KeyUp(0x43, 60);
                Check(gesture.KeyUp(RightCtrl, 90) == default);
            }),
            ("Another key during the hold interrupts it once", () =>
            {
                var gesture = new ShortcutGesture(ShortcutKey.RightCtrl);
                var press = gesture.KeyDown(RightCtrl, 0);
                gesture.HoldDeadlineReached(press.HoldDeadline!.Value);
                Check(gesture.KeyDown(LeftShift, 500).Gesture == ShortcutGestureKind.HoldInterrupted);
                Check(gesture.KeyUp(LeftShift, 600) == default && gesture.KeyUp(RightCtrl, 700) == default);
            }),
            ("A key held before the shortcut makes the press not count", () =>
            {
                var gesture = new ShortcutGesture(ShortcutKey.RightCtrl);
                gesture.KeyDown(LeftShift, 0);
                Check(gesture.KeyDown(RightCtrl, 10) == default);
                gesture.KeyUp(LeftShift, 20);
                Check(gesture.KeyUp(RightCtrl, 30) == default);
            }),
            ("Key repeat and stale deadlines change nothing", () =>
            {
                var gesture = new ShortcutGesture(ShortcutKey.RightCtrl);
                var first = gesture.KeyDown(RightCtrl, 0);
                Check(gesture.KeyDown(RightCtrl, 30) == default && gesture.KeyDown(RightCtrl, 60) == default);
                gesture.KeyUp(RightCtrl, 100);
                var second = gesture.KeyDown(RightCtrl, 400);
                Check(gesture.HoldDeadlineReached(first.HoldDeadline!.Value) == default);
                Check(gesture.HoldDeadlineReached(second.HoldDeadline!.Value).Gesture == ShortcutGestureKind.HoldBegan);
                Check(gesture.KeyDown(RightCtrl, 800) == default);
                Check(gesture.KeyUp(RightCtrl, 900).Gesture == ShortcutGestureKind.HoldEnded);
            }),
            ("A key-up lost to the lock screen does not block the shortcut", () =>
            {
                var blocked = new ShortcutGesture(ShortcutKey.RightCtrl);
                blocked.KeyDown(0x4C, 0);
                Check(blocked.KeyDown(RightCtrl, 5000) == default);
                var pruned = new ShortcutGesture(ShortcutKey.RightCtrl, key => key == RightCtrl);
                pruned.KeyDown(0x4C, 0);
                Check(pruned.KeyDown(RightCtrl, 5000).HoldDeadline is not null);
            }),
            ("A shortcut key-up lost while a press was spoiled does not block the next press", () =>
            {
                var held = new HashSet<int>();
                var gesture = new ShortcutGesture(ShortcutKey.CtrlWin, held.Contains);
                foreach (int key in new[] { LeftCtrl, LeftWin, 0x44 }) { held.Add(key); gesture.KeyDown(key, 0); }
                // Win's key-up is lost; D and Ctrl come up normally.
                held.Clear();
                gesture.KeyUp(0x44, 50); gesture.KeyUp(LeftCtrl, 60);
                held.Add(LeftCtrl); gesture.KeyDown(LeftCtrl, 1000);
                held.Add(LeftWin);
                var press = gesture.KeyDown(LeftWin, 1001);
                Check(gesture.HoldDeadlineReached(press.HoldDeadline!.Value).Gesture == ShortcutGestureKind.HoldBegan);
            }),
            ("Trigger: a hold records while held, a tap toggles", () =>
            {
                var control = new TriggerControl();
                Check(control.Handle(ShortcutGestureKind.HoldBegan, recording: false, busy: false) == TriggerAction.Start);
                Check(control.Handle(ShortcutGestureKind.HoldEnded, recording: true, busy: true) == TriggerAction.Stop);
                Check(control.Handle(ShortcutGestureKind.Tap, recording: false, busy: false) == TriggerAction.Start);
                Check(control.Handle(ShortcutGestureKind.Tap, recording: true, busy: true) == TriggerAction.Stop);
            }),
            ("Trigger: holding during a tapped recording stops it on release", () =>
            {
                var control = new TriggerControl();
                Check(control.Handle(ShortcutGestureKind.HoldBegan, recording: true, busy: true) == TriggerAction.None);
                Check(control.Handle(ShortcutGestureKind.HoldEnded, recording: true, busy: true) == TriggerAction.Stop);
                control.Handle(ShortcutGestureKind.HoldBegan, recording: true, busy: true);
                Check(control.Handle(ShortcutGestureKind.HoldInterrupted, recording: true, busy: true) == TriggerAction.None);
            }),
            ("Trigger: an interrupted hold cancels and keeps the audio; nothing overlaps", () =>
            {
                var control = new TriggerControl();
                control.Handle(ShortcutGestureKind.HoldBegan, recording: false, busy: false);
                Check(control.Handle(ShortcutGestureKind.HoldInterrupted, recording: true, busy: true) == TriggerAction.CancelKeepingAudio);
                Check(control.Handle(ShortcutGestureKind.HoldBegan, recording: false, busy: true) == TriggerAction.None);
                Check(control.Handle(ShortcutGestureKind.HoldEnded, recording: false, busy: true) == TriggerAction.None);
                Check(control.Handle(ShortcutGestureKind.Tap, recording: false, busy: true) == TriggerAction.None);
                // A recording that failed to start leaves nothing to stop.
                control.Handle(ShortcutGestureKind.HoldBegan, recording: false, busy: false);
                Check(control.Handle(ShortcutGestureKind.HoldEnded, recording: false, busy: false) == TriggerAction.None);
            }),
            ("Paste only into the captured window, still in front, with the transcript on the clipboard", () =>
            {
                var target = new WindowTarget(42, 7, 1000);
                Check(PastePolicy.MayPaste(true, target, target with { }, "Text", "Text", true, 99));
                Check(!PastePolicy.MayPaste(false, target, target, "Text", "Text", true, 99));
                Check(!PastePolicy.MayPaste(true, null, target, "Text", "Text", true, 99));
                Check(!PastePolicy.MayPaste(true, target, target with { Window = 43 }, "Text", "Text", true, 99));
                Check(!PastePolicy.MayPaste(true, target, target with { ProcessStartTicks = 1001 }, "Text", "Text", true, 99));
                Check(!PastePolicy.MayPaste(true, target, null, "Text", "Text", true, 99));
                Check(!PastePolicy.MayPaste(true, target, target, "Other", "Text", true, 99));
                Check(!PastePolicy.MayPaste(true, target, target, null, "Text", true, 99));
                Check(!PastePolicy.MayPaste(true, target, target, "Text", "Text", false, 99));
                Check(!PastePolicy.MayPaste(true, target, target, "Text", "Text", true, 7));
                Check(!PastePolicy.MayPaste(true, new WindowTarget(0, 7, 1000), new WindowTarget(0, 7, 1000), "Text", "Text", true, 99));
            }),
            ("Settings default to Ctrl+Win, automatic paste and an unconfirmed shortcut", () =>
            {
                var settings = DictationSettings.Default;
                Check(settings.ShortcutKey == ShortcutKey.CtrlWin && settings.Shortcut == "ctrl-win");
                Check(settings.AutoInsert && !settings.ShortcutConfirmed);
                Check(ShortcutGesture.Parse("right-ctrl") == ShortcutKey.RightCtrl && ShortcutGesture.Parse("Ctrl+Win") is null);
            }),
            ("Shortcut settings round-trip; an unknown shortcut is refused, the file kept", () => InTemporaryDirectory(folder =>
            {
                string path = Path.Combine(folder, "settings.json");
                var saved = DictationSettings.Default with { Shortcut = "right-ctrl", ShortcutConfirmed = true, AutoInsert = false };
                SettingsFile.Save(path, saved);
                string json = File.ReadAllText(path);
                Check(json.Contains("\"shortcut\": \"right-ctrl\"") && json.Contains("\"auto_insert\": false") &&
                    json.Contains("\"shortcut_confirmed\": true") && !json.Contains("shortcut_key"));
                Check(SettingsFile.Load(path) == saved);
                Throws<UserFacingException>(() => SettingsFile.Save(path, saved with { Shortcut = "f9" }));
                File.WriteAllText(path, "{\"shortcut\": \"f9\"}");
                Throws<UserFacingException>(() => SettingsFile.Load(path));
                Check(File.ReadAllText(path) == "{\"shortcut\": \"f9\"}");
                File.WriteAllText(path, "{\"model\": \"gpt-transcribe\"}");
                var older = SettingsFile.Load(path);
                Check(older.ShortcutKey == ShortcutKey.CtrlWin && older.AutoInsert && !older.ShortcutConfirmed);
            })),
            ("Indicator words and lines follow the brand in German and English", () =>
            {
                Check(IndicatorText.Word(IndicatorPhase.Listening) == "Hört zu" && IndicatorText.Word(IndicatorPhase.Oops) == "Hoppla");
                Check(IndicatorText.Detail(IndicatorPhase.Listening, TimeSpan.FromSeconds(7)) == "REC 0:07");
                Check(IndicatorText.Detail(IndicatorPhase.Listening, TimeSpan.FromSeconds(82.5)) == "REC · Stopp in 8 s");
                Check(IndicatorText.Detail(IndicatorPhase.Writing, translating: true) == "Wird übersetzt");
                Check(IndicatorText.ClosesAfter(IndicatorPhase.Inserted) == TimeSpan.FromSeconds(2) && IndicatorText.ClosesAfter(IndicatorPhase.Oops) is null);
                CultureInfo.CurrentUICulture = new CultureInfo("en-US");
                try
                {
                    Check(IndicatorText.Word(IndicatorPhase.Writing) == "Writing" && IndicatorText.Word(IndicatorPhase.Inserted) == "Pasted");
                    Check(IndicatorText.Detail(IndicatorPhase.Listening, TimeSpan.FromSeconds(85)) == "REC · stops in 5 s");
                }
                finally { CultureInfo.CurrentUICulture = new CultureInfo("de-DE"); }
            }),
            ("An ending says the recording is saved only when it was", () =>
            {
                var failed = new DictationResult(DictationOutcome.Failed, Message: "Keine Verbindung.");
                Check(IndicatorText.Ending(failed, saved: true) == (IndicatorPhase.Oops, "Keine Verbindung. Deine Aufnahme ist gesichert."));
                Check(IndicatorText.Ending(failed, saved: false) == (IndicatorPhase.Oops, "Keine Verbindung."));
                Check(IndicatorText.Ending(new(DictationOutcome.Delivered, "x"), true)?.Phase == IndicatorPhase.Inserted);
                Check(IndicatorText.Ending(new(DictationOutcome.ManualDelivery, "x"), true)?.Phase == IndicatorPhase.Copied);
                Check(IndicatorText.Ending(new(DictationOutcome.Cancelled), true) is null);
                Check(IndicatorText.Ending(new(DictationOutcome.Failed), false)?.Reason == "Das hat nicht geklappt.");
            }),
        };
        int failures = 0;
        try
        {
            foreach (var (name, run) in tests)
            {
                try { run(); Console.WriteLine($"PASS {name}"); }
                catch (Exception error) { ++failures; Console.WriteLine($"FAIL {name}: {error.GetType().Name}"); }
            }
        }
        finally { CultureInfo.CurrentUICulture = previous; }
        Console.WriteLine($"{tests.Length - failures}/{tests.Length} shortcut and app checks passed; synthetic key events only.");
        return failures;
    }

    private static void Check(bool condition) { if (!condition) throw new InvalidOperationException("Assertion failed."); }

    private static void Throws<T>(Action action) where T : Exception
    {
        try { action(); } catch (T) { return; }
        throw new InvalidOperationException($"Expected {typeof(T).Name}.");
    }

    private static void InTemporaryDirectory(Action<string> action)
    {
        var directory = Path.Combine(Path.GetTempPath(), "opendictate-shortcut-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try { action(directory); }
        finally { Directory.Delete(directory, true); } // Only this test's synthetic files.
    }
}
