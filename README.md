# Minutes Recorder iOS App

![Minutes Recorder](https://via.placeholder.com/1200x600/4A90E2/FFFFFF?text=Minutes+Recorder)

An enterprise-grade iOS application that combines the power of OpenAI's Whisper-like speech recognition with intelligent meeting minutes generation, similar to Fireflies.ai. Record meetings, conversations, and lectures with automatic transcription and smart minute generation.

## 📱 Features

- **Real-time Audio Recording**: High-quality audio recording with live waveform visualization
- **Live Transcription**: Real-time speech-to-text conversion using Apple's Speech Recognition framework
- **Smart Minutes Generation**: Automatically generates structured meeting minutes with:
  - Meeting summary
  - Key topics extraction
  - Action items identification
  - Full searchable transcription
- **Export Options**: Export minutes as Markdown or JSON
- **Offline Support**: On-device speech recognition for privacy and offline functionality
- **Enterprise Security**: All data stored locally with optional cloud sync

## 🛠 Technology Stack

- **Language**: Swift 5.7+
- **UI Framework**: SwiftUI
- **Speech Recognition**: Apple Speech Framework
- **Audio**: AVFoundation
- **Natural Language Processing**: Natural Language framework
- **Minimum iOS Version**: iOS 16.0

## 📋 Requirements

- Xcode 14.0 or later
- iOS 16.0 or later
- iPhone or iPad with microphone support

## 🚀 Getting Started

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/MinutesRecorder.git
   cd MinutesRecorder
   ```

2. Open the project in Xcode:
   ```bash
   open MinutesRecorder.xcodeproj
   ```

3. Build and run the project on your device or simulator

### Permissions

The app requires the following permissions:
- **Microphone Access**: For recording audio
- **Speech Recognition**: For transcribing audio to text

These permissions will be requested when first launching the app.

## 📖 Usage

### Recording a Meeting

1. Tap the large microphone button to start recording
2. The app will show live transcription as you speak
3. Tap the stop button when finished
4. The app automatically generates minutes with summary and action items

### Viewing Minutes

- Recent minutes appear in the list below the recording button
- Tap any minute to view full details
- Swipe to delete or share minutes

### Exporting Minutes

Minutes can be exported in two formats:
- **Markdown**: Perfect for documentation and wikis
- **JSON**: For integration with other systems

## 🏗 Architecture

```
MinutesRecorder/
├── MinutesRecorder.xcodeproj/     # Xcode project file
├── Sources/
│   └── MinutesRecorder/
│       └── Main.swift             # All app code in one file
├── Info.plist                     # App configuration
├── Package.swift                  # Swift Package Manager config
└── README.md                      # This file
```

## 🔧 Configuration

### Customization Options

- **Language Support**: Change the speech recognizer locale in `TranscriptionManager` class
- **Audio Quality**: Adjust recording settings in `AudioRecordingManager` class
- **Export Formats**: Add custom export formats in `MeetingMinutes` extension

## 🔒 Privacy & Security

- All recordings and transcriptions are processed on-device
- No data is sent to external servers without explicit user consent
- Audio files are stored in the app's secure documents directory
- Supports Face ID/Touch ID for app access (optional)

## 📊 Performance

- Optimized for real-time transcription with minimal latency
- Efficient memory management for long recordings
- Background audio recording support

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Documentation](https://github.com/yourusername/MinutesRecorder/wiki)
- [Issues](https://github.com/yourusername/MinutesRecorder/issues)
- [Project Website](https://minutesrecorder.example.com)

## 📞 Support

For support, email support@minutesrecorder.com or open an issue in the GitHub repository.

---

Made with ❤️ by Your Company Name
