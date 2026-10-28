import Foundation
import Flutter
import UIKit
import Photos
import AVFoundation

public class PlatformBridgeHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "com.slomocreator.pro/engine", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "com.slomocreator.pro/progress", binaryMessenger: registrar.messenger())
        
        let instance = PlatformBridgeHandler()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "inspectVideo":
            guard let args = call.arguments as? [String: Any],
                  let path = args["videoPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Video path missing", details: nil))
                return
            }
            let url = URL(fileURLWithPath: path)
            Task {
                do {
                    let metadata = try await VideoMetadataService.shared.inspectVideo(at: url)
                    DispatchQueue.main.async {
                        result(metadata)
                    }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INSPECT_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "checkCapabilities":
            result([
                "visionOpticalFlowSupported": VisionOpticalFlowEngine.isSupported,
                "vtFrameProcessorSupported": VisionOpticalFlowEngine.isVTFrameProcessorSupported,
                "metalSupported": MTLCreateSystemDefaultDevice() != nil,
                "maxOutputFps": 120
            ])

        case "cancelRender":
            VideoExportService.shared.cancel()
            result(nil)

        case "saveToPhotos":
            guard let args = call.arguments as? [String: Any],
                  let path = args["videoPath"] as? String else {
                result(false)
                return
            }
            let url = URL(fileURLWithPath: path)
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized || status == .limited else {
                    DispatchQueue.main.async { result(false) }
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { success, error in
                    DispatchQueue.main.async {
                        result(success)
                    }
                }
            }

        case "shareVideo":
            guard let args = call.arguments as? [String: Any],
                  let path = args["videoPath"] as? String else {
                result(nil)
                return
            }
            let url = URL(fileURLWithPath: path)
            DispatchQueue.main.async {
                guard let rootVC = UIApplication.shared.windows.first?.rootViewController else {
                    result(nil)
                    return
                }
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                rootVC.present(activityVC, animated: true)
                result(nil)
            }

        case "startRender":
            guard let args = call.arguments as? [String: Any],
                  let sourcePath = args["sourceVideoPath"] as? String,
                  let speedPercent = args["speedPercent"] as? Double,
                  let exportConfig = args["exportConfig"] as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid render parameters", details: nil))
                return
            }

            let sourceURL = URL(fileURLWithPath: sourcePath)
            let fps = exportConfig["fps"] as? Int ?? 60
            let bitrate = exportConfig["bitrate"] as? Int ?? 15_000_000
            let containerStr = exportConfig["container"] as? String ?? "mp4"
            let codecStr = exportConfig["codec"] as? String ?? "hevc"
            let audioModeStr = exportConfig["audioMode"] as? String ?? "retimedPitchPreserved"
            let keyframes = args["keyframes"] as? [[String: Any]] ?? []

            let fileExt = (containerStr == "mov") ? "mov" : "mp4"
            let fileType: AVFileType = (containerStr == "mov") ? .mov : .mp4
            let codec: AVVideoCodecType = (codecStr == "h264") ? .h264 : .hevc
            let audioMode = AudioProcessingMode(rawValue: audioModeStr) ?? .retimedPitchPreserved

            let outputFileName = "SloMo_\(Int(speedPercent))pct_\(fps)fps_\(Int(Date().timeIntervalSince1970)).\(fileExt)"
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documentsDir.appendingPathComponent(outputFileName)

            let targetWidth = args["sourceWidth"] as? Int ?? 1920
            let targetHeight = args["sourceHeight"] as? Int ?? 1080

            let params = ExportParameters(
                sourceVideoURL: sourceURL,
                outputURL: outputURL,
                speedPercent: speedPercent,
                outputFps: fps,
                codec: codec,
                fileType: fileType,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                bitrate: bitrate,
                audioMode: audioMode,
                keyframes: keyframes
            )

            Task {
                do {
                    try await VideoExportService.shared.exportSlowMotion(parameters: params) { status, progress, currentFrame, totalFrames, fpsProc, elapsed, eta, message in
                        DispatchQueue.main.async {
                            self.eventSink?([
                                "status": status,
                                "progress": progress,
                                "currentFrame": currentFrame,
                                "totalFrames": totalFrames,
                                "fpsProcessing": fpsProc,
                                "elapsedSeconds": elapsed,
                                "etaSeconds": eta,
                                "statusMessage": message,
                                "outputPath": outputURL.path
                            ])
                        }
                    }
                    DispatchQueue.main.async {
                        result(outputURL.path)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.eventSink?([
                            "status": "error",
                            "errorMessage": error.localizedDescription
                        ])
                        result(FlutterError(code: "RENDER_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
