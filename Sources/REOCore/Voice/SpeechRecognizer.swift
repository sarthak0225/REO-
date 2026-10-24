import Foundation
import Speech
import AVFoundation

public enum SpeechInputError: LocalizedError, Sendable {
    case micPermissionDenied
    case speechPermissionDenied
    case audioEngineFailed(String)
    case recognizerUnavailable
    case privacyModeActive
    
    public var errorDescription: String? {
        switch self {
        case .micPermissionDenied:
            return "Microphone permission is required. Please grant access in System Settings."
        case .speechPermissionDenied:
            return "Speech recognition permission is required. Please grant access in System Settings."
        case .audioEngineFailed(let msg):
            return "Audio engine failure: \(msg)"
        case .recognizerUnavailable:
            return "Speech recognizer is currently unavailable."
        case .privacyModeActive:
            return "Voice capture is disabled while Privacy Mode is active."
        }
    }
}

@MainActor
public final class SpeechRecognizer: ObservableObject, SpeechInputProvider {
    public static let shared = SpeechRecognizer()
    
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var currentTranscript: String = ""
    @Published public private(set) var audioLevel: Float = 0.0
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var activeRecognizer: SFSpeechRecognizer? {
        if let rec = SFSpeechRecognizer(locale: Locale.current), rec.isAvailable {
            return rec
        }
        if let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), rec.isAvailable {
            return rec
        }
        return SFSpeechRecognizer()
    }
    
    private init() {}
    
    public func startListening(onTranscript: @escaping @Sendable (String, Bool) -> Void) async throws {
        if SettingsManager.shared.privacyMode {
            throw SpeechInputError.privacyModeActive
        }
        
        let micGranted = await PermissionManager.shared.requestMicrophone()
        guard micGranted else {
            throw SpeechInputError.micPermissionDenied
        }
        
        let speechGranted = await PermissionManager.shared.requestSpeechRecognition()
        guard speechGranted else {
            throw SpeechInputError.speechPermissionDenied
        }
        
        guard let recognizer = activeRecognizer, recognizer.isAvailable else {
            throw SpeechInputError.recognizerUnavailable
        }
        
        // Cancel existing task if any
        stopListening()
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request
        
        let inputNode = engine.inputNode
        let bus = 0
        let recordingFormat = inputNode.outputFormat(forBus: bus)
        let formatToUse = (recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0) ? recordingFormat : nil
        
        inputNode.removeTap(onBus: bus)
        inputNode.installTap(onBus: bus, bufferSize: 1024, format: formatToUse) { [weak self] buffer, _ in
            request.append(buffer)
            
            // Calculate approximate audio level for visual indicator
            if let channelData = buffer.floatChannelData?[0] {
                let frames = buffer.frameLength
                var sum: Float = 0
                for i in 0..<Int(frames) {
                    sum += abs(channelData[i])
                }
                let avg = sum / Float(max(1, frames))
                Task { @MainActor [weak self] in
                    self?.audioLevel = min(1.0, avg * 5.0)
                }
            }
        }
        
        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: bus)
            self.audioEngine = nil
            self.recognitionRequest = nil
            self.isListening = false
            throw SpeechInputError.audioEngineFailed(error.localizedDescription)
        }
        
        self.isListening = true
        self.currentTranscript = ""
        AppLogger.shared.info("Speech recognition listening started", category: .voice)
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                
                Task { @MainActor in
                    self.currentTranscript = transcript
                    onTranscript(transcript, isFinal)
                    
                    if isFinal {
                        self.stopListening()
                    }
                }
            }
            
            if error != nil {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }
    }
    
    public func stopListening() {
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
        audioLevel = 0.0
        AppLogger.shared.info("Speech recognition listening stopped", category: .voice)
    }
    
    public func cancelListening() {
        stopListening()
        currentTranscript = ""
    }
}
