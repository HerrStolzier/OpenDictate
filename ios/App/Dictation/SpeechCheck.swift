import AVFoundation
import Foundation
import OpenDictateCore

/// Whether a recording holds anything louder than room noise, with the Mac's
/// rule: some 50 ms window above -45 dBFS. Services tend to invent a word for
/// silence ("you", "Vielen Dank."), so a silent recording is not sent.
enum SpeechCheck {
    static let thresholdDb: Float = -45

    /// True when the file cannot be read: the service then decides.
    static func heardSpeech(at url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url) else { return true }
        let format = file.processingFormat
        let window = AVAudioFrameCount(max(1, Int(format.sampleRate * 0.05)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: window) else { return true }
        let channels = max(1, Int(format.channelCount))
        while file.framePosition < file.length {
            guard (try? file.read(into: buffer, frameCount: window)) != nil else { return true }
            let frames = Int(buffer.frameLength)
            guard frames > 0, let data = buffer.floatChannelData else { break }
            var sumSquares: Float = 0
            for channel in 0..<channels {
                for frame in 0..<frames {
                    let sample = data[channel][frame]
                    sumSquares += sample * sample
                }
            }
            if AudioLevels.decibels(sumSquares: sumSquares, count: frames * channels) >= thresholdDb { return true }
        }
        return false
    }
}
