// Generated from design/tokens.json by scripts/design-tokens.py. Do not edit.

public enum DesignTheme: String, CaseIterable, Sendable {
    case nacht
    case bernstein
    case papier
}

public enum DesignColor: String, CaseIterable, Sendable {
    case bg = "bg"
    case surface = "surface"
    case surfaceSunken = "surface-sunken"
    case line = "line"
    case ink = "ink"
    case inkMuted = "ink-muted"
    case signal = "signal"
    case signalLight = "signal-light"
    case signalShade = "signal-shade"
    case signalDeep = "signal-deep"
    case signalInk = "signal-ink"
    case onSignal = "on-signal"
    case rec = "rec"
    case warn = "warn"
    case sneaker = "sneaker"
    case sneakerLight = "sneaker-light"
    case sole = "sole"
    case floor = "floor"
    case glitch = "glitch"
    case focusRing = "focus-ring"

    /// sRGB value as 0xRRGGBB.
    public func rgb(in theme: DesignTheme) -> UInt32 {
        switch (self, theme) {
        case (.bg, .nacht):
            return 0x0E1014
        case (.bg, .bernstein):
            return 0x17110A
        case (.bg, .papier):
            return 0xEDEEE9
        case (.surface, .nacht):
            return 0x181C23
        case (.surface, .bernstein):
            return 0x22190F
        case (.surface, .papier):
            return 0xFFFFFF
        case (.surfaceSunken, .nacht):
            return 0x12151A
        case (.surfaceSunken, .bernstein):
            return 0x120D07
        case (.surfaceSunken, .papier):
            return 0xE2E4DD
        case (.line, .nacht):
            return 0x2A303A
        case (.line, .bernstein):
            return 0x3A2C1B
        case (.line, .papier):
            return 0xC9CCC3
        case (.ink, .nacht):
            return 0xE9EEE2
        case (.ink, .bernstein):
            return 0xFFE9C7
        case (.ink, .papier):
            return 0x14161A
        case (.inkMuted, .nacht):
            return 0x8F988A
        case (.inkMuted, .bernstein):
            return 0xB49A74
        case (.inkMuted, .papier):
            return 0x585D63
        case (.signal, .nacht):
            return 0xB6FF4D
        case (.signal, .bernstein):
            return 0xFFB23F
        case (.signal, .papier):
            return 0x1A4FE0
        case (.signalLight, .nacht):
            return 0xDDFFA8
        case (.signalLight, .bernstein):
            return 0xFFD796
        case (.signalLight, .papier):
            return 0x7F9DFF
        case (.signalShade, .nacht):
            return 0x86CC2E
        case (.signalShade, .bernstein):
            return 0xD98E22
        case (.signalShade, .papier):
            return 0x1440B8
        case (.signalDeep, .nacht):
            return 0x7AB82A
        case (.signalDeep, .bernstein):
            return 0xB8741A
        case (.signalDeep, .papier):
            return 0x12389F
        case (.signalInk, .nacht):
            return 0x5E9420
        case (.signalInk, .bernstein):
            return 0x8F5810
        case (.signalInk, .papier):
            return 0x0C2A7A
        case (.onSignal, .nacht):
            return 0x0E1014
        case (.onSignal, .bernstein):
            return 0x17110A
        case (.onSignal, .papier):
            return 0xFFFFFF
        case (.rec, .nacht):
            return 0xFF5D5D
        case (.rec, .bernstein):
            return 0xFF6A4D
        case (.rec, .papier):
            return 0xB52A1A
        case (.warn, .nacht):
            return 0xFFD84D
        case (.warn, .bernstein):
            return 0xFFEFB0
        case (.warn, .papier):
            return 0x8A5A00
        case (.sneaker, .nacht):
            return 0xF2F5EE
        case (.sneaker, .bernstein):
            return 0xFFF3DE
        case (.sneaker, .papier):
            return 0x2A2F38
        case (.sneakerLight, .nacht):
            return 0xFFFFFF
        case (.sneakerLight, .bernstein):
            return 0xFFFFFF
        case (.sneakerLight, .papier):
            return 0x4A515E
        case (.sole, .nacht):
            return 0x9AA394
        case (.sole, .bernstein):
            return 0xB49A74
        case (.sole, .papier):
            return 0x585D63
        case (.floor, .nacht):
            return 0x07080A
        case (.floor, .bernstein):
            return 0x0A0704
        case (.floor, .papier):
            return 0xC9CCC3
        case (.glitch, .nacht):
            return 0x5CE1E6
        case (.glitch, .bernstein):
            return 0x5CE1E6
        case (.glitch, .papier):
            return 0x008C95
        case (.focusRing, .nacht):
            return 0xB6FF4D
        case (.focusRing, .bernstein):
            return 0xFFB23F
        case (.focusRing, .papier):
            return 0x1A4FE0
        }
    }
}

/// Lengths in points; `radiusIcon` is a fraction of the icon size.
public enum DesignMetric {
    public static let space1: Double = 4.0
    public static let space2: Double = 8.0
    public static let space3: Double = 12.0
    public static let space4: Double = 16.0
    public static let space6: Double = 24.0
    public static let space8: Double = 32.0
    public static let space12: Double = 48.0
    public static let space16: Double = 64.0
    public static let radiusChip: Double = 8.0
    public static let radiusCard: Double = 18.0
    public static let radiusIcon: Double = 0.225
    public static let pixelStep: Double = 3.0
    public static let pixelIcon: Double = 36.0
    public static let meterCell: Double = 8.0
    public static let meterGap: Double = 3.0
}

public struct DesignTextStyle: Equatable, Sendable {
    public let family: String
    public let size: Double
    public let lineHeight: Double
    public let weight: Int
    /// Letter spacing as a fraction of `size` (CSS em); 0 when the style sets none.
    public let tracking: Double
}

public enum DesignFont {
    public static let pixel = "Geist Pixel"
    public static let mono = "Geist Mono"
    public static let sans = "Geist"

    public static let display = DesignTextStyle(
        family: pixel, size: 64.0, lineHeight: 64.0, weight: 400, tracking: -0.01)
    public static let title = DesignTextStyle(
        family: pixel, size: 40.0, lineHeight: 44.0, weight: 400, tracking: 0.0)
    public static let heading = DesignTextStyle(
        family: pixel, size: 24.0, lineHeight: 30.0, weight: 400, tracking: 0.0)
    public static let lead = DesignTextStyle(
        family: sans, size: 18.0, lineHeight: 28.0, weight: 400, tracking: 0.0)
    public static let body = DesignTextStyle(
        family: sans, size: 15.0, lineHeight: 24.0, weight: 400, tracking: 0.0)
    public static let strong = DesignTextStyle(
        family: sans, size: 15.0, lineHeight: 24.0, weight: 600, tracking: 0.0)
    public static let small = DesignTextStyle(
        family: sans, size: 13.0, lineHeight: 20.0, weight: 400, tracking: 0.0)
    public static let ui = DesignTextStyle(
        family: mono, size: 14.0, lineHeight: 20.0, weight: 600, tracking: 0.0)
    public static let label = DesignTextStyle(
        family: mono, size: 12.0, lineHeight: 16.0, weight: 400, tracking: 0.02)
    public static let code = DesignTextStyle(
        family: mono, size: 13.0, lineHeight: 20.0, weight: 400, tracking: 0.0)
}
