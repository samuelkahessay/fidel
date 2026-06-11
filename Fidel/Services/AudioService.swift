import AVFoundation
import CryptoKit
import SwiftUI

// MARK: - ElevenLabs Configuration

struct ElevenLabsConfig {
    /// Debug-only. Release builds ship no client API key; bundled pronunciation
    /// audio is the production path and isConfigured gates live TTS.
    static var apiKey: String {
        #if DEBUG
        if let key = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !key.isEmpty {
            return key
        }
        #endif
        return ""
    }
    
    static let baseURL = "https://api.elevenlabs.io/v1"
    static let modelId = "eleven_multilingual_v2"
    static let defaultVoiceId = "21m00Tcm4TlvDq8ikWAM"
    
    static var isConfigured: Bool {
        !apiKey.isEmpty
    }
}

// MARK: - ElevenLabs API Models

struct ElevenLabsVoice: Codable, Identifiable {
    let voice_id: String
    let name: String
    let category: String?
    
    var id: String { voice_id }
}

struct ElevenLabsVoicesResponse: Codable {
    let voices: [ElevenLabsVoice]
}

// MARK: - Audio Cache

actor AudioCache {
    private var cache: [String: URL] = [:]
    private let cacheDirectory: URL

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("AudioCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func stableHash(for text: String) -> String {
        let data = Data(text.utf8)
        let digest = SHA256.hash(data: data)
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    func getCachedAudio(for text: String) -> URL? {
        let hash = stableHash(for: text)
        let filename = "\(hash).mp3"
        let fileURL = cacheDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }

    func cacheAudio(_ data: Data, for text: String) -> URL? {
        let hash = stableHash(for: text)
        let filename = "\(hash).mp3"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            cache[text] = fileURL
            return fileURL
        } catch {
            print("Failed to cache audio: \(error)")
            return nil
        }
    }
    
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        cache.removeAll()
    }
}

// MARK: - AudioService

@MainActor
@Observable
class AudioService {
    private var audioPlayer: AVAudioPlayer?
    private var audioRecorder: AVAudioRecorder?
    private var synthesizer = AVSpeechSynthesizer()
    private let audioCache = AudioCache()
    
    var isPlaying = false
    var isRecording = false
    var isLoading = false
    var recordingURL: URL?
    var playbackProgress: Double = 0
    var lastError: String?
    
    private var progressTimer: Timer?
    private var currentTask: Task<Void, Never>?
    
    init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
        #endif
    }
    
    // MARK: - ElevenLabs TTS
    
    func speakAmharicWithElevenLabs(_ text: String, voiceId: String? = nil) {
        currentTask?.cancel()
        stopPlayback()
        
        guard ElevenLabsConfig.isConfigured else {
            print("ElevenLabs API key not configured, falling back to system TTS")
            speakAmharicFallback(text)
            return
        }
        
        isLoading = true
        lastError = nil
        
        currentTask = Task {
            do {
                if let cachedURL = await audioCache.getCachedAudio(for: text) {
                    await MainActor.run {
                        self.isLoading = false
                        self.playAudio(from: cachedURL)
                    }
                    return
                }
                
                let audioData = try await fetchElevenLabsAudio(text: text, voiceId: voiceId)
                
                if let cachedURL = await audioCache.cacheAudio(audioData, for: text) {
                    await MainActor.run {
                        self.isLoading = false
                        self.playAudio(from: cachedURL)
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.playAudioData(audioData)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.lastError = error.localizedDescription
                    print("ElevenLabs TTS failed: \(error), falling back to system TTS")
                    self.speakAmharicFallback(text)
                }
            }
        }
    }
    
    private func fetchElevenLabsAudio(text: String, voiceId: String?) async throws -> Data {
        let voice = voiceId ?? ElevenLabsConfig.defaultVoiceId
        let urlString = "\(ElevenLabsConfig.baseURL)/text-to-speech/\(voice)?output_format=mp3_44100_128"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(ElevenLabsConfig.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "text": text,
            "model_id": ElevenLabsConfig.modelId,
            "voice_settings": [
                "stability": 0.75,
                "similarity_boost": 0.75,
                "style": 0.0,
                "use_speaker_boost": true
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ElevenLabs", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])
        }
        
        return data
    }
    
    func fetchAvailableVoices() async throws -> [ElevenLabsVoice] {
        guard ElevenLabsConfig.isConfigured else {
            throw NSError(domain: "ElevenLabs", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }
        
        let urlString = "\(ElevenLabsConfig.baseURL)/voices"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue(ElevenLabsConfig.apiKey, forHTTPHeaderField: "xi-api-key")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ElevenLabsVoicesResponse.self, from: data)
        
        return response.voices
    }
    
    private func playAudioData(_ data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            startProgressTimer()
        } catch {
            print("Audio playback from data failed: \(error)")
            isPlaying = false
        }
    }
    
    // MARK: - System TTS Fallback
    
    private func speakAmharicFallback(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        
        if let voice = AVSpeechSynthesisVoice(language: "am-ET") {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: "ar-SA") {
            utterance.voice = voice
            utterance.rate = 0.4
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.3
        }
        
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isPlaying = true
        synthesizer.speak(utterance)
        
        Task {
            try? await Task.sleep(for: .seconds(Double(text.count) * 0.15))
            self.isPlaying = false
        }
    }

    func speakAmharic(_ text: String, transliteration: String? = nil) {
        if ElevenLabsConfig.isConfigured {
            speakAmharicWithElevenLabs(text)
        } else {
            speakAmharicFallback(text)
        }
    }
    
    func speakEnglish(_ text: String) {
        stopPlayback()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isPlaying = true
        synthesizer.speak(utterance)
        
        Task {
            try? await Task.sleep(for: .seconds(Double(text.count) * 0.08))
            self.isPlaying = false
        }
    }
    
    func stopPlayback() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        isPlaying = false
        progressTimer?.invalidate()
    }
    
    func playAudio(from url: URL) {
        stopPlayback()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            startProgressTimer()
        } catch {
            print("Audio playback failed: \(error)")
        }
    }
    
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            
            if player.isPlaying {
                self.playbackProgress = player.currentTime / player.duration
            } else {
                self.isPlaying = false
                self.progressTimer?.invalidate()
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        stopPlayback()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date.now.timeIntervalSince1970).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            recordingURL = audioFilename
            isRecording = true
        } catch {
            print("Recording failed: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return recordingURL
    }
    
    func playRecording() {
        guard let url = recordingURL else { return }
        playAudio(from: url)
    }
    
    func getRecordingDuration() -> TimeInterval? {
        guard let url = recordingURL else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            return nil
        }
    }
}

// MARK: - UI Components

struct SpeakButton: View {
    let text: String
    let isAmharic: Bool
    var audioService: AudioService

    var body: some View {
        Button(action: {
            if isAmharic {
                audioService.speakAmharic(text)
            } else {
                audioService.speakEnglish(text)
            }
        }) {
            ZStack {
                if audioService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: audioService.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .foregroundColor(audioService.isPlaying ? AppTheme.primaryColor : .secondary)
                        .font(.title3)
                }
            }
        }
        .disabled(audioService.isPlaying || audioService.isLoading)
    }
}

struct RecordButton: View {
    @Binding var isRecording: Bool
    let onRecordingComplete: (URL?) -> Void
    var audioService: AudioService

    var body: some View {
        Button(action: {
            if audioService.isRecording {
                let url = audioService.stopRecording()
                isRecording = false
                onRecordingComplete(url)
            } else {
                audioService.startRecording()
                isRecording = true
            }
        }) {
            ZStack {
                Circle()
                    .fill(audioService.isRecording ? Color.red : AppTheme.primaryColor)
                    .frame(width: 64, height: 64)
                
                if audioService.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.onAccentColor)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(AppTheme.onAccentColor)
                        .frame(width: 24, height: 24)
                }
            }
        }
    }
}
