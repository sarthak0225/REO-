import Foundation

@MainActor
public protocol SpeechInputProvider: AnyObject, Sendable {
    var isListening: Bool { get }
    func startListening(onTranscript: @escaping @Sendable (String, Bool) -> Void) async throws
    func stopListening()
    func cancelListening()
}

@MainActor
public protocol SpeechOutputProvider: AnyObject, Sendable {
    var isSpeaking: Bool { get }
    func speak(text: String)
    func stopSpeaking()
}
