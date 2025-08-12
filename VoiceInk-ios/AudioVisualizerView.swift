import SwiftUI

struct AudioVisualizerView: View {
    let levels: [CGFloat]  // values in 0...1
    @Environment(\.colorScheme) private var colorScheme

    private var barColor: Color { Color(UIColor.tertiaryLabel) }

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let h = height(for: i, in: proxy.size)
                    Capsule()
                        .fill(barColor)
                        .frame(width: barWidth(in: proxy.size), height: h)
                        .animation(.easeOut(duration: 0.12), value: levels)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 48)
        .accessibilityLabel("Audio level visualizer")
    }

    private var barCount: Int { 8 }

    private func barWidth(in size: CGSize) -> CGFloat {
        max(2, (size.width - 16) / CGFloat(barCount) - 3)
    }

    private func height(for index: Int, in size: CGSize) -> CGFloat {
        // Sample evenly from the tail of the history for a simple, minimal equalizer
        guard !levels.isEmpty else { return 4 }
        let span = max(1, min(levels.count, barCount))
        let step = max(1, levels.count / span)
        let srcIndex = max(0, levels.count - 1 - (index * step))
        let level = levels[srcIndex]
        let minH: CGFloat = 4
        let maxH = size.height
        let clamped = max(0, min(1, level))
        let h = minH + (maxH - minH) * clamped
        return h
    }
}

#Preview {
    AudioVisualizerView(levels: (0..<40).map { _ in .random(in: 0.05...0.7) })
        .padding()
}


