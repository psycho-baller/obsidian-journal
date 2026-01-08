import Foundation
import AVFoundation
import os

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var audioLevel: Float = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    override init() {
        super.init()
    }

    func startRecording() {
        Logger.audio.info("Initiating recording flow...")
        let recordingSession = AVAudioSession.sharedInstance()

        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)

            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = docDir.appendingPathComponent("recording.m4a")
            Logger.audio.debug("Recording path: \(audioFilename.path)")

            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            recordingURL = nil

            startMonitoring()
            Logger.audio.notice("Recording started.")

        } catch {
            Logger.audio.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        Logger.audio.info("Stopping recording...")
        audioRecorder?.stop()
        isRecording = false
        stopMonitoring()
        recordingURL = audioRecorder?.url
        Logger.audio.notice("Recording stopped. File saved.")
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.audioRecorder?.updateMeters()
            self.audioLevel = self.audioRecorder?.averagePower(forChannel: 0) ?? -160.0
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        audioLevel = 0.0
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            // Handle error
            Logger.audio.error("Audio Recorder finish flag is false.")
            recordingURL = nil
        } else {
            Logger.audio.info("Audio Recorder finished successfully.")
        }
    }
}
