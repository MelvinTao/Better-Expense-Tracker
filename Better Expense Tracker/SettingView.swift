import SwiftUI

struct SettingView: View {
    @AppStorage(AppStorageKeys.timeFormatIs24hr) private var is24hr = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Toggle("24-Hour Time", isOn: $is24hr)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingView()
}
