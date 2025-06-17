import SwiftUI
import DonnaShared

struct ContentView: View {
    @State private var token: SessionToken?

    var body: some View {
        VStack(spacing: 24) {
            Button("Start") {
                Task {
                    let recorder = AppDependencyManager.shared
                        .resolve(AudioRecordingService.self)
                    token = try? await recorder.start()
                }
            }
            .disabled(token != nil)

            Button("Stop") {
                guard let token else { return }
                Task {
                    let recorder = AppDependencyManager.shared
                        .resolve(AudioRecordingService.self)
                    _ = try? await recorder.stop(token)
                    self.token = nil
                }
            }
            .disabled(token == nil)
        }
        .font(.title)
        .padding()
    }
}