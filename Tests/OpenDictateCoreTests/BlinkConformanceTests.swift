import Foundation
import JavaScriptCore
import Testing

@testable import OpenDictateCore

/// Runs the design system's own web component and compares every pixel run,
/// so the Swift port cannot drift from the figure on the website.
@Suite("Blink matches the design system")
struct BlinkConformanceTests {
    private static let bundle = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("design/components/web/bundle.js")

    private static let motions: [String: BlinkMotion] = [
        "od-a-body": .body, "od-a-run-a": .runA, "od-a-run-b": .runB, "od-a-hop": .hop,
        "od-a-hop-shadow": .hopShadow, "od-a-twinkle": .twinkle, "od-a-glitch": .glitch
    ]

    @Test(arguments: BlinkPose.allCases) func sceneEqualsWebComponent(pose: BlinkPose) throws {
        let source = try String(contentsOf: Self.bundle, encoding: .utf8)
        let context = try #require(JSContext())
        context.evaluateScript(
            """
            var window = { React: { createElement: function (type, props) {
              var kids = Array.prototype.slice.call(arguments, 2);
              return { type: type, props: props || {}, children: [].concat.apply([], kids) };
            } } };
            """)
        context.evaluateScript(source)
        let result = context.evaluateScript(
            """
            (function () {
              var svg = window.OpenDictate.Blink({ state: '\(pose.rawValue)' });
              return JSON.stringify({ box: svg.props.viewBox, layers: svg.children.map(function (g) {
                return { cls: g.props.className || '', runs: g.children.map(function (r) {
                  return [r.props.x, r.props.y, r.props.width, r.props.className.split(' ')[0].slice(6)];
                }) };
              }) });
            })()
            """)
        let json = try #require(result?.toString())
        #expect(context.exception == nil)
        let decoded = try JSONDecoder().decode(WebScene.self, from: Data(json.utf8))

        let scene = BlinkFigure.scene(pose)
        #expect(decoded.box == "\(scene.boxX) \(scene.boxY) \(scene.width) \(scene.height)")
        #expect(decoded.layers.count == scene.layers.count)
        for (web, swift) in zip(decoded.layers, scene.layers) {
            #expect(Self.motions[web.cls] == swift.motion)
            let webRuns = web.runs.map { "\($0.x),\($0.y),\($0.width),\($0.code)" }
            let swiftRuns = swift.runs.map { "\($0.x),\($0.y),\($0.width),\($0.code)" }
            #expect(webRuns == swiftRuns)
        }
    }
}

private struct WebScene: Decodable {
    struct Layer: Decodable {
        let cls: String
        let runs: [Run]
    }
    struct Run: Decodable {
        let x: Int
        let y: Int
        let width: Int
        let code: String

        init(from decoder: Decoder) throws {
            var values = try decoder.unkeyedContainer()
            x = try values.decode(Int.self)
            y = try values.decode(Int.self)
            width = try values.decode(Int.self)
            code = try values.decode(String.self)
        }
    }
    let box: String
    let layers: [Layer]
}
