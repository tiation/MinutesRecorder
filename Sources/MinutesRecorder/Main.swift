import Foundation
import AVFoundation
import Speech
import SwiftUI
import NaturalLanguage

@main
struct MinutesRecorderApp: App {
    @StateObject private var audioManager = AudioRecordingManager()
    @StateObject private var transcriptionManager = TranscriptionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioManager)
                .environmentObject(transcriptionManager)
        }
    }
}

class AudioRecordingManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration = "00:00"
    @Published var audioLevel: Float = 0.0
    @Published var actualRecordingDuration: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession?
    private var timer: Timer?
    private var startTime: Date?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession?.setCategory(.playAndRecord, mode: .default)
            try audioSession?.setActive(true)
            
            audioSession?.requestRecordPermission { [weak self] allowed in
                if !allowed {
                    print("Microphone permission denied")
                }
            }
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileName = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFileName, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true
            startTime = Date()
            startTimer()
            NotificationCenter.default.post(name: .recordingStarted, object: audioFileName)
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        if let startTime = startTime {
            actualRecordingDuration = Date().timeIntervalSince(startTime)
        }
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
        recordingDuration = "00:00"
        
        if let url = audioRecorder?.url {
            NotificationCenter.default.post(name: .recordingStopped, object: url, userInfo: ["duration": actualRecordingDuration])
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            self.recordingDuration = String(format: "%02d:%02d", minutes, seconds)
            
            self.audioRecorder?.updateMeters()
            self.audioLevel = self.audioRecorder?.averagePower(forChannel: 0) ?? 0
        }
    }
}

extension AudioRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}

extension Notification.Name {
    static let recordingStarted = Notification.Name("recordingStarted")
    static let recordingStopped = Notification.Name("recordingStopped")
}

class TranscriptionManager: NSObject, ObservableObject {
    @Published var currentTranscription = ""
    @Published var isProcessing = false
    @Published var savedMinutes: [MeetingMinutes] = []
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        requestSpeechAuthorization()
        setupNotifications()
        loadSavedMinutes()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleRecordingStarted(_:)), name: .recordingStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRecordingStopped(_:)), name: .recordingStopped, object: nil)
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    print("Speech recognition denied")
                case .restricted:
                    print("Speech recognition restricted")
                case .notDetermined:
                    print("Speech recognition not determined")
                @unknown default:
                    print("Speech recognition unknown status")
                }
            }
        }
    }
    
    @objc private func handleRecordingStarted(_ notification: Notification) {
        startLiveTranscription()
    }
    
    @objc private func handleRecordingStopped(_ notification: Notification) {
        guard let audioURL = notification.object as? URL else { return }
        let duration = notification.userInfo?["duration"] as? TimeInterval ?? 0
        stopLiveTranscription()
        processRecording(at: audioURL, duration: duration)
    }
    
    private func startLiveTranscription() {
        isProcessing = true
        currentTranscription = ""
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine couldn't start: \(error)")
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.currentTranscription = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || result?.isFinal == true {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
    }
    
    private func stopLiveTranscription() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    private var recordingDuration: TimeInterval = 0
    
    private func processRecording(at url: URL, duration: TimeInterval) {
        self.recordingDuration = duration
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { 
            print("Speech recognizer not available")
            // Generate minutes with empty transcription for testing
            DispatchQueue.main.async {
                self.generateMinutes(from: "Test recording - speech recognition not available")
                self.isProcessing = false
            }
            return 
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.currentTranscription = result.bestTranscription.formattedString
                    self.generateMinutes(from: result.bestTranscription.formattedString)
                    self.isProcessing = false
                }
            } else if let error = error {
                print("Recognition error: \(error)")
                DispatchQueue.main.async {
                    // Generate minutes with error message for testing
                    self.generateMinutes(from: "Recording completed but transcription failed: \(error.localizedDescription)")
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func generateMinutes(from transcription: String) {
        let minutes = MeetingMinutes(
            id: UUID(),
            title: generateTitle(from: transcription),
            date: Date(),
            duration: calculateDuration(),
            transcription: transcription,
            summary: generateSummary(from: transcription),
            actionItems: extractActionItems(from: transcription),
            keyTopics: extractKeyTopics(from: transcription)
        )
        
        savedMinutes.insert(minutes, at: 0)
        saveMinutesToDisk()
    }
    
    private func generateTitle(from transcription: String) -> String {
        if transcription.isEmpty {
            return "Untitled Recording - \(Date().formatted(date: .abbreviated, time: .shortened))"
        }
        let words = transcription.split(separator: " ").prefix(10)
        if words.isEmpty {
            return "Recording - \(Date().formatted(date: .abbreviated, time: .shortened))"
        }
        return words.joined(separator: " ") + "..."
    }
    
    private func generateSummary(from transcription: String) -> String {
        if transcription.isEmpty {
            return "No transcription available"
        }
        let summary = String(transcription.prefix(100))
        return summary.isEmpty ? "No content" : summary + "..."
    }
    
    private func extractActionItems(from transcription: String) -> [String] {
        var actionItems: [String] = []
        let actionPhrases = ["need to", "will", "should", "must", "have to", "going to"]
        
        let sentences = transcription.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        for sentence in sentences {
            let lowercased = sentence.lowercased()
            for phrase in actionPhrases {
                if lowercased.contains(phrase) {
                    actionItems.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
                    break
                }
            }
        }
        
        return actionItems
    }
    
    private func extractKeyTopics(from transcription: String) -> [String] {
        var topics: [String] = []
        
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = transcription
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        let tags: [NLTag] = [.personalName, .placeName, .organizationName]
        
        tagger.enumerateTags(in: transcription.startIndex..<transcription.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag, tags.contains(tag) {
                let name = String(transcription[tokenRange])
                if !topics.contains(name) {
                    topics.append(name)
                }
            }
            return true
        }
        
        return topics
    }
    
    private func calculateDuration() -> Int {
        return Int(recordingDuration / 60) // Convert seconds to minutes
    }
    
    private func saveMinutesToDisk() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(savedMinutes) {
            UserDefaults.standard.set(encoded, forKey: "SavedMinutes")
        }
    }
    
    private func loadSavedMinutes() {
        if let data = UserDefaults.standard.data(forKey: "SavedMinutes"),
           let decoded = try? JSONDecoder().decode([MeetingMinutes].self, from: data) {
            savedMinutes = decoded
        }
    }
}

struct MeetingMinutes: Identifiable, Codable {
    let id: UUID
    let title: String
    let date: Date
    let duration: Int
    let transcription: String
    let summary: String
    let actionItems: [String]
    let keyTopics: [String]
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension MeetingMinutes {
    func exportAsMarkdown() -> String {
        var markdown = """
        # \(title)
        
        **Date:** \(formattedDate)
        **Duration:** \(duration) minutes
        
        ## Summary
        \(summary)
        
        ## Key Topics
        """
        
        for topic in keyTopics {
            markdown += "\n- \(topic)"
        }
        
        markdown += "\n\n## Action Items"
        for (index, item) in actionItems.enumerated() {
            markdown += "\n\(index + 1). \(item)"
        }
        
        markdown += "\n\n## Full Transcription\n\(transcription)"
        
        return markdown
    }
    
    func exportAsJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(self)
    }
}

struct ContentView: View {
    @EnvironmentObject var audioManager: AudioRecordingManager
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    @State private var showingMinutesDetail = false
    @State private var selectedMinutes: MeetingMinutes?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                RecordingStatusView()
                RecordingButton().padding(.vertical, 30)
                if !transcriptionManager.currentTranscription.isEmpty {
                    TranscriptionPreviewView().frame(maxHeight: 200)
                }
                RecentMinutesList()
            }
            .padding()
            .navigationTitle("Minutes Recorder")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {/* Settings action */}) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}

struct RecordingStatusView: View {
    @EnvironmentObject var audioManager: AudioRecordingManager
    
    var body: some View {
        HStack {
            Circle()
                .fill(audioManager.isRecording ? Color.red : Color.gray)
                .frame(width: 12, height: 12)
            Text(audioManager.isRecording ? "Recording..." : "Ready to Record")
                .font(.headline)
            Spacer()
            if audioManager.isRecording {
                Text(audioManager.recordingDuration)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct RecordingButton: View {
    @EnvironmentObject var audioManager: AudioRecordingManager
    
    var body: some View {
        Button(action: {
            if audioManager.isRecording {
                audioManager.stopRecording()
            } else {
                audioManager.startRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(audioManager.isRecording ? Color.red : Color.blue)
                    .frame(width: 120, height: 120)
                Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(audioManager.isRecording ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: audioManager.isRecording)
    }
}

struct TranscriptionPreviewView: View {
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Live Transcription")
                    .font(.headline)
                Spacer()
                if transcriptionManager.isProcessing {
                    ProgressView().scaleEffect(0.8)
                }
            }
            ScrollView {
                Text(transcriptionManager.currentTranscription)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
    }
}

struct RecentMinutesList: View {
    @EnvironmentObject var transcriptionManager: TranscriptionManager
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Minutes")
                .font(.headline)
                .padding(.horizontal)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(transcriptionManager.savedMinutes) { minutes in
                        MinutesRowView(minutes: minutes)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MinutesRowView: View {
    let minutes: MeetingMinutes
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(minutes.title)
                    .font(.headline)
                Spacer()
                Text(minutes.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(minutes.summary)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.secondary)
            HStack {
                Label("\(minutes.duration)m", systemImage: "clock")
                    .font(.caption)
                Spacer()
                Label("\(minutes.actionItems.count) actions", systemImage: "checkmark.circle")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AudioRecordingManager())
            .environmentObject(TranscriptionManager())
    }
}

