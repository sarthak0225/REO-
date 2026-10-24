import Foundation
import SwiftUI

@MainActor
public final class VoiceActivityManager: ObservableObject {
    public static let shared = VoiceActivityManager()
    
    @Published public private(set) var isVoiceModeActive: Bool = false
    
    private init() {}
    
    public func toggleVoiceMode(onTranscriptCompleted: @escaping @Sendable (String) -> Void) {
        if isVoiceModeActive {
            stopVoiceMode()
        } else {
            startVoiceMode(onTranscriptCompleted: onTranscriptCompleted)
        }
    }
    
    public func startVoiceMode(onTranscriptCompleted: @escaping @Sendable (String) -> Void) {
        isVoiceModeActive = true
        Task {
            do {
                try await SpeechRecognizer.shared.startListening { transcript, isFinal in
                    if isFinal && !transcript.isEmpty {
                        onTranscriptCompleted(transcript)
                    }
                }
            } catch {
                isVoiceModeActive = false
                AppLogger.shared.error("Voice mode error: \(error.localizedDescription)", category: .voice)
            }
        }
    }
    
    public func stopVoiceMode() {
        isVoiceModeActive = false
        SpeechRecognizer.shared.stopListening()
        TextToSpeech.shared.stopSpeaking()
    }
}
