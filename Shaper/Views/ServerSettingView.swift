import SwiftUI

struct ServerSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var address: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("服务器地址")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                TextField("http://127.0.0.1:8000", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)

                Text("建议使用本机局域网地址或 127.0.0.1。")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(20)
            .navigationTitle("服务器设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        appState.serverAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                address = appState.serverAddress
            }
        }
    }
}

#Preview {
    ServerSettingView()
        .environmentObject(AppState())
}
