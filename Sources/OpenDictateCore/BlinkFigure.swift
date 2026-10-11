import Foundation

/// Blink, the brand figure, as pixel cells. The scenes are ported from the
/// design system's web component (`design/components/web/bundle.js`), so the
/// Mac app draws the same figure as the website. Motion follows its CSS: every
/// change happens in steps, and "Bewegung reduzieren" shows the first frame.
public enum BlinkPose: String, CaseIterable, Sendable {
    case bereit, hoert, schreibt, eingefuegt, hoppla
}

/// One horizontal run of same-coloured cells.
public struct BlinkRun: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    /// Colour code of the web component (`B` body, `r` sole light, …).
    public let code: Character

    public init(x: Int, y: Int, width: Int, height: Int = 1, code: Character) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.code = code
    }

    /// Cell-level motion of the web component, with its start delay.
    public var motion: (BlinkMotion, delay: Double)? {
        switch code {
        case "r": (.blink, 0)
        case "a": (.arc, 0.4)
        case "b": (.arc, 0.2)
        case "c": (.arc, 0)
        case "1": (.type, 0)
        case "2": (.type, 0.3)
        case "3": (.type, 0.6)
        default: nil
        }
    }

    /// Design token and opacity for the colour code.
    public var color: (DesignColor, opacity: Double) {
        switch code {
        case "B", "a", "b", "c": (.signal, 1)
        case "L": (.signalLight, 1)
        case "S": (.signalShade, 1)
        case "E", "k": (.signalInk, 1)
        case "K": (.signalDeep, 1)
        case "W": (.sneaker, 1)
        case "w", "y": (.sneakerLight, 1)
        case "V", "G": (.sole, 1)
        case "r", "R", "C": (.rec, 1)
        case "Q": (.glitch, 1)
        case "D": (.floor, 1)
        case "d": (.line, 1)
        case "m": (.inkMuted, 0.6)
        case "1", "2", "3": (.inkMuted, 1)
        case "X": (.ink, 0.8)
        case "Y": (.warn, 1)
        default: (.ink, 1)
        }
    }
}

public struct BlinkLayer: Equatable, Sendable {
    public let motion: BlinkMotion?
    public let runs: [BlinkRun]

    /// Horizontal centre of the drawn cells, the origin for a horizontal scale.
    public var centerX: Double {
        guard let minX = runs.map(\.x).min(), let maxX = runs.map({ $0.x + $0.width }).max() else { return 0 }
        return Double(minX + maxX) / 2
    }
}

public struct BlinkScene: Equatable, Sendable {
    /// Visible part of the grid in cells: origin and size.
    public let boxX: Int
    public let boxY: Int
    public let width: Int
    public let height: Int
    public let layers: [BlinkLayer]
}

/// How a layer or a cell looks at a moment of its animation.
public struct BlinkFrame: Equatable, Sendable {
    public var opacity: Double = 1
    /// Offsets in cells.
    public var dx: Double = 0
    public var dy: Double = 0
    public var scaleX: Double = 1

    public init(opacity: Double = 1, dx: Double = 0, dy: Double = 0, scaleX: Double = 1) {
        self.opacity = opacity
        self.dx = dx
        self.dy = dy
        self.scaleX = scaleX
    }
}

public enum BlinkMotion: String, Sendable {
    case body, blink, arc, type, runA, runB, hop, hopShadow, twinkle, glitch, hopSmall

    public var period: Double {
        switch self {
        case .body: 1.1
        case .blink: 0.8
        case .arc: 1.2
        case .type: 1.8
        case .runA, .runB: 0.36
        case .hop, .hopShadow, .twinkle, .hopSmall: 1.4
        case .glitch: 2.2
        }
    }

    /// The frame at `time` seconds after the figure appeared. `animated: false`
    /// is the still frame for "Bewegung reduzieren".
    public func frame(at time: Double, delay: Double = 0, animated: Bool = true) -> BlinkFrame {
        guard animated else { return still }
        guard time >= delay else {
            // CSS keeps the plain style during a delay, except `backwards` fill.
            return self == .type ? BlinkFrame(opacity: 0) : BlinkFrame()
        }
        let progress = (time - delay).truncatingRemainder(dividingBy: period) / period
        func step(_ stops: [(Double, Double)]) -> Double {
            stops.last(where: { progress >= $0.0 })?.1 ?? stops[0].1
        }
        switch self {
        case .body, .blink: return BlinkFrame(opacity: progress < 0.5 ? 1 : 0)
        case .arc:
            // steps(3) between .2 → 1 → .2.
            let half = progress < 0.5 ? progress * 2 : (progress - 0.5) * 2
            let index = Double(min(2, Int(half * 3)))
            let value = progress < 0.5 ? 0.2 + 0.8 * index / 3 : 1 - 0.8 * index / 3
            return BlinkFrame(opacity: value)
        case .type: return BlinkFrame(opacity: progress < 0.25 ? 0 : 1)
        case .runA: return BlinkFrame(opacity: progress < 0.5 ? 1 : 0)
        case .runB: return BlinkFrame(opacity: progress < 0.5 ? 0 : 1)
        case .hop:
            return BlinkFrame(dy: step([(0, 0), (0.15, -2), (0.25, -4), (0.4, -5), (0.5, -3), (0.6, 0)]))
        case .hopSmall: return BlinkFrame(dy: step([(0, 0), (0.25, -1), (0.6, 0)]))
        case .hopShadow: return BlinkFrame(scaleX: step([(0, 1), (0.25, 0.85), (0.4, 0.75), (0.6, 1)]))
        case .twinkle: return BlinkFrame(opacity: step([(0, 0), (0.4, 1), (0.75, 0)]))
        case .glitch:
            return BlinkFrame(dx: step([(0, 0), (0.08, -1), (0.14, 1), (0.2, 0), (0.6, 1), (0.64, 0)]))
        }
    }

    private var still: BlinkFrame { self == .runB ? BlinkFrame(opacity: 0) : BlinkFrame() }
}

public enum BlinkFigure {
    /// Scenes on the component's 44 × 50 grid. `framed` keeps the full grid so
    /// figures in different poses stand on the same line.
    public static func scene(_ pose: BlinkPose, framed: Bool = false) -> BlinkScene {
        let scene = scenes[pose]!
        guard framed else { return scene }
        return BlinkScene(boxX: 0, boxY: 0, width: Grid.width, height: Grid.height, layers: scene.layers)
    }

    /// The pixel-exact 16 × 16 figure (`design/assets/logos/blink-16.svg`) for
    /// the menu bar, with small per-pose changes: glowing soles while listening
    /// or after an error, a running step while writing, a hop when inserted.
    public static func small(_ pose: BlinkPose) -> BlinkScene {
        let legs: [BlinkRun] = [
            .init(x: 6, y: 11, width: 1, height: 3, code: "K"), .init(x: 8, y: 11, width: 1, height: 3, code: "K")
        ]
        let shoes: (Character) -> [BlinkRun] = { code in
            [.init(x: 5, y: 14, width: 2, code: code), .init(x: 8, y: 14, width: 2, code: code)]
        }
        let body = BlinkLayer(motion: nil, runs: smallBody)
        let layers: [BlinkLayer]
        switch pose {
        case .bereit:
            layers = [BlinkLayer(motion: nil, runs: legs + shoes("W")), BlinkLayer(motion: .body, runs: smallBody)]
        case .hoert:
            layers = [BlinkLayer(motion: nil, runs: legs + shoes("r")), body]
        case .schreibt:
            let spread: [BlinkRun] = [
                .init(x: 5, y: 11, width: 1, height: 3, code: "K"), .init(x: 9, y: 11, width: 1, height: 3, code: "K"),
                .init(x: 4, y: 14, width: 2, code: "W"), .init(x: 9, y: 14, width: 2, code: "W")
            ]
            layers = [
                BlinkLayer(motion: .runA, runs: legs + shoes("W")), BlinkLayer(motion: .runB, runs: spread), body
            ]
        case .eingefuegt:
            layers = [BlinkLayer(motion: .hopSmall, runs: smallBody + legs + shoes("W"))]
        case .hoppla:
            layers = [BlinkLayer(motion: nil, runs: legs + shoes("R")), BlinkLayer(motion: .glitch, runs: smallBody)]
        }
        return BlinkScene(boxX: 0, boxY: 0, width: 16, height: 16, layers: layers)
    }

    private static let smallBody: [BlinkRun] = [
        .init(x: 6, y: 1, width: 3, code: "B"), .init(x: 5, y: 2, width: 1, height: 8, code: "L"),
        .init(x: 6, y: 2, width: 3, height: 8, code: "B"), .init(x: 9, y: 2, width: 1, height: 8, code: "S"),
        .init(x: 6, y: 10, width: 3, code: "B")
    ]

    private static let scenes: [BlinkPose: BlinkScene] = Dictionary(
        uniqueKeysWithValues: BlinkPose.allCases.map { ($0, build($0)) })

    private static func build(_ pose: BlinkPose) -> BlinkScene {
        switch pose {
        case .bereit:
            let ox = 12
            var back = Grid()
            var legs = Grid()
            var body = Grid()
            back.shadow(ox - 2, ox + 21, 48)
            legs.standLegs(ox, "G")
            body.body(ox)
            return BlinkScene(
                boxX: 9, boxY: 0, width: 26, height: 50,
                layers: [back.layer(nil), legs.layer(nil), body.layer(.body)])
        case .hoert:
            let ox = 18
            var grid = Grid()
            grid.arcs(cx: ox - 3, cy: 18)
            grid.shadow(ox - 2, ox + 21, 48)
            grid.standLegs(ox, "r")
            grid.body(ox)
            return full([grid.layer(nil)])
        case .schreibt:
            let ox = 17
            var back = Grid()
            var runA = Grid()
            var runB = Grid()
            var body = Grid()
            back.rect(4, 8, 7, 1, "m")
            back.rect(1, 15, 8, 1, "m")
            back.rect(4, 22, 7, 1, "m")
            back.rect(0, 31, 4, 2, "1")
            back.rect(5, 31, 6, 2, "2")
            back.rect(12, 31, 2, 2, "3")
            back.shadow(ox, ox + 20, 48)
            runA.leg(ox + 8, 40, 6, -1)
            runA.shoeR(ox - 1, 45, "G")
            runA.leg(ox + 9, 40, 4, 1)
            runA.shoeR(ox + 11, 43, "G")
            runB.leg(ox + 8, 40, 6, 0)
            runB.shoeR(ox + 6, 45, "G")
            runB.leg(ox + 8, 40, 3, -1)
            runB.shoeR(ox - 1, 41, "G")
            body.body(ox, shear: 1)
            return full([back.layer(nil), runA.layer(.runA), runB.layer(.runB), body.layer(nil)])
        case .eingefuegt:
            let ox = 18
            var back = Grid()
            var figure = Grid()
            var front = Grid()
            back.rect(0, 18, 5, 4, "X")
            back.rect(6, 18, 7, 4, "X")
            back.rect(14, 18, 2, 4, "X")
            back.shadow(ox - 2, ox + 21, 48)
            figure.standLegs(ox, "G")
            figure.body(ox)
            for (x, y) in [
                (41, 0), (41, 1), (41, 2), (41, 4), (41, 5), (41, 6), (38, 3), (39, 3), (40, 3), (42, 3), (43, 3)
            ] {
                front.put(x, y, "Y")
            }
            front.put(41, 3, "y")
            return full([back.layer(.hopShadow), figure.layer(.hop), front.layer(.twinkle)])
        case .hoppla:
            let ox = 14
            var back = Grid()
            var figure = Grid()
            back.shadow(ox - 2, ox + 21, 48)
            back.standLegs(ox, "R")
            figure.body(ox - 2, flat: "C")
            figure.body(ox + 2, flat: "Q")
            figure.body(ox)
            figure.clearRow(11)
            figure.clearRow(26)
            figure.shift(12...15, by: 3)
            figure.shift(27...30, by: -3)
            return full([back.layer(nil), figure.layer(.glitch)])
        }
    }

    private static func full(_ layers: [BlinkLayer]) -> BlinkScene {
        BlinkScene(boxX: 0, boxY: 0, width: Grid.width, height: Grid.height, layers: layers)
    }
}

/// The web component's drawing helpers on a character grid.
private struct Grid {
    static let width = 44
    static let height = 50
    private static let drawn = Set("BLSEKkWwVGrRDdabcm123XYyCQ")
    var cells = Array(repeating: Array(repeating: Character("."), count: width), count: height)

    mutating func put(_ x: Int, _ y: Int, _ code: Character) {
        guard (0..<Self.height).contains(y), (0..<Self.width).contains(x) else { return }
        cells[y][x] = code
    }

    mutating func rect(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ code: Character) {
        for row in 0..<height { for column in 0..<width { put(x + column, y + row, code) } }
    }

    private static func bodyCell(_ row: Int, _ column: Int) -> Character {
        if row == 0 { return column <= 14 ? "L" : "B" }
        if row == 39 { return "E" }
        if column <= 2 { return "L" }
        if column == 3 { return row % 2 == 1 ? "L" : "B" }
        if column == 15 { return row % 2 == 1 ? "S" : "B" }
        if column >= 16 { return "S" }
        return "B"
    }

    mutating func body(_ ox: Int, shear: Int = 0, flat: Character? = nil) {
        for row in 0..<40 {
            let offset = shear == 0 ? 0 : ((39 - row) / 10) * shear
            var range = 0...19
            if row == 0 || row == 39 { range = 2...17 } else if row == 1 || row == 38 { range = 1...18 }
            for column in range { put(ox + column + offset, row, flat ?? Self.bodyCell(row, column)) }
        }
    }

    mutating func shoeL(_ x: Int, _ y: Int, _ sole: Character) {
        rect(x + 1, y, 6, 1, "W")
        put(x + 2, y, "w")
        put(x + 3, y, "w")
        rect(x, y + 1, 8, 1, "W")
        put(x + 7, y + 1, "V")
        rect(x, y + 2, 8, 1, sole)
    }

    mutating func shoeR(_ x: Int, _ y: Int, _ sole: Character) {
        rect(x + 1, y, 6, 1, "W")
        put(x + 4, y, "w")
        put(x + 5, y, "w")
        rect(x, y + 1, 8, 1, "W")
        put(x, y + 1, "V")
        rect(x, y + 2, 8, 1, sole)
    }

    mutating func leg(_ x: Int, _ y: Int, _ count: Int, _ dx: Int) {
        for step in 0..<count {
            let column = x + step * dx
            put(column, y + step, "K")
            put(column + 1, y + step, "K")
            put(column + 2, y + step, "k")
        }
    }

    mutating func standLegs(_ ox: Int, _ sole: Character) {
        leg(ox + 4, 40, 6, 0)
        leg(ox + 13, 40, 6, 0)
        shoeL(ox - 1, 45, sole)
        shoeR(ox + 12, 45, sole)
    }

    mutating func shadow(_ x0: Int, _ x1: Int, _ y: Int) {
        rect(x0 + 1, y, x1 - x0 - 1, 1, "D")
        put(x0, y, "d")
        put(x1, y, "d")
    }

    mutating func arcs(cx: Int, cy: Int) {
        for (radius, code) in [(4.0, Character("a")), (8.0, "b"), (12.0, "c")] {
            for degrees in stride(from: 128, through: 232, by: 2) {
                let angle = Double(degrees) * .pi / 180
                // JavaScript's Math.round rounds halves up.
                let x = Int((Double(cx) + radius * cos(angle) + 0.5).rounded(.down))
                let y = Int((Double(cy) + radius * sin(angle) * 1.25 + 0.5).rounded(.down))
                put(x, y, code)
            }
        }
    }

    mutating func clearRow(_ row: Int) {
        cells[row] = Array(repeating: ".", count: Self.width)
    }

    mutating func shift(_ rows: ClosedRange<Int>, by dx: Int) {
        for row in rows {
            let old = cells[row]
            clearRow(row)
            for (x, code) in old.enumerated() where code != "." { put(x + dx, row, code) }
        }
    }

    func layer(_ motion: BlinkMotion?) -> BlinkLayer {
        var runs: [BlinkRun] = []
        for (y, row) in cells.enumerated() {
            var x = 0
            while x < row.count {
                let code = row[x]
                var width = 1
                while x + width < row.count, row[x + width] == code { width += 1 }
                if Self.drawn.contains(code) { runs.append(BlinkRun(x: x, y: y, width: width, code: code)) }
                x += width
            }
        }
        return BlinkLayer(motion: motion, runs: runs)
    }
}
