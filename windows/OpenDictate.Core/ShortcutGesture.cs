namespace OpenDictate.Core;

// The dictation shortcuts of the Windows app (settings value in brackets):
// Ctrl+Win held [ctrl-win], or right Ctrl alone [right-ctrl] for games whose
// keyboards lock the Windows key. Right Ctrl also toggles with a short tap.
public enum ShortcutKey { CtrlWin, RightCtrl }

public static class VirtualKey
{
    public const int LeftShift = 0xA0, RightShift = 0xA1, LeftCtrl = 0xA2, RightCtrl = 0xA3;
    public const int LeftAlt = 0xA4, RightAlt = 0xA5, LeftWin = 0x5B, RightWin = 0x5C;
    // Unassigned key code. Sent once while Ctrl+Win is held, it makes Windows
    // treat the Win press as a combination, so releasing it opens no Start menu.
    public const int StartMenuMask = 0xE8;
    public const int V = 0x56;
}

public enum ShortcutGestureKind
{
    // Short press and release on its own (only for keys that support taps).
    Tap,
    // Held past the threshold on its own.
    HoldBegan,
    // Released after HoldBegan.
    HoldEnded,
    // Another key arrived after HoldBegan; the hold was not meant for us.
    HoldInterrupted,
}

// HoldDeadline: report it back through HoldDeadlineReached after
// ShortcutGesture.HoldThreshold. MaskStartMenu: send StartMenuMask now.
public readonly record struct ShortcutStep(ShortcutGestureKind? Gesture = null, long? HoldDeadline = null, bool MaskStartMenu = false);

// Turns the physical key events of one shortcut into dictation gestures, as
// ModifierKeyGesture does on macOS. A press counts only while no other key is
// down, so combinations such as Ctrl+Win+D or Right Ctrl+C keep working. The
// caller feeds timestamps and reports deadlines, so the recognizer stays free
// of timers and hooks. Injected keys (including the app's own) never reach it.
public sealed class ShortcutGesture(ShortcutKey key, Func<int, bool>? physicallyDown = null)
{
    public static readonly TimeSpan HoldThreshold = TimeSpan.FromMilliseconds(300);
    private enum Phase { Idle, Pressed, Holding, Spoiled }
    private readonly HashSet<int> down = [];
    private Phase phase;
    private long pressId;
    private long pressedAt;

    public ShortcutKey Key { get; } = key;
    public bool SupportsTap => Key == ShortcutKey.RightCtrl;

    public ShortcutStep KeyDown(int virtualKey, long timestampMs)
    {
        // Key repeat while held changes nothing.
        if (!down.Add(virtualKey)) return default;
        if (!IsShortcutKey(virtualKey))
        {
            if (phase == Phase.Pressed) phase = Phase.Spoiled;
            else if (phase == Phase.Holding) { phase = Phase.Spoiled; return new(ShortcutGestureKind.HoldInterrupted); }
            return default;
        }
        // A second down while holding means a lost key-up; keep the hold so the
        // eventual release still ends it.
        if (phase is Phase.Holding or Phase.Spoiled or Phase.Pressed) return default;
        // A key-up lost to the lock screen or a secure desktop must not block
        // the shortcut until the next restart.
        if (physicallyDown is not null) down.RemoveWhere(held => held != virtualKey && !physicallyDown(held));
        if (down.Any(held => !IsShortcutKey(held))) { phase = Phase.Spoiled; return default; }
        if (!ChordDown()) return default;
        phase = Phase.Pressed;
        pressedAt = timestampMs;
        return new(HoldDeadline: ++pressId, MaskStartMenu: Key == ShortcutKey.CtrlWin);
    }

    public ShortcutStep KeyUp(int virtualKey, long timestampMs)
    {
        down.Remove(virtualKey);
        // A shortcut key whose key-up was lost must not keep the press spoiled.
        if (phase == Phase.Spoiled && physicallyDown is not null) down.RemoveWhere(held => !physicallyDown(held));
        if (!IsShortcutKey(virtualKey)) return default;
        switch (phase)
        {
            case Phase.Pressed:
                phase = down.Any(IsShortcutKey) ? Phase.Spoiled : Phase.Idle;
                return SupportsTap && timestampMs - pressedAt < HoldThreshold.TotalMilliseconds
                    ? new(ShortcutGestureKind.Tap) : default;
            case Phase.Holding:
                // Releasing either key of the chord ends the hold; the other key
                // must come up before the next press.
                phase = down.Any(IsShortcutKey) ? Phase.Spoiled : Phase.Idle;
                return new(ShortcutGestureKind.HoldEnded);
            case Phase.Spoiled:
                if (!down.Any(IsShortcutKey)) phase = Phase.Idle;
                return default;
            default:
                return default;
        }
    }

    public ShortcutStep HoldDeadlineReached(long id)
    {
        if (phase != Phase.Pressed || id != pressId) return default;
        phase = Phase.Holding;
        return new(ShortcutGestureKind.HoldBegan);
    }

    public void Reset() { phase = Phase.Idle; down.Clear(); }

    private bool IsShortcutKey(int virtualKey) => Key switch
    {
        ShortcutKey.CtrlWin => virtualKey is VirtualKey.LeftCtrl or VirtualKey.RightCtrl or VirtualKey.LeftWin or VirtualKey.RightWin,
        _ => virtualKey == VirtualKey.RightCtrl,
    };

    private bool ChordDown() => Key switch
    {
        ShortcutKey.CtrlWin => (down.Contains(VirtualKey.LeftCtrl) || down.Contains(VirtualKey.RightCtrl)) &&
            (down.Contains(VirtualKey.LeftWin) || down.Contains(VirtualKey.RightWin)),
        _ => down.Contains(VirtualKey.RightCtrl),
    };

    public static string SettingsName(ShortcutKey key) => key == ShortcutKey.CtrlWin ? "ctrl-win" : "right-ctrl";

    public static ShortcutKey? Parse(string? name) => name switch
    {
        "ctrl-win" => ShortcutKey.CtrlWin,
        "right-ctrl" => ShortcutKey.RightCtrl,
        _ => null,
    };
}

public enum TriggerAction { None, Start, Stop, CancelKeepingAudio }

// What a gesture does to the dictation, as handleModifierGesture on macOS:
// a tap toggles, a hold records while held, and a hold that another key
// joined was not meant as dictation, so it cancels and keeps the audio.
public sealed class TriggerControl
{
    private enum Hold { None, Started, StopsRecording }
    private Hold hold;

    // recording: the microphone runs. busy: an earlier dictation is still
    // being processed or delivered, so nothing new may start.
    public TriggerAction Handle(ShortcutGestureKind gesture, bool recording, bool busy)
    {
        switch (gesture)
        {
            case ShortcutGestureKind.Tap:
                hold = Hold.None;
                return recording ? TriggerAction.Stop : busy ? TriggerAction.None : TriggerAction.Start;
            case ShortcutGestureKind.HoldBegan:
                if (recording) { hold = Hold.StopsRecording; return TriggerAction.None; }
                if (busy) { hold = Hold.None; return TriggerAction.None; }
                hold = Hold.Started;
                return TriggerAction.Start;
            default:
                var control = hold;
                hold = Hold.None;
                if (!recording) return TriggerAction.None;
                return (control, gesture) switch
                {
                    (Hold.Started, ShortcutGestureKind.HoldInterrupted) => TriggerAction.CancelKeepingAudio,
                    (Hold.Started, _) => TriggerAction.Stop,
                    (Hold.StopsRecording, ShortcutGestureKind.HoldEnded) => TriggerAction.Stop,
                    _ => TriggerAction.None,
                };
        }
    }

    public void Reset() => hold = Hold.None;
}
