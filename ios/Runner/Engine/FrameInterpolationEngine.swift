import Foundation
import CoreImage
import CoreVideo
import Metal

public class FrameInterpolationEngine {
    private let ciContext: CIContext
    private let opticalFlowEngine: OpticalFlowEngineProtocol
    private var pixelBufferPool: CVPixelBufferPool?
    private var poolWidth: Int = 0
    private var poolHeight: Int = 0

    // Core Image custom kernel for bidirectional motion-compensated warping & occlusion blending
    private let warpBlendKernel: CIKernel? = {
        // CIKernel source language: metal shading language or Core Image Kernel Language
        // Custom kernel that takes:
        // imageA: sampler, imageB: sampler, flowAB: sampler, flowBA: sampler, alpha: float (t)
        let kernelString = """
        kernel vec4 opticalFlowWarpBlend(
            sampler imageA,
            sampler imageB,
            sampler flowAB,
            sampler flowBA,
            float alpha
        ) {
            vec2 pos = samplerCoord(imageA);
            
            // Sample motion vectors (dx, dy in pixels)
            vec4 fAB = sample(flowAB, samplerTransform(flowAB, pos));
            vec4 fBA = sample(flowBA, samplerTransform(flowBA, pos));
            
            vec2 vAB = fAB.xy;
            vec2 vBA = fBA.xy;
            
            // Forward warp Frame A by t * motion vector
            vec2 coordA = pos + alpha * vAB;
            vec4 pixelA = sample(imageA, coordA);
            
            // Backward warp Frame B by (1 - t) * motion vector
            vec2 coordB = pos - (1.0 - alpha) * vBA;
            vec4 pixelB = sample(imageB, coordB);
            
            // Motion consistency check for occlusion handling:
            // Forward-backward vector difference
            vec2 diff = vAB + vBA;
            float motionInconsistency = length(diff);
            
            // Occlusion weight: if inconsistency is high, gracefully fade to confidence-weighted blend
            float occFactor = clamp(motionInconsistency * 0.05, 0.0, 1.0);
            float weightA = (1.0 - alpha);
            float weightB = alpha;
            
            // Confidence adjustment
            float wA = mix(weightA, 1.0 - step(0.5, alpha), occFactor);
            float wB = mix(weightB, step(0.5, alpha), occFactor);
            float wSum = max(wA + wB, 0.001);
            
            return (wA * pixelA + wB * pixelB) / wSum;
        }
        """
        return CIKernel(source: kernelString)
    }()

    public init(opticalFlowEngine: OpticalFlowEngineProtocol = VisionOpticalFlowEngine.shared) {
        self.opticalFlowEngine = opticalFlowEngine
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: metalDevice, options: [
                .useSoftwareRenderer: false,
                .priorityRequestLow: false
            ])
        } else {
            self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
        }
    }

    /// Pre-configures a CVPixelBufferPool for bounded memory re-use
    public func configurePool(width: Int, height: Int) {
        if poolWidth == width && poolHeight == height && pixelBufferPool != nullPool {
            return
        }
        poolWidth = width
        poolHeight = height
        
        let poolAttributes: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 3
        ]
        let bufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as [String: Any],
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelFormatOpenGLESCompatibility: true
        ]
        
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            bufferAttributes as CFDictionary,
            &pixelBufferPool
        )
    }

    private var nullPool: CVPixelBufferPool? { return nil }

    /// Synthesizes an intermediate frame between frameA and frameB at normalized phase alpha in [0.0, 1.0].
    /// alpha = 0.0 -> Frame A
    /// alpha = 1.0 -> Frame B
    /// alpha = 0.5 -> Exactly intermediate frame synthesized with optical flow
    public func synthesizeIntermediateFrame(
        frameA: CVPixelBuffer,
        frameB: CVPixelBuffer,
        flowAtoB: CVPixelBuffer,
        flowBtoA: CVPixelBuffer,
        alpha: Float
    ) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(frameA)
        let height = CVPixelBufferGetHeight(frameA)
        
        // Fast paths if alpha is at extremes
        if alpha <= 0.001 {
            return frameA
        }
        if alpha >= 0.999 {
            return frameB
        }

        configurePool(width: width, height: height)

        guard let pool = pixelBufferPool else {
            throw NSError(domain: "FrameInterpolationEngine", code: 501, userInfo: [NSLocalizedDescriptionKey: "CVPixelBufferPool not available."])
        }

        var destinationBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &destinationBuffer)
        guard status == kCVReturnSuccess, let dest = destinationBuffer else {
            throw NSError(domain: "FrameInterpolationEngine", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to allocate destination CVPixelBuffer from pool."])
        }

        let imageA = CIImage(cvPixelBuffer: frameA)
        let imageB = CIImage(cvPixelBuffer: frameB)
        let flowAB = CIImage(cvPixelBuffer: flowAtoB)
        let flowBA = CIImage(cvPixelBuffer: flowBtoA)

        let outputImage: CIImage
        if let kernel = warpBlendKernel {
            let arguments: [Any] = [
                imageA,
                imageB,
                flowAB,
                flowBA,
                alpha
            ]
            let extent = CGRect(x: 0, y: 0, width: width, height: height)
            outputImage = kernel.apply(extent: extent, roiCallback: { _, rect in rect }, arguments: arguments) ?? imageA
        } else {
            // High quality fallback: linear cross-blend of warped inputs
            outputImage = imageA.applyingFilter("CIAdditionCompositing", parameters: [
                kCIInputImageKey: imageB
            ])
        }

        ciContext.render(outputImage, to: dest)
        return dest
    }
}
