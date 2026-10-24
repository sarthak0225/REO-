import Foundation
import AVFoundation

@MainActor
public final class TextToSpeech: NSObject, ObservableObject, SpeechOutputProvider, AVSpeechSynthesizerDelegate {
    public static let shared = TextToSpeech()
    
    @Published public private(set) var isSpeaking: Bool = false
    
    private let synthesizer = AVSpeechSynthesizer()
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    public func speak(text: String) {
        guard SettingsManager.shared.enableSpokenResponses else { return }
        
        let cleaned = cleanTextForSpeech(text)
        guard !cleaned.isEmpty else { return }
        
        stopSpeaking()
        
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = SettingsManager.shared.speechRate
        
        let voiceIdentifier = SettingsManager.shared.selectedVoiceIdentifier
        if !voiceIdentifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        isSpeaking = true
        synthesizer.speak(utterance)
        AppLogger.shared.info("Spoken response initiated: \(cleaned.prefix(40))...", category: .voice)
    }
    
    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    private func cleanTextForSpeech(_ text: String) -> String {
        // Strip markdown links, bold/italics, and backtick code blocks for pleasant audio
        var cleaned = text.replacingOccurrences(of: "```[\\s\\S]*?```", with: "Code snippet omitted.", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^\\)]+\\)", with: "$1", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "[*#_~]", with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
