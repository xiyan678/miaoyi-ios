import SwiftUI
import Speech
import AVFoundation
import Translation
import UIKit

@MainActor
final class TranslationStore: ObservableObject {
    @Published var sourceText = ""
    @Published var translatedText = ""
    @Published var isListening = false
    @Published var sourceLanguage: AppLanguage = .english
    @Published var targetLanguage: AppLanguage = .chinese
    @Published var history: [TranslationRecord] = []
    @Published var audioRouteName = "iPhone"
    @Published var errorMessage: String?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()

    init() {
        history = (try? JSONDecoder().decode([TranslationRecord].self, from: UserDefaults.standard.data(forKey: "translation-history") ?? Data())) ?? []
        configureAudioSession(); refreshRoute()
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do { try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]); try session.setActive(true) }
        catch { errorMessage = "无法设置音频设备：\(error.localizedDescription)" }
    }
    @objc private func routeChanged() { Task { @MainActor in refreshRoute() } }
    func refreshRoute() { audioRouteName = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "iPhone" }
    func requestPermissionsAndStart() async {
        let speechStatus = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        guard speechStatus == .authorized, micAllowed else { errorMessage = "请在设置中允许语音识别和麦克风访问。"; return }
        startListening()
    }
    func startListening() {
        guard !isListening else { return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: sourceLanguage.localeIdentifier)), recognizer.isAvailable else { errorMessage = "当前语言的语音识别暂不可用。"; return }
        configureAudioSession()
        recognitionTask?.cancel(); recognitionTask = nil
        let request = SFSpeechAudioBufferRecognitionRequest(); request.shouldReportPartialResults = true; recognitionRequest = request
        let input = audioEngine.inputNode; let format = input.outputFormat(forBus: 0); input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        audioEngine.prepare()
        do { try audioEngine.start(); isListening = true } catch { errorMessage = "无法启动麦克风：\(error.localizedDescription)"; return }
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in guard let self else { return }; if let result { self.sourceText = result.bestTranscription.formattedString }; if error != nil { self.stopListening() } }
        }
    }
    func stopListening() {
        guard isListening else { return }; audioEngine.stop(); audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio(); recognitionTask?.cancel(); recognitionRequest = nil; recognitionTask = nil; isListening = false
        if !sourceText.isEmpty && !translatedText.isEmpty { history.insert(TranslationRecord(source: sourceText, translation: translatedText, date: .now), at: 0); history = Array(history.prefix(50)); if let data = try? JSONEncoder().encode(history) { UserDefaults.standard.set(data, forKey: "translation-history") } }
    }
    func acceptTranslation(_ value: String) { translatedText = value }
    func translate(_ text: String) { guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { translatedText = ""; return }; if sourceLanguage == targetLanguage { translatedText = text } }
    func speakTranslation() { guard !translatedText.isEmpty else { return }; let utterance = AVSpeechUtterance(string: translatedText); utterance.voice = AVSpeechSynthesisVoice(language: targetLanguage.localeIdentifier); synthesizer.stopSpeaking(at: .immediate); synthesizer.speak(utterance) }
    func swapLanguages() { (sourceLanguage, targetLanguage) = (targetLanguage, sourceLanguage) }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "简体中文", english = "英语", japanese = "日语", korean = "韩语", french = "法语", german = "德语", spanish = "西班牙语"
    var id: String { rawValue }
    var localeIdentifier: String { switch self { case .chinese: "zh-CN"; case .english: "en-US"; case .japanese: "ja-JP"; case .korean: "ko-JP"; case .french: "fr-FR"; case .german: "de-DE"; case .spanish: "es-ES" } }
    var language: Locale.Language { Locale.Language(identifier: localeIdentifier) }
}
struct TranslationRecord: Codable, Identifiable { var id = UUID(); let source: String; let translation: String; let date: Date }


