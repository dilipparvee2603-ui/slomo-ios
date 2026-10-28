import Foundation
import AVFoundation

public class VideoMetadataService {
    public static let shared = VideoMetadataService()

    private init() {}

    public func inspectVideo(at url: URL) async throws -> [String: Any] {
        let asset = AVURLAsset(url: url)
        
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw NSError(domain: "VideoMetadataService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No video track found in file."])
        }
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
        
        // Determine orientation
        var orientationDegrees = 0
        if preferredTransform.a == 0 && preferredTransform.b == 1.0 && preferredTransform.c == -1.0 && preferredTransform.d == 0 {
            orientationDegrees = 90
        } else if preferredTransform.a == 0 && preferredTransform.b == -1.0 && preferredTransform.c == 1.0 && preferredTransform.d == 0 {
            orientationDegrees = 270
        } else if preferredTransform.a == -1.0 && preferredTransform.b == 0 && preferredTransform.c == 0 && preferredTransform.d == -1.0 {
            orientationDegrees = 180
        }
        
        // Detect codec and HDR
        var codecName = "H.264"
        var isHDR = false
        var colorPrimaries = "BT.709"
        
        if let desc = formatDescriptions.first {
            let mediaSubType = CMFormatDescriptionGetMediaSubType(desc)
            switch mediaSubType {
            case kCMVideoCodecType_HEVC, kCMVideoCodecType_HEVCWithAlpha:
                codecName = "HEVC"
            case kCMVideoCodecType_H264:
                codecName = "H.264"
            case kCMVideoCodecType_AppleProRes422,
                 kCMVideoCodecType_AppleProRes422HQ,
                 kCMVideoCodecType_AppleProRes4444:
                codecName = "Apple ProRes"
            default:
                codecName = "MPEG-4"
            }
            
            if let extensions = CMFormatDescriptionGetExtensions(desc) as? [String: Any] {
                if let primaries = extensions[kCVImageBufferColorPrimariesKey as String] as? String {
                    colorPrimaries = primaries
                    if primaries == (kCVImageBufferColorPrimaries_ITU_R_2020 as String) {
                        isHDR = true
                    }
                }
                if let transfer = extensions[kCVImageBufferTransferFunctionKey as String] as? String {
                    if transfer == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String) ||
                       transfer == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String) {
                        isHDR = true
                    }
                }
            }
        }
        
        // Audio inspection
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let hasAudio = !audioTracks.isEmpty
        var audioChannels = 2
        var audioSampleRate = 48000
        
        if let audioTrack = audioTracks.first {
            let audioFormats = try await audioTrack.load(.formatDescriptions)
            if let audioDesc = audioFormats.first,
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioDesc)?.pointee {
                audioChannels = Int(asbd.mChannelsPerFrame)
                audioSampleRate = Int(asbd.mSampleRate)
            }
        }
        
        // File size
        var fileSizeBytes: Int64 = 0
        if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
           let size = resourceValues.fileSize {
            fileSizeBytes = Int64(size)
        }
        
        let totalFrames = Int(round(durationSeconds * Double(nominalFrameRate)))
        
        return [
            "path": url.path,
            "fileName": url.lastPathComponent,
            "width": Int(naturalSize.width),
            "height": Int(naturalSize.height),
            "fps": Double(nominalFrameRate),
            "durationSeconds": durationSeconds,
            "totalFrames": totalFrames,
            "codec": codecName,
            "hasAudio": hasAudio,
            "audioChannels": audioChannels,
            "audioSampleRate": audioSampleRate,
            "isHDR": isHDR,
            "colorPrimaries": colorPrimaries,
            "fileSizeBytes": fileSizeBytes,
            "orientationDegrees": orientationDegrees
        ]
    }
}
