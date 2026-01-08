import AVFoundation
import SwiftUI

class PermissionsManager: ObservableObject {
    @Published var microphonePermission: PermissionStatus = .notDetermined

    enum PermissionStatus {
        case notDetermined
        case denied
        case authorized
    }

    init() {
        checkMicrophonePermission()
    }

    func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            microphonePermission = .notDetermined
        case .denied:
            microphonePermission = .denied
        case .granted:
            microphonePermission = .authorized
        @unknown default:
            microphonePermission = .notDetermined
        }
    }

    func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphonePermission = granted ? .authorized : .denied
            }
        }
    }
}
