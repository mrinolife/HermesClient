import Foundation
import Speech
import AVFoundation

/// Manages the voice loop: speech-to-text → WebView injection → text-to-speech.
/// TTS uses CosyVoice server (Ina's voice) when available, falls back to iOS TTS.
@MainActor
class VoiceManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcript = ""
    @Published var voiceSource: String = "CosyVoice" // "CosyVoice" or "iOS TTS"
    
    /// Base URL for the CosyVoice TTS server
    var ttsServerURL: String {
        UserDefaults.standard.string(forKey: "tts_server_url")
            ?? "https://aibo.tail065eca.ts.net:5055"
    }
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var onTranscript: ((String) -> Void)?
    private let session = URLSession.shared
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - STT (Speech-to-Text)
    
    func requestPermission() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        return status == .authorized
    }
    
    func startListening(onTranscript: @escaping (String) -> Void) {
        self.onTranscript = onTranscript
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            guard granted else {
                print("Mic permission denied")
                return
            }
            DispatchQueue.main.async { [self] in
                startAudioEngine()
            }
        }
    }
    
    private func startAudioEngine() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            print("Audio engine start failed: \(error)")
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                self.transcript = text
                
                if result.isFinal {
                    self.onTranscript?(text)
                }
            }
            
            if error != nil {
                self.stopListening()
            }
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }
    
    // MARK: - TTS (Text-to-Speech) — tries CosyVoice server first
    
    func speak(_ text: String) {
        // Stop any current speech
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = true
        
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isSpeaking = false
            return
        }
        
        // Try CosyVoice server first
        Task {
            let ok = await tryCosyVoice(text)
            if !ok {
                // Fall back to iOS TTS
                await MainActor.run {
                    self.voiceSource = "iOS TTS"
                    self.speakWithIOS(text)
                }
            }
        }
    }
    
    /// Try CosyVoice3 server — returns true if speech was played
    private func tryCosyVoice(_ text: String) async -> Bool {
        guard let url = URL(string: "\(ttsServerURL)/tts") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["text": text])
        request.timeoutInterval = 15
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            // Success — play the audio data
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
    
    /// Play raw WAV audio data
    private func playAudioData(_ data: Data) {
        // Save to temp file and play via AVAudioPlayer
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("cosyvoice_\(UUID().uuidString).wav")
        do {
            try data.write(to: tempURL)
            let player = try AVAudioPlayer(contentsOf: tempURL)
            player.delegate = self
            player.play()
            // Store reference so it doesn't deallocate
            objc_setAssociatedObject(self, &assocKey, player, .OBJC_ASSOCIATION_RETAIN)
        } catch {
            print("Audio playback failed: \(error)")
            // Fall back to iOS TTS
            speakWithIOS(String(data: data, encoding: .utf8) ?? "...")
        }
    }
    
    /// iOS native TTS fallback
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

private var assocKey: UInt8 = 0

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

extension VoiceManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isSpeaking = false
        }
    }
}
