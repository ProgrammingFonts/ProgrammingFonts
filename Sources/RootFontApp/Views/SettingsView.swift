import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FontBrowserViewModel

    var body: some View {
        Form {
            Picker(viewModel.tr(.language), selection: Binding(
                get: { viewModel.language },
                set: { viewModel.updateLanguage($0) }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.radioGroup)
        }
        .padding()
        .frame(width: 360)
    }
}
