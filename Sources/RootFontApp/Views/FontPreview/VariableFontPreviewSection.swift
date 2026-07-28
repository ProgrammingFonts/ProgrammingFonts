import SwiftUI

struct VariableFontPreviewSection: View {
    let title: String
    let axes: [VariableFontAxis]
    @Binding var axisValues: [String: Double]

    var body: some View {
        if !axes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(axes) { axis in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(axis.name)
                                .font(.caption)
                            Spacer()
                            Text(formattedValue(axis))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: binding(for: axis),
                            in: axis.minValue ... axis.maxValue
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func binding(for axis: VariableFontAxis) -> Binding<Double> {
        Binding(
            get: { axisValues[axis.tag] ?? axis.defaultValue },
            set: { axisValues[axis.tag] = $0 }
        )
    }

    private func formattedValue(_ axis: VariableFontAxis) -> String {
        let value = axisValues[axis.tag] ?? axis.defaultValue
        if axis.tag == "wght" || axis.name.localizedCaseInsensitiveContains("weight") {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}
