import SwiftUI

/// The moving text plus focal guides and countdown overlay. Used by both the screen
/// prompter and the camera prompter. It does not draw a background, so the camera
/// feed (or a theme color placed behind it) shows through.
struct PrompterCanvas: View {
    @EnvironmentObject private var tm: ThemeManager
    @ObservedObject var engine: PrompterEngine
    let text: String
    let fontSize: Double
    let font: PrompterFont
    let textColor: Color
    let mirror: Bool
    var bold: Bool = false
    var karaoke: Bool = false
    var dimText: Double = 1.0          // camera mode dims text slightly for legibility over video

    var body: some View {
        ZStack {
            ScrollingText(scroll: engine.scroll, engine: engine, text: text,
                          fontSize: fontSize, font: font, textColor: textColor,
                          mirror: mirror, bold: bold, karaoke: karaoke,
                          focalFraction: engine.focalFraction, dimText: dimText)
            focalGuides
            if let n = engine.countdown { countdownOverlay(n) }
        }
        // The script is one tall text block extending far beyond the screen.
        // Clip that overflow (generously, so nothing visible is cut at the safe
        // areas) or it bleeds over other screens during the dismiss transition.
        .clipShape(Rectangle().inset(by: -150))
    }

    private var focalGuides: some View {
        GeometryReader { geo in
            let y = geo.size.height * engine.focalFraction
            ZStack {
                Triangle().fill(tm.accent).frame(width: 15, height: 20)
                    .rotationEffect(.degrees(90)).position(x: 16, y: y)
                Triangle().fill(tm.accent).frame(width: 15, height: 20)
                    .rotationEffect(.degrees(-90)).position(x: geo.size.width - 16, y: y)
                LinearGradient(
                    colors: [tm.accent.opacity(0), tm.accent.opacity(0.12), tm.accent.opacity(0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: fontSize * 1.35)
                .position(x: geo.size.width / 2, y: y)
            }
        }
        .allowsHitTesting(false)
    }

    private func countdownOverlay(_ n: Int) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            Text("\(n)")
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .foregroundStyle(tm.accentGradient)
                .id(n)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        }
        .allowsHitTesting(false)
    }
}

/// The only view that re-renders every frame. It observes just the scroll offset, so
/// the rest of the prompter UI stays still while this glides.
private struct ScrollingText: View {
    @ObservedObject var scroll: ScrollModel
    let engine: PrompterEngine            // plain reference: layout writes only, not observed
    let text: String
    let fontSize: Double
    let font: PrompterFont
    let textColor: Color
    let mirror: Bool
    let bold: Bool
    let karaoke: Bool
    let focalFraction: CGFloat
    let dimText: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base layer (dimmed when karaoke is on), and the layer that measures height.
                textLayer(width: geo.size.width, measure: true)
                    .opacity(dimText * (karaoke ? 0.30 : 1))

                // Bright "spotlight" line at the reading position.
                if karaoke {
                    textLayer(width: geo.size.width, measure: false)
                        .opacity(dimText)
                        .mask(spotlight(in: geo.size))
                }
            }
            .onAppear {
                engine.firstLineLead = fontSize * 0.6
                engine.containerHeight = geo.size.height
            }
            .onChange(of: geo.size) { _, s in engine.containerHeight = s.height }
            .onChange(of: fontSize) { _, s in engine.firstLineLead = s * 0.6 }
        }
    }

    private func textLayer(width: CGFloat, measure: Bool) -> some View {
        Text(text)
            .font(font.font(size: fontSize, bold: bold))
            .foregroundStyle(textColor)
            .lineSpacing(fontSize * 0.32)
            .multilineTextAlignment(.center)
            // Legibility shadow over live video only. Kept tight: a wide shadow
            // on a screen-sized text layer is a real per-frame GPU cost.
            .shadow(color: .black.opacity(dimText < 1 ? 0.7 : 0), radius: dimText < 1 ? 3 : 0, y: 1)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width - 48, alignment: .top)
            .padding(.horizontal, 24)
            .background(
                measure
                    ? GeometryReader { proxy in
                        Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
                    }
                    : nil
            )
            .offset(y: scroll.offset)
            .scaleEffect(x: mirror ? -1 : 1, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onPreferenceChange(HeightKey.self) { if measure { engine.contentHeight = $0 } }
    }

    /// A soft horizontal band fixed at the reading line, used to reveal the bright text.
    private func spotlight(in size: CGSize) -> some View {
        let y = size.height * focalFraction
        return LinearGradient(
            colors: [.clear, .black, .black, .clear],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: fontSize * 2.6)
        .position(x: size.width / 2, y: y)
    }
}

/// Hairline progress bar that tracks the scroll without re-rendering its parent.
struct PrompterProgressBar: View {
    @ObservedObject var scroll: ScrollModel
    let engine: PrompterEngine
    var trackColor: Color = .white.opacity(0.12)

    private var progress: CGFloat {
        let s = engine.startOffset, e = engine.endOffset
        guard s > e else { return 0 }
        return min(1, max(0, (s - scroll.offset) / (s - e)))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule().fill(.tint)
                    .frame(width: max(0, geo.size.width * progress))
            }
            .frame(height: 3)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 6).padding(.horizontal, 20)
        }
        .allowsHitTesting(false)
        .opacity(engine.contentHeight > engine.containerHeight ? 1 : 0)
    }
}

struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
