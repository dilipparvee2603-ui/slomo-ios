import Foundation
import AVFoundation
import CoreVideo
import CoreMedia

public struct ExportParameters {
    public let sourceVideoURL: URL
    public let outputURL: URL
    public let speedPercent: Double
    public let outputFps: Int
    public let codec: AVVideoCodecType
    public let fileType: AVFileType
    public let targetWidth: Int
    public let targetHeight: Int
    public let bitrate: Int
    public let audioMode: AudioProcessingMode
    public let keyframes: [[String: Any]]
}

public class VideoExportService {
    public static let shared = VideoExportService()

    private let opticalFlowEngine = VisionOpticalFlowEngine.shared
    private let interpolationEngine = FrameInterpolationEngine()
    private var isCancelled: Bool = false

    private init() {}

    public func cancel() {
        isCancelled = true
    }

    public func exportSlowMotion(
        parameters: ExportParameters,
        progressHandler: @escaping (
            _ status: String,
            _ progress: Double,
            _ currentFrame: Int,
            _ totalFrames: Int,
            _ fpsProcessing: Double,
            _ elapsedSeconds: Double,
            _ etaSeconds: Double,
            _ statusMessage: String
        ) -> Void
    ) async throws {
        isCancelled = false
        let startTime = Date()

        let asset = AVURLAsset(url: parameters.sourceVideoURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = videoTracks.first else {
            throw NSError(domain: "VideoExportService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No video track found."])
        }

        let sourceDuration = try await asset.load(.duration)
        let sourceDurationSeconds = CMTimeGetSeconds(sourceDuration)
        let sourceFps = try await sourceVideoTrack.load(.nominalFrameRate)
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)

        // Calculate output duration and total frames
        let slowdownMultiplier = 100.0 / parameters.speedPercent.clamped(to: 1.0...100.0)
        let outputDurationSeconds = sourceDurationSeconds * slowdownMultiplier
        let totalOutputFrames = Int(round(outputDurationSeconds * Double(parameters.outputFps)))

        let outputWidth = parameters.targetWidth > 0 ? parameters.targetWidth : Int(naturalSize.width)
        let outputHeight = parameters.targetHeight > 0 ? parameters.targetHeight : Int(naturalSize.height)

        // Clean up any existing destination file
        if FileManager.default.fileExists(atPath: parameters.outputURL.path) {
            try? FileManager.default.removeItem(at: parameters.outputURL)
        }

        // Setup AVAssetReader
        let reader = try AVAssetReader(asset: asset)
        let readerOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outputWidth,
            kCVPixelBufferHeightKey as String: outputHeight,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: sourceVideoTrack, outputSettings: readerOutputSettings)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        // Setup AVAssetWriter
        let writer = try AVAssetWriter(outputURL: parameters.outputURL, fileType: parameters.fileType)
        let videoCompressionSettings: [String: Any] = [
            AVVideoAverageBitRateKey: parameters.bitrate,
            AVVideoProfileLevelKey: (parameters.codec == .hevc) ? AVVideoProfileLevelHEVCMainAutoLevel : AVVideoProfileLevelH264HighAutoLevel,
            AVVideoExpectedSourceFrameRateKey: parameters.outputFps
        ]
        let writerOutputSettings: [String: Any] = [
            AVVideoCodecKey: parameters.codec,
            AVVideoWidthKey: outputWidth,
            AVVideoHeightKey: outputHeight,
            AVVideoCompressionPropertiesKey: videoCompressionSettings
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerOutputSettings)
        writerInput.expectsMediaDataInRealTime = false

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outputWidth,
            kCVPixelBufferHeightKey as String: outputHeight,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        writer.add(writerInput)

        guard reader.startReading() else {
            throw reader.error ?? NSError(domain: "VideoExportService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to start AVAssetReader."])
        }

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Pre-allocate buffer pool
        interpolationEngine.configurePool(width: outputWidth, height: outputHeight)

        // Bounded frame reading pipeline
        var currentSourceFrame: CVPixelBuffer?
        var nextSourceFrame: CVPixelBuffer?
        var currentSourcePTS: Double = 0.0
        var nextSourcePTS: Double = 0.0

        // Read initial Frame A
        guard let sampleBuffer1 = readerOutput.copyNextSampleBuffer(),
              let pixelBuffer1 = CMSampleBufferGetImageBuffer(sampleBuffer1) else {
            throw NSError(domain: "VideoExportService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Cannot read first frame."])
        }
        currentSourceFrame = pixelBuffer1
        currentSourcePTS = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer1))

        // Read initial Frame B
        guard let sampleBuffer2 = readerOutput.copyNextSampleBuffer(),
              let pixelBuffer2 = CMSampleBufferGetImageBuffer(sampleBuffer2) else {
            // Video with only 1 frame
            throw NSError(domain: "VideoExportService", code: 503, userInfo: [NSLocalizedDescriptionKey: "Video has insufficient frames."])
        }
        nextSourceFrame = pixelBuffer2
        nextSourcePTS = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer2))

        // Initial Optical Flow computation between Frame A and Frame B
        var forwardFlow = try opticalFlowEngine.computeFlow(from: currentSourceFrame!, to: nextSourceFrame!)
        var backwardFlow = try opticalFlowEngine.computeFlow(from: nextSourceFrame!, to: currentSourceFrame!)

        var outputFrameIdx = 0
        let targetFrameDurationSeconds = 1.0 / Double(parameters.outputFps)

        while outputFrameIdx < totalOutputFrames {
            if isCancelled {
                reader.cancelReading()
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: parameters.outputURL)
                throw NSError(domain: "VideoExportService", code: -999, userInfo: [NSLocalizedDescriptionKey: "Render was cancelled by user."])
            }

            let outputTimestamp = Double(outputFrameIdx) * targetFrameDurationSeconds
            // Linear constant speed source mapping:
            let mappedSourceTimestamp = outputTimestamp * (parameters.speedPercent / 100.0)

            // Advance the source window if mapped timestamp has exceeded nextSourcePTS
            while mappedSourceTimestamp > nextSourcePTS && reader.status == .reading {
                if let nextSample = readerOutput.copyNextSampleBuffer(),
                   let nextBuf = CMSampleBufferGetImageBuffer(nextSample) {
                    currentSourceFrame = nextSourceFrame
                    currentSourcePTS = nextSourcePTS

                    nextSourceFrame = nextBuf
                    nextSourcePTS = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(nextSample))

                    // Recompute optical flow for new consecutive interval
                    forwardFlow = try opticalFlowEngine.computeFlow(from: currentSourceFrame!, to: nextSourceFrame!)
                    backwardFlow = try opticalFlowEngine.computeFlow(from: nextSourceFrame!, to: currentSourceFrame!)
                } else {
                    break
                }
            }

            // Calculate intermediate phase alpha in [0.0, 1.0]
            let timeSpan = max(nextSourcePTS - currentSourcePTS, 1.0 / Double(sourceFps))
            let alpha = Float(((mappedSourceTimestamp - currentSourcePTS) / timeSpan).clamped(to: 0.0...1.0))

            // Synthesize intermediate frame using genuine optical flow motion vectors
            try autoreleasepool {
                guard let fA = currentSourceFrame, let fB = nextSourceFrame else { return }
                
                let renderedPixelBuffer = try interpolationEngine.synthesizeIntermediateFrame(
                    frameA: fA,
                    frameB: fB,
                    flowAtoB: forwardFlow,
                    flowBtoA: backwardFlow,
                    alpha: alpha
                )

                // Wait until writer is ready
                while !writerInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.002)
                }

                let presentationTime = CMTime(
                    value: CMTimeValue(outputFrameIdx),
                    timescale: CMTimeScale(parameters.outputFps)
                )
                adaptor.append(renderedPixelBuffer, withPresentationTime: presentationTime)
            }

            outputFrameIdx += 1

            // Report progress every 5 frames
            if outputFrameIdx % 5 == 0 || outputFrameIdx == totalOutputFrames {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = Double(outputFrameIdx) / Double(max(totalOutputFrames, 1))
                let currentProcessingFps = Double(outputFrameIdx) / max(elapsed, 0.001)
                let remainingFrames = totalOutputFrames - outputFrameIdx
                let eta = Double(remainingFrames) / max(currentProcessingFps, 0.001)

                progressHandler(
                    "synthesizingFrames",
                    progress,
                    outputFrameIdx,
                    totalOutputFrames,
                    currentProcessingFps,
                    elapsed,
                    eta,
                    "Synthesizing optical-flow frame \(outputFrameIdx)/\(totalOutputFrames)"
                )
            }
        }

        // Finalize video track
        writerInput.markAsFinished()
        await writer.finishWriting()

        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "VideoExportService", code: 504, userInfo: [NSLocalizedDescriptionKey: "Video writer failed."])
        }

        // Handle Audio track muxing and retiming
        if parameters.audioMode != .mute {
            progressHandler("retimingAudio", 0.98, totalOutputFrames, totalOutputFrames, 0, Date().timeIntervalSince(startTime), 0, "Retiming audio track with pitch preservation...")
            try await muxRetimedAudio(
                sourceVideoURL: parameters.sourceVideoURL,
                renderedVideoURL: parameters.outputURL,
                outputDuration: CMTime(seconds: outputDurationSeconds, preferredTimescale: 600),
                mode: parameters.audioMode
            )
        }

        let totalElapsed = Date().timeIntervalSince(startTime)
        progressHandler("completed", 1.0, totalOutputFrames, totalOutputFrames, Double(totalOutputFrames) / max(totalElapsed, 0.001), totalElapsed, 0, "Render completed successfully!")
    }

    /// Muxes pitch-preserved retimed audio with rendered optical-flow video
    private func muxRetimedAudio(
        sourceVideoURL: URL,
        renderedVideoURL: URL,
        outputDuration: CMTime,
        mode: AudioProcessingMode
    ) async throws {
        let tempMuxURL = renderedVideoURL.deletingLastPathComponent().appendingPathComponent("temp_muxed_\(UUID().uuidString).\(renderedVideoURL.pathExtension)")
        
        let sourceAsset = AVURLAsset(url: sourceVideoURL)
        let renderedAsset = AVURLAsset(url: renderedVideoURL)
        
        let composition = AVMutableComposition()
        
        // Video track from rendered asset
        guard let renderedVideoTrack = try await renderedAsset.loadTracks(withMediaType: .video).first,
              let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return
        }
        
        let renderedDuration = try await renderedAsset.load(.duration)
        try compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: renderedDuration), of: renderedVideoTrack, at: .zero)
        
        // Retimed Audio track from source asset
        let audioMix = try await AudioRetimingService.shared.createRetimedAudioTrack(
            sourceAsset: sourceAsset,
            composition: composition,
            targetDuration: renderedDuration,
            mode: mode
        )
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            return
        }
        
        exportSession.outputURL = tempMuxURL
        exportSession.outputFileType = (renderedVideoURL.pathExtension.lowercased() == "mov") ? .mov : .mp4
        exportSession.audioMix = audioMix
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            _ = try? FileManager.default.removeItem(at: renderedVideoURL)
            try FileManager.default.moveItem(at: tempMuxURL, to: renderedVideoURL)
        } else {
            try? FileManager.default.removeItem(at: tempMuxURL)
        }
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
