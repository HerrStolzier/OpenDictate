import ActivityKit
import OpenDictateCore
import SwiftUI
import WidgetKit

@main
struct OpenDictateWidgets: WidgetBundle {
    var body: some Widget {
        DictationLiveActivity()
    }
}

/// Lock Screen and Dynamic Island while a dictation runs: state word, clock
/// and the stop button. Always in the Nacht theme, like the Dynamic Island.
struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(design: .bg))
                .activitySystemActionForegroundColor(Color(design: .ink))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BlinkView(pose: context.state.pose, small: true, animated: false)
                        .frame(width: 32, height: 32)
                }
                DynamicIslandExpandedRegion(.center) {
                    StateLine(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.phase == .listening { StopButton(compact: true) }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let detail = context.state.detail {
                        Text(detail)
                            .font(BrandFont.sans(13))
                            .foregroundStyle(Color(design: .inkMuted))
                            .lineLimit(2)
                    }
                }
            } compactLeading: {
                BlinkView(pose: context.state.pose, small: true, animated: false)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                if context.state.phase == .listening {
                    Clock(state: context.state)
                        .frame(maxWidth: 44)
                        .foregroundStyle(Color(design: .rec))
                } else {
                    Text(L10n.word(context.state.phase))
                        .font(BrandFont.mono(12, semibold: true))
                        .foregroundStyle(Color(design: context.state.phase == .oops ? .warn : .signal))
                }
            } minimal: {
                BlinkView(pose: context.state.pose, small: true, animated: false)
                    .frame(width: 20, height: 20)
            }
            .keylineTint(Color(design: .signal))
        }
    }
}

private struct LockScreenView: View {
    let state: DictationAttributes.ContentState

    var body: some View {
        HStack(spacing: DesignMetric.space4) {
            BlinkView(pose: state.pose, animated: false)
                .frame(width: 44, height: 50)
            VStack(alignment: .leading, spacing: DesignMetric.space1) {
                StateLine(state: state)
                if let detail = state.detail {
                    Text(detail)
                        .font(BrandFont.sans(14))
                        .foregroundStyle(Color(design: .inkMuted))
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
            if state.phase == .listening { StopButton(compact: false) }
        }
        .padding(DesignMetric.space4)
    }
}

private struct StateLine: View {
    let state: DictationAttributes.ContentState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignMetric.space2) {
            Text(L10n.word(state.phase))
                .font(BrandFont.pixel(22, relativeTo: .title3))
                .foregroundStyle(Color(design: state.phase == .oops ? .warn : .ink))
            if state.phase == .listening {
                Clock(state: state)
                    .foregroundStyle(Color(design: .inkMuted))
            }
        }
    }
}

/// Elapsed time; it stops by itself at the recording limit.
private struct Clock: View {
    let state: DictationAttributes.ContentState

    var body: some View {
        Text(timerInterval: state.startedAt...state.endsAt, countsDown: false, showsHours: false)
            .font(BrandFont.mono(14))
            .monospacedDigit()
    }
}

private struct StopButton: View {
    let compact: Bool

    var body: some View {
        Button(intent: StopDictationIntent()) {
            Label(L10n.stop, systemImage: "stop.fill")
                .labelStyle(.iconOnly)
                .font(.system(size: compact ? 16 : 20, weight: .bold))
                .frame(width: compact ? 36 : 48, height: compact ? 36 : 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(design: .ink))
        .background(Circle().fill(Color(design: .rec)))
        .accessibilityLabel(L10n.stop)
    }
}
