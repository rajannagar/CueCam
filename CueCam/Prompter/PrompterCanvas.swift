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
    var dimText: Double = 1.0          // camera mode dims text slightly for legibility over video

    var body: some View {
        ZStack {
            scrollingText
            focalGuides
            if let n = engine.countdown { countdownOverlay(n) }
        }
    }

    private var scrollingText: some View {
        GeometryReader { geo in
            Text(text)
                .font(.system(size: fontSize, weight: .semibold, design: font.design))
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
                .offset(y: engine.offset)
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
