import AVFoundation
import DonnaShared

/// **Super‑naïve** implementation: one AVAudioRecorder at a time,
/// direct CAF → M4A streaming omitted for brevity.
public actor AudioRecorderManager: AudioRecordingService {

    private var recorder: AVAudioRecorder?
    private var token: SessionToken?

    public init() {}

    public func start() async throws -> SessionToken {
        guard recorder == nil else { throw RecorderError.alreadyRunning }

        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000
        ]
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.record()

        let t = SessionToken()
        token = t
        return t
    }

    public func stop(_ token: SessionToken) async throws -> URL {
        guard token == self.token, let recorder else {
            throw RecorderError.invalidToken
        }
        recorder.stop()
        self.recorder = nil
        self.token = nil
        return recorder.url
    }
}

public enum RecorderError: Error { case alreadyRunning, invalidToken }