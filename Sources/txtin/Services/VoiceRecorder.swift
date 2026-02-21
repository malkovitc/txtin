import Foundation
import AVFoundation

enum VoiceRecorderError: LocalizedError {
    case failedToStart
    case noRecordingInProgress

    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Failed to start microphone recording"
        case .noRecordingInProgress:
            return "No recording in progress"
        }
    }
}

final class VoiceRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var currentFileURL: URL?

    func start() throws -> URL {
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("txtin-\(Int(Date().timeIntervalSince1970 * 1000)).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw VoiceRecorderError.failedToStart
        }

        self.recorder = recorder
        self.currentFileURL = fileURL
        return fileURL
    }

    func stop() throws -> URL {
        guard let recorder, let fileURL = currentFileURL else {
            throw VoiceRecorderError.noRecordingInProgress
        }

        recorder.stop()
        self.recorder = nil
        self.currentFileURL = nil
        return fileURL
    }

    var isRecording: Bool {
        recorder?.isRecording == true
    }
}
