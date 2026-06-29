import AVFoundation
import UIKit

class VoiceManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcript = ""
    @Published var lastError: String?
    @Published var voiceSource = "None"
    
    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine = AVAudioEngine()
    private var recognitionTask: (any Cancellable)?
    private var audioPlayer: AVAudioPlayer?
    private static let assocKey: UInt8 = 0
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - STT (Speech-to-Text) using OpenAI Whisper API
    
    func startListening() {
        guard !isListening else { return }
        isListening = true
        transcript = ""
        lastError = nil
        voiceSource = "Whisper"
        
        // Request permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async { [self] in
                    self.lastError = "Microphone access denied"
                    self.isListening = false
                }
                return
            }
            self.startRecording()
        }
    }
    
    private func startRecording() {
        // Use device recording and send to STT API
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
            // Buffer audio data for processing
        }
        
        do {
            try audioEngine.start()
        } catch {
            DispatchQueue.main.async { [self] in
                self.lastError = "Failed to start audio engine: \(error.localizedDescription)"
                self.isListening = false
            }
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        isListening = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    // MARK: - TTS (Text-to-Speech) with CosyVoice priority
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        isSpeaking = true
        
        Task {
            // Try CosyVoice server first
            if await tryCosyVoice(text) { return }
            // Fall back to iOS TTS
            speakWithIOS(text)
        }
    }
    
    private func tryCosyVoice(_ text: String) async -> Bool {
        // Try local CosyVoice server
        let url = URL(string: "http://localhost:5055/tts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "text": text + "<|endofprompt|>",
            "voice": "inanis_00000.wav"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            await MainActor.run {
                self.voiceSource = "CosyVoice (Ina)"
                self.playAudioData(data)
            }
            return true
        } catch {
            print("CosyVoice server unreachable: \(error.localizedDescription)")
            return false
        }
    }
    
    private func playAudioData(_ data: Data) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("cosyvoice_\(UUID().uuidString).wav")
        do {
            try data.write(to: tempURL)
            let player = try AVAudioPlayer(contentsOf: tempURL)
            player.delegate = self
            player.play()
            objc_setAssociatedObject(self, &Self.assocKey, player, .OBJC_ASSOCIATION_RETAIN)
        } catch {
            print("Audio playback failed: \(error)")
            speakWithIOS(String(data: data, encoding: .utf8) ?? "...")
        }
    }
    
    private func speakWithIOS(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.1
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func interrupt() {
        stopListening()
        stopSpeaking()
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceManager {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [self] in
            isSpeaking = false
        }
    }
}

// MARK: - Cancellable protocol

protocol Cancellable {
    func cancel()
}
