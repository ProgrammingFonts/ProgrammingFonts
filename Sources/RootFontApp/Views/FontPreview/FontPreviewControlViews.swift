import SwiftUI

struct FontPreviewSurfacePicker: View {
    @Binding var selection: FontPreviewSurface
    let title: String
    let sampleTitle: String
    let codeTitle: String

    var body: some View {
        Picker(title, selection: $selection) {
            Text(sampleTitle).tag(FontPreviewSurface.sample)
            Text(codeTitle).tag(FontPreviewSurface.code)
        }
        .pickerStyle(.segmented)
    }
}

struct FontPreviewSizeControl: View {
    @Binding var size: Double
    let title: String
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title): \(Int(size)) px")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $size, in: 12...96)
                .onChange(of: size) { _, _ in onChange() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FontPreviewDisplayOptions: View {
    @Binding var singleLine: Bool
    @Binding var monospacedDigits: Bool
    @Binding var expandedLetterSpacing: Bool
    let showsWrapOption: Bool
    let wrapTitle: String
    let digitsTitle: String
    let spacingTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsWrapOption {
                Toggle(wrapTitle, isOn: $singleLine)
                    .toggleStyle(.switch)
            }
            Toggle(digitsTitle, isOn: $monospacedDigits)
                .toggleStyle(.switch)
            Toggle(spacingTitle, isOn: $expandedLetterSpacing)
                .toggleStyle(.switch)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
