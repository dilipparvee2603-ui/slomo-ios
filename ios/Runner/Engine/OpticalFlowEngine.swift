import Foundation
import CoreVideo
import Vision

public protocol OpticalFlowEngineProtocol {
    func computeFlow(
        from sourceBuffer: CVPixelBuffer,
        to targetBuffer: CVPixelBuffer
    ) throws -> CVPixelBuffer
}

/// Real Optical Flow Engine powered by Apple Vision Framework (VNGenerateOpticalFlowRequest).
/// Computes 2-channel 32-bit floating point motion displacement vectors (dx, dy) per pixel.
public class VisionOpticalFlowEngine: OpticalFlowEngineProtocol {
    public static let shared = VisionOpticalFlowEngine()

    public init() {}

    /// Computes pixel-level motion vector field from sourceBuffer to targetBuffer
    public func computeFlow(
        from sourceBuffer: CVPixelBuffer,
        to targetBuffer: CVPixelBuffer
    ) throws -> CVPixelBuffer {
        let request = VNGenerateOpticalFlowRequest(targetedCVPixelBuffer: targetBuffer, options: [:])
        request.computationAccuracy = .high
        request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float

        let handler = VNImageRequestHandler(cvPixelBuffer: sourceBuffer, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first as? VNPixelBufferObservation else {
            throw NSError(
                domain: "VisionOpticalFlowEngine",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to obtain optical flow pixel buffer observation."]
            )
        }

        return observation.pixelBuffer
    }

    /// Check if hardware supports Vision optical flow
    public static var isSupported: Bool {
        if #available(iOS 14.0, *) {
            return true
        }
        return false
    }

    /// Dynamically check if VideoToolbox VTFrameProcessor is supported
    public static var isVTFrameProcessorSupported: Bool {
        return NSClassFromString("VTFrameProcessor") != nil
    }
}
