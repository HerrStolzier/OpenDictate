namespace OpenDictate.Core;

public enum AttemptKind { Recording, Insertion }

// Owned by the UI thread. A focus change permanently invalidates the attempt,
// even if the user returns to the original field before completion.
public sealed class AttemptGate
{
    private long generation;
    private string? target;
    private bool invalidated;
    private bool delivering;

    public AttemptKind? Kind { get; private set; }
    public bool IsBusy => Kind is not null;
    public bool IsDelivering => delivering;

    public long Begin(AttemptKind kind, string? targetIdentity = null)
    {
        if (IsBusy) throw new InvalidOperationException("An attempt is already active.");
        Kind = kind;
        target = targetIdentity;
        invalidated = false;
        delivering = false;
        return ++generation;
    }

    public void ObserveFocus(string? identity)
    {
        if (Kind == AttemptKind.Insertion && !StringComparer.Ordinal.Equals(target, identity))
            invalidated = true;
    }

    public bool CanInsert(long ticket, string? currentIdentity, bool modifiersReleased) =>
        ticket == generation && Kind == AttemptKind.Insertion && !invalidated && !delivering &&
        target is not null && StringComparer.Ordinal.Equals(target, currentIdentity) && modifiersReleased;

    public bool BeginDelivery(long ticket)
    {
        if (ticket != generation || Kind != AttemptKind.Insertion || target is null || invalidated || delivering)
            return false;
        delivering = true;
        return true;
    }

    public bool Complete(long ticket)
    {
        if (ticket != generation || !IsBusy) return false;
        Kind = null;
        target = null;
        delivering = false;
        return true;
    }

    public bool Cancel()
    {
        if (delivering) return false; // Dispatched edits cannot be unsent.
        ++generation;
        Kind = null;
        target = null;
        invalidated = true;
        return true;
    }
}
