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
    var dimText: Double = 1.0          // camera mode dims text slightly for legibility over video

    var body: some View {
        ZStack {
            ScrollingText(scroll: engine.scroll, engine: engine, text: text,
                          fontSize: fontSize, font: font, textColor: textColor,
                          mirror: mirror, bold: bold, dimText: dimText)
            focalGuides
            if let n = engine.countdown { countdownOverlay(n) }
        }
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
    let dimText: Double

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font.font(size: fontSize, bold: bold))
                .foregroundStyle(textColor)
                .lineSpacing(fontSize * 0.32)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(dimText < 1 ? 0.7 : 0), radius: 6, y: 1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: geo.size.width - 48, alignment: .top)
                .padding(.horizontal, 24)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
                    }
                )
                .offset(y: scroll.offset)
                .scaleEffect(x: mirror ? -1 : 1, y: 1)
                .opacity(dimText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onPreferenceChange(HeightKey.self) { engine.contentHeight = $0 }
                .onAppear {
                    engine.firstLineLead = fontSize * 0.6
                    engine.containerHeight = geo.size.height
                }
                .onChange(of: geo.size) { _, s in engine.containerHeight = s.height }
                .onChange(of: fontSize) { _, s in engine.firstLineLead = s * 0.6 }
        }
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
