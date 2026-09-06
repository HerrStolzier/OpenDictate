import Foundation

public enum OpenDictateError: LocalizedError {
    case audioPreprocessingFailed(String)
    case apiError(String)
    case hotKeyRegistrationFailed(OSStatus)
    case invalidResponse
    case keychainStatus(OSStatus)
    case missingAPIKey
    case noActiveRecording
    case noAudioFile
    case noSpeechDetected(peakDb: Float)
    case recordingCouldNotStart
    case recordingTooShort(actual: TimeInterval, minimum: TimeInterval)

    public var isSkippedRecording: Bool {
        switch self {
        case .noSpeechDetected, .recordingTooShort:
            return true
        default:
            return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .audioPreprocessingFailed(let message):
            return "Could not prepare the recording for transcription.\n\n\(message)"
        case .apiError(let message):
            return message
        case .hotKeyRegistrationFailed(let status):
            return "RegisterEventHotKey failed with status \(status)."
        case .invalidResponse:
            return "The transcription service returned an invalid response."
        case .keychainStatus(let status):
            return "Keychain operation failed with status \(status)."
        case .missingAPIKey:
            return "The OpenAI API key is not set."
        case .noActiveRecording:
            return "There is no active recording to stop."
        case .noAudioFile:
            return "The recording finished, but no audio file was written."
        case .noSpeechDetected(let peakDb):
            return "No speech was detected (peak \(peakDb.formattedDb)), so nothing was sent to OpenAI."
        case .recordingCouldNotStart:
            return "AVAudioRecorder could not start recording."
        case .recordingTooShort(let actual, let minimum):
            return "Recording skipped: \(actual.formattedSeconds) is too short. Speak for at least \(minimum.formattedSeconds)."
        }
    }
}
