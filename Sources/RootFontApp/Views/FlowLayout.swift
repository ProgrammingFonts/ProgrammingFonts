import SwiftUI

struct FlowLayout: Layout {
    var hSpacing: CGFloat = 12
    var vSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(subviews: subviews, maxWidth: maxWidth)
        let totalHeight = rows.reduce(CGFloat(0)) { acc, row in
            acc + row.height + (acc > 0 ? vSpacing : 0)
        }
        let widestRow = rows.map { $0.width }.max() ?? 0
        return CGSize(width: min(widestRow, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = row.sizes[index - row.indices.lowerBound]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + hSpacing
            }
            y += row.height + vSpacing
        }
    }

    private struct Row {
        var indices: Range<Int>
        var sizes: [CGSize]
        var width: CGFloat
        var height: CGFloat
    }

    private func computeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var startIndex = 0
        var currentX: CGFloat = 0
        var currentHeight: CGFloat = 0
        var currentSizes: [CGSize] = []

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needsNewRow = !currentSizes.isEmpty && (currentX + size.width > maxWidth)

            if needsNewRow {
                rows.append(Row(
                    indices: startIndex..<index,
                    sizes: currentSizes,
                    width: currentX - hSpacing,
                    height: currentHeight
                ))
                startIndex = index
                currentX = 0
                currentHeight = 0
                currentSizes = []
            }

            currentSizes.append(size)
            currentX += size.width + hSpacing
            currentHeight = max(currentHeight, size.height)
        }

        if !currentSizes.isEmpty {
            rows.append(Row(
                indices: startIndex..<subviews.endIndex,
                sizes: currentSizes,
                width: currentX - hSpacing,
                height: currentHeight
            ))
        }

        return rows
    }
}
