import Foundation
import AVFoundation

public enum AudioProcessingMode: String {
    case retimedPitchPreserved = "retimedPitchPreserved"
    case mute = "mute"
    case originalSpeed = "originalSpeed"
}

public class AudioRetimingService {
    public static let shared = AudioRetimingService()

    private init() {}

    /// Retimes source audio to match slow motion video duration without pitch shift
    public func createRetimedAudioTrack(
        sourceAsset: AVURLAsset,
        composition: AVMutableComposition,
        targetDuration: CMTime,
        mode: AudioProcessingMode
    ) async throws -> AVMutableAudioMix? {
        if mode == .mute {
            return nil
        }

        let audioTracks = try await sourceAsset.loadTracks(withMediaType: .audio)
        guard let sourceAudioTrack = audioTracks.first else {
            return nil
        }

        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            return nil
        }

        let sourceDuration = try await sourceAsset.load(.duration)
        let sourceTimeRange = CMTimeRange(start: .zero, duration: sourceDuration)

        try compositionAudioTrack.insertTimeRange(sourceTimeRange, of: sourceAudioTrack, at: .zero)

        if mode == .retimedPitchPreserved {
            // Scale audio track duration to exactly match target video duration
            compositionAudioTrack.scaleTimeRange(
                CMTimeRange(start: .zero, duration: sourceDuration),
                toDuration: targetDuration
            )

            // Setup pitch-preserving audio mix parameters
            let audioMix = AVMutableAudioMix()
            let trackParams = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
            trackParams.audioTimePitchAlgorithm = .timeDomain
            audioMix.inputParameters = [trackParams]
            return audioMix
        }

        return nil
    }
}
