import AVFoundation
import SwiftUI

// MARK: - AudioService

@MainActor
@Observable
class AudioService {
    private var audioPlayer: AVAudioPlayer?
    private var audioRecorder: AVAudioRecorder?
    private var synthesizer = AVSpeechSynthesizer()
    
    var isPlaying = false
    var isRecording = false
    var recordingURL: URL?
    var playbackProgress: Double = 0
    
    private var progressTask: Task<Void, Never>?
    
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
        speakAmharicFallback(text)
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
        progressTask?.cancel()
        progressTask = nil
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
        progressTask?.cancel()
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let player = self.audioPlayer else { return }

                if player.isPlaying {
                    self.playbackProgress = player.currentTime / player.duration
                } else {
                    self.isPlaying = false
                    return
                }
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
