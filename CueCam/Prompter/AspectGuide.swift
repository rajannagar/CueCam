import SwiftUI

/// Framing guides for the camera so you can compose for each platform's aspect ratio.
enum AspectGuide: String, CaseIterable, Identifiable {
    case off, r9x16, r1x1, r16x9

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Free"
        case .r9x16: return "9:16"
        case .r1x1: return "1:1"
        case .r16x9: return "16:9"
        }
    }

    /// width / height of the target frame.
    var ratio: CGFloat? {
        switch self {
        case .off: return nil
        case .r9x16: return 9.0 / 16.0
        case .r1x1: return 1.0
        case .r16x9: return 16.0 / 9.0
        }
    }

    func next() -> AspectGuide {
        let all = AspectGuide.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

/// Dims the area outside the target aspect frame and draws a clean border with
/// rule-of-thirds guides. Non-interactive overlay.
struct AspectGuideOverlay: View {
    let guide: AspectGuide

    var body: some View {
        GeometryReader { geo in
            if let ratio = guide.ratio {
                let frame = fittedRect(in: geo.size, ratio: ratio)
                ZStack {
                    // Dim everything, then punch out the frame.
                    Rectangle()
                        .fill(Color.black.opacity(0.42))
                        .mask(
                            ZStack {
                                Rectangle()
                                Rectangle()
                                    .frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX, y: frame.midY)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        )

                    // Border + rule of thirds
                    let r = RoundedRectangle(cornerRadius: 4, style: .continuous)
                    r.stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)

                    thirds(in: frame)
                }
                .animation(.easeInOut(duration: 0.2), value: guide)
            }
        }
        .allowsHitTesting(false)
    }

    private func thirds(in frame: CGRect) -> some View {
        Path { p in
            for i in 1...2 {
                let x = frame.minX + frame.width * CGFloat(i) / 3
                p.move(to: CGPoint(x: x, y: frame.minY))
                p.addLine(to: CGPoint(x: x, y: frame.maxY))
                let y = frame.minY + frame.height * CGFloat(i) / 3
                p.move(to: CGPoint(x: frame.minX, y: y))
                p.addLine(to: CGPoint(x: frame.maxX, y: y))
            }
        }
        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
    }

    private func fittedRect(in size: CGSize, ratio: CGFloat) -> CGRect {
        var w = size.width
        var h = w / ratio
        if h > size.height {
            h = size.height
            w = h * ratio
        }
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }
}
