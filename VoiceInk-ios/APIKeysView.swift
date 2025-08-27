import SwiftUI

struct APIKeysView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        List {
            ForEach(Provider.allCases.filter { $0 != .local && $0 != .voiceink }) { provider in
                NavigationLink(destination: ProviderAPIKeyView(provider: provider)) {
                    HStack {
                        Text(provider.rawValue)
                        Spacer()
                        if settings.isKeyVerified(for: provider) {
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
        .navigationTitle("Cloud Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { APIKeysView() }
}