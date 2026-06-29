import AVFoundation
import Speech
import UIKit

class VoiceManager: NSObject, ObservableObject, @unchecked Sendable {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcript = ""
    @Published var lastError: String?
    @Published var voiceSource = "None"
    
    private let synthesizer = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var ttsServerURL = "http://aibo.tail065eca.ts.net:5055"
    private var sttCompletion: (@Sendable (String) -> Void)?
    private static let assocKey: UInt8 = 0
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func configure(ttsURL: String) {
        ttsServerURL = ttsURL
    }
    
    // MARK: - STT using SFSpeechRecognizer (iOS native, no server needed)
    
    func requestPermission() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        if status != .authorized {
            lastError = "Speech recognition not authorized"
        }
        return status == .authorized
    }
    
    func startListening(completion: @escaping @Sendable (String) -> Void) {
        sttCompletion = completion
        guard !isListening else { return }
        
        // Request audio permission
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                DispatchQueue.main.async {
                    self.lastError = "Microphone access denied"
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isListening = true
                self.transcript = ""
                self.lastError = nil
                self.voiceSource = "iOS Speech"
            }
            
            do {
                try self.startSpeechRecognition()
            } catch {
                DispatchQueue.main.async {
                    self.lastError = "Failed to start: \(error.localizedDescription)"
                    self.isListening = false
                }
            }
        }
    }
    
    private func startSpeechRecognition() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = text
                }
                
                if result.isFinal {
                    Task { @MainActor in
                        self.sttCompletion?(text)
                        self.sttCompletion = nil
                        self.cleanup()
                    }
                }
            }
            
            if let error = error {
                // Only report errors that aren't just "stopped" 
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1 {
                    // "Stopped" is normal when user stops talking
                    return
                }
                DispatchQueue.main.async {
                    self.lastError = error.localizedDescription
                    self.isListening = false
                }
            }
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        // Finalize and get the current transcript
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        cleanup()
    }
    
    private func cleanup() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - TTS with CosyVoice3 priority
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        isSpeaking = true
        
        Task {
            if await tryCosyVoice(text) { return }
            speakWithIOS(text)
        }
    }
    
    private func tryCosyVoice(_ text: String) async -> Bool {
        let url = URL(string: "\(ttsServerURL)/tts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        let body: [String: Any] = ["text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return false }
            await MainActor.run {
                self.voiceSource = "CosyVoice 3.0"
                self.playAudioData(data)
            }
            return true
        } catch {
            print("CosyVoice unreachable: \(error.localizedDescription)")
            return false
        }
    }
    
    private func playAudioData(_ data: Data) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("cv3_\(UUID().uuidString).wav")
        do {
            try data.write(to: tempURL)
            let player = try AVAudioPlayer(contentsOf: tempURL)
            player.delegate = self
            player.play()
            withUnsafePointer(to: Self.assocKey) { ptr in
                objc_setAssociatedObject(self, ptr, player, .OBJC_ASSOCIATION_RETAIN)
            }
        } catch {
            print("Audio playback failed: \(error)")
            speakWithIOS(String(data: data, encoding: .utf8) ?? "...")
        }
    }
    
    private func speakWithIOS(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.1
        utterance.volume = 1.0
        voiceSource = "iOS TTS"
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func interrupt() {
        cleanup()
        stopSpeaking()
    }
}

extension VoiceManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}

extension VoiceManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        DispatchQueue.main.async { [self] in isSpeaking = false }
    }
}
