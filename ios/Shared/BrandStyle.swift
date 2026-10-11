import OpenDictateCore
import SwiftUI

extension Color {
    init(design color: DesignColor, theme: DesignTheme = .nacht) {
        let value = color.rgb(in: theme)
        self.init(
            .sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255)
    }
}

extension DesignTheme {
    /// Nacht on dark surfaces, Papier on light ones, as on the Mac.
    static func matching(_ scheme: ColorScheme) -> DesignTheme { scheme == .dark ? .nacht : .papier }
}

/// Geist, Geist Mono and Geist Pixel from `design/fonts`, bundled through
/// `UIAppFonts` (SIL Open Font License). SwiftUI falls back to the system font
/// when a file is missing. Sizes scale with Dynamic Type.
enum BrandFont {
    /// The state word. Geist Pixel has one weight; never fake bold.
    static func pixel(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("GeistPixel-Regular", size: size, relativeTo: style)
    }

    /// Times, labels and buttons.
    static func mono(_ size: CGFloat, semibold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(semibold ? "GeistMono-SemiBold" : "GeistMono-Regular", size: size, relativeTo: style)
    }

    /// Running text.
    static func sans(_ size: CGFloat, semibold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(semibold ? "Geist-SemiBold" : "Geist-Regular", size: size, relativeTo: style)
    }
}

/// Blink from `BlinkFigure`, drawn cell by cell like the Mac's `BlinkRenderer`.
/// Motion runs in steps and stops with "Reduce Motion"; Live Activities pass
/// `animated: false` because they do not redraw on their own.
struct BlinkView: View {
    let pose: BlinkPose
    var small = false
    var animated = true
    var theme: DesignTheme = .nacht

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let scene = small ? BlinkFigure.small(pose) : BlinkFigure.scene(pose, framed: true)
        Group {
            if animated && !reduceMotion {
                TimelineView(.periodic(from: .now, by: 1.0 / 12)) { context in
                    BlinkCanvas(
                        scene: scene, time: context.date.timeIntervalSinceReferenceDate, animated: true, theme: theme)
                }
            } else {
                BlinkCanvas(scene: scene, time: 0, animated: false, theme: theme)
            }
        }
        .aspectRatio(CGFloat(scene.width) / CGFloat(scene.height), contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct BlinkCanvas: View {
    let scene: BlinkScene
    let time: Double
    let animated: Bool
    let theme: DesignTheme

    var body: some View {
        Canvas { context, size in
            let fit = min(size.width / CGFloat(scene.width), size.height / CGFloat(scene.height))
            // Whole points keep the cells crisp once the figure is big enough.
            let cell = Double(fit >= 2 ? fit.rounded(.down) : fit)
            let originX = ((Double(size.width) - cell * Double(scene.width)) / 2).rounded()
            let originY = ((Double(size.height) - cell * Double(scene.height)) / 2).rounded()
            for layer in scene.layers {
                let frame = layer.motion?.frame(at: time, animated: animated) ?? BlinkFrame()
                let center = layer.centerX
                for run in layer.runs {
                    let own =
                        run.motion.map { $0.0.frame(at: time, delay: $0.delay, animated: animated) } ?? BlinkFrame()
                    let opacity = frame.opacity * own.opacity * run.color.opacity
                    guard opacity > 0 else { continue }
                    let left = center + (Double(run.x) - center) * frame.scaleX
                    let x = left - Double(scene.boxX) + frame.dx + own.dx
                    let y = Double(run.y - scene.boxY) + frame.dy + own.dy
                    let rect = CGRect(
                        x: originX + (x * cell).rounded(), y: originY + (y * cell).rounded(),
                        width: (Double(run.width) * frame.scaleX * cell).rounded(), height: Double(run.height) * cell)
                    context.fill(Path(rect), with: .color(Color(design: run.color.0, theme: theme).opacity(opacity)))
                }
            }
        }
    }
}

/// The design system's button plate: two steps of `pixel-step` at every
/// corner instead of a rounding.
struct PixelPlate: Shape {
    func path(in rect: CGRect) -> Path {
        let step = CGFloat(DesignMetric.pixelStep)
        let (minX, minY, maxX, maxY) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        let points: [CGPoint] = [
            CGPoint(x: minX, y: minY + 2 * step), CGPoint(x: minX + step, y: minY + 2 * step),
            CGPoint(x: minX + step, y: minY + step), CGPoint(x: minX + 2 * step, y: minY + step),
            CGPoint(x: minX + 2 * step, y: minY), CGPoint(x: maxX - 2 * step, y: minY),
            CGPoint(x: maxX - 2 * step, y: minY + step), CGPoint(x: maxX - step, y: minY + step),
            CGPoint(x: maxX - step, y: minY + 2 * step), CGPoint(x: maxX, y: minY + 2 * step),
            CGPoint(x: maxX, y: maxY - 2 * step), CGPoint(x: maxX - step, y: maxY - 2 * step),
            CGPoint(x: maxX - step, y: maxY - step), CGPoint(x: maxX - 2 * step, y: maxY - step),
            CGPoint(x: maxX - 2 * step, y: maxY), CGPoint(x: minX + 2 * step, y: maxY),
            CGPoint(x: minX + 2 * step, y: maxY - step), CGPoint(x: minX + step, y: maxY - step),
            CGPoint(x: minX + step, y: maxY - 2 * step), CGPoint(x: minX, y: maxY - 2 * step)
        ]
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}
