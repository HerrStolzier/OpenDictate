import AppKit
import CoreText
import OpenDictateCore

/// Geist, Geist Mono and Geist Pixel from the app bundle (SIL Open Font
/// License, `Resources/Fonts/OFL.txt`). Falls back to system fonts when the
/// files are missing, for example in `swift test`.
@MainActor
enum BrandFonts {
    private static var registered = false

    static func register() {
        guard !registered else { return }
        registered = true
        for directory in fontDirectories() {
            let files =
                (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            let fonts = files.filter { $0.pathExtension.lowercased() == "ttf" }
            guard !fonts.isEmpty else { continue }
            for font in fonts { CTFontManagerRegisterFontsForURL(font as CFURL, .process, nil) }
            return
        }
        AppLog.write("Brand fonts not found; using system fonts")
    }

    private static func fontDirectories() -> [URL] {
        var directories = [Bundle.main.resourceURL?.appendingPathComponent("Fonts")].compactMap { $0 }
        #if DEBUG
            // `swift run` and previews start outside a bundle; use the checkout's copy.
            directories.append(
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("design/fonts"))
            var folder = Bundle.main.executableURL?.deletingLastPathComponent()
            while let current = folder, current.path != "/" {
                directories.append(current.appendingPathComponent("design/fonts"))
                folder = current.deletingLastPathComponent()
            }
        #endif
        return directories
    }

    /// Geist Pixel: the state word. It has one weight; never fake bold.
    static func pixel(_ size: CGFloat) -> NSFont {
        NSFont(name: "GeistPixel-Regular", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// Geist Mono: times, labels, buttons and shortcuts.
    static func mono(_ size: CGFloat, semibold: Bool = false) -> NSFont {
        NSFont(name: semibold ? "GeistMono-SemiBold" : "GeistMono-Regular", size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: semibold ? .semibold : .regular)
    }

    /// Geist: running text.
    static func sans(_ size: CGFloat, semibold: Bool = false) -> NSFont {
        NSFont(name: semibold ? "Geist-SemiBold" : "Geist-Regular", size: size)
            ?? .systemFont(ofSize: size, weight: semibold ? .semibold : .regular)
    }

    /// A generated text style (`DesignFont`) with its family, size and weight.
    static func font(_ style: DesignTextStyle) -> NSFont {
        let size = CGFloat(style.size)
        switch style.family {
        case DesignFont.pixel: return pixel(size)
        case DesignFont.mono: return mono(size, semibold: style.weight >= 600)
        default: return sans(size, semibold: style.weight >= 600)
        }
    }

    /// The style's line height as a fixed paragraph height, for running text.
    static func paragraph(_ style: DesignTextStyle) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = CGFloat(style.lineHeight)
        paragraph.maximumLineHeight = CGFloat(style.lineHeight)
        return paragraph
    }
}

extension DesignTheme {
    /// Nacht on dark surfaces, Papier on light ones.
    static func matching(_ appearance: NSAppearance) -> DesignTheme {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .nacht : .papier
    }
}

extension NSColor {
    convenience init(design color: DesignColor, theme: DesignTheme = .nacht, opacity: Double = 1) {
        let value = color.rgb(in: theme)
        self.init(
            srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: opacity)
    }
}

/// Draws Blink scenes from `BlinkFigure` cell by cell, with crisp edges.
@MainActor
enum BlinkRenderer {
    /// `origin` is the top-left corner in a flipped context; `cell` is the size
    /// of one grid cell in points. `time` drives the stepped motion.
    static func draw(
        _ scene: BlinkScene, at origin: CGPoint, cell: CGFloat, time: Double, animated: Bool,
        theme: DesignTheme = .nacht, silhouette: NSColor? = nil
    ) {
        NSGraphicsContext.current?.shouldAntialias = false
        defer { NSGraphicsContext.current?.shouldAntialias = true }
        for layer in scene.layers {
            let frame = layer.motion?.frame(at: time, animated: animated) ?? BlinkFrame()
            let center = layer.centerX
            for run in layer.runs {
                let own = run.motion.map { $0.0.frame(at: time, delay: $0.delay, animated: animated) } ?? BlinkFrame()
                let opacity = frame.opacity * own.opacity * (silhouette == nil ? run.color.opacity : 1)
                guard opacity > 0 else { continue }
                let left: Double = center + (Double(run.x) - center) * frame.scaleX
                let x: Double = left - Double(scene.boxX) + frame.dx + own.dx
                let y: Double = Double(run.y - scene.boxY) + frame.dy + own.dy
                let width: Double = Double(run.width) * frame.scaleX * Double(cell)
                let rect = NSRect(
                    x: origin.x + CGFloat((x * Double(cell)).rounded()),
                    y: origin.y + CGFloat((y * Double(cell)).rounded()),
                    width: CGFloat(width.rounded()), height: CGFloat(run.height) * cell)
                let color = silhouette ?? NSColor(design: run.color.0, theme: theme)
                color.withAlphaComponent(opacity).setFill()
                rect.fill(using: .sourceOver)
            }
        }
    }

    /// One-colour Blink for the menu bar; macOS tints it for light and dark bars.
    static func statusBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            draw(BlinkFigure.small(.bereit), at: .zero, cell: 1, time: 0, animated: false, silhouette: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "OpenDictate"
        return image
    }

    /// 12 × 12 pixel symbols from the design system (`PixelIcon`).
    static func drawGlyph(_ rows: [String], at origin: CGPoint, cell: CGFloat, color: NSColor) {
        color.setFill()
        for (y, row) in rows.enumerated() {
            for (x, character) in row.enumerated() where character == "X" {
                NSRect(x: origin.x + CGFloat(x) * cell, y: origin.y + CGFloat(y) * cell, width: cell, height: cell)
                    .fill(using: .sourceOver)
            }
        }
    }
}

/// Glyph rows of the design system's `PixelIcon` component.
enum PixelGlyph {
    static let rec = [
        "............", "............", "....XXXX....", "...XXXXXX...", "..XXXXXXXX..", "..XXXXXXXX..",
        "..XXXXXXXX..", "..XXXXXXXX..", "...XXXXXX...", "....XXXX....", "............", "............"
    ]
    static let check = [
        "............", "............", "..........X.", ".........XX.", "........XX..", ".X.....XX...",
        ".XX...XX....", "..XX.XX.....", "...XXX......", "....X.......", "............", "............"
    ]
    static let error = [
        "............", ".....XX.....", ".....XX.....", ".....XX.....", ".....XX.....", ".....XX.....",
        ".....XX.....", ".....XX.....", "............", ".....XX.....", ".....XX.....", "............"
    ]
    static let prompt = [
        "............", "............", "...XX.......", "....XX......", ".....XX.....", "......XX....",
        ".....XX.....", "....XX......", "...XX.......", "............", "............", "............"
    ]
}

/// The design system's button: Geist Mono on a plate with stepped pixel
/// corners, 44 pt high. Native NSButton semantics and accessibility.
@MainActor
final class PixelButton: NSButton {
    let primary: Bool

    init(title: String, primary: Bool, target: AnyObject?, action: Selector) {
        self.primary = primary
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        font = BrandFonts.mono(14, semibold: true)
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var intrinsicContentSize: NSSize {
        let width = (title as NSString).size(withAttributes: [.font: font ?? BrandFonts.mono(14)]).width
        return NSSize(width: ceil(width) + 36, height: 44)
    }

    override func drawFocusRingMask() { plate(in: bounds).fill() }
    override var focusRingMaskBounds: NSRect { bounds }

    override func draw(_ dirtyRect: NSRect) {
        let pressed = cell?.isHighlighted == true
        let fill = NSColor(design: primary ? .signal : .line)
        (pressed ? fill.blended(withFraction: 0.12, of: .black) ?? fill : fill).setFill()
        plate(in: bounds.offsetBy(dx: 0, dy: pressed ? 1 : 0)).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? BrandFonts.mono(14, semibold: true),
            .foregroundColor: NSColor(design: primary ? .onSignal : .ink)
        ]
        let size = (title as NSString).size(withAttributes: attributes)
        (title as NSString).draw(
            at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2 + (pressed ? 1 : 0)),
            withAttributes: attributes)
    }

    /// Two steps of `pixel-step` (3 pt) at every corner instead of a rounding.
    private func plate(in rect: NSRect) -> NSBezierPath {
        let step = DesignMetric.pixelStep
        let (minX, minY, maxX, maxY) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        let points: [(CGFloat, CGFloat)] = [
            (minX, minY + 2 * step), (minX + step, minY + 2 * step), (minX + step, minY + step),
            (minX + 2 * step, minY + step), (minX + 2 * step, minY), (maxX - 2 * step, minY),
            (maxX - 2 * step, minY + step), (maxX - step, minY + step), (maxX - step, minY + 2 * step),
            (maxX, minY + 2 * step), (maxX, maxY - 2 * step), (maxX - step, maxY - 2 * step),
            (maxX - step, maxY - step), (maxX - 2 * step, maxY - step), (maxX - 2 * step, maxY),
            (minX + 2 * step, maxY), (minX + 2 * step, maxY - step), (minX + step, maxY - step),
            (minX + step, maxY - 2 * step), (minX, maxY - 2 * step)
        ]
        let path = NSBezierPath()
        path.move(to: NSPoint(x: points[0].0, y: points[0].1))
        for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
        path.close()
        return path
    }
}
