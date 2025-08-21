import SwiftUI

struct APIKeysView: View {
    var body: some View {
        List {
            ForEach(Provider.allCases.filter { $0 != .local }) { provider in
                NavigationLink(destination: ProviderAPIKeyView(provider: provider)) {
                    HStack {
                        Text(provider.rawValue)
                        Spacer()
                        if AppSettings.shared.isKeyVerified(for: provider) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { APIKeysView() }
}