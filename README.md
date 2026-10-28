# Slo-Mo Creator Pro — iOS

**Slo-Mo Creator Pro** is a high-performance slow-motion video workstation for iPhone (iOS 15+, optimized for iPhone 17 and ProMotion 120Hz displays) inspired by Adobe Premiere Pro's percentage-based Speed/Duration controls and powered by **genuine optical-flow frame interpolation**.

Instead of simple frame duplication or basic crossfades, the app uses Apple's **Vision Framework** (`VNGenerateOpticalFlowRequest`) and **Metal GPU compute** to synthesize authentic motion-compensated intermediate video frames.

---

## ⚡ Features

### 1. Premiere Pro-Style Speed/Duration Controls
- **Percentage Speed Slider & Numeric Input**: Enter any speed from `1%` to `100%` (including decimal values like `12.5%` or `33.33%`).
  - `100%` = Normal speed ($1.0\times$)
  - `75%` = $1.33\times$ slower
  - `50%` = $2.0\times$ slower
  - `40%` = $2.5\times$ slower
  - `25%` = $4.0\times$ slower
  - `20%` = $5.0\times$ slower
  - `10%` = $10.0\times$ slower
  - `5%` = $20.0\times$ slower
  - `1%` = $100.0\times$ slower
- **Two-Way Duration Calculator**:
  $$\text{Output Duration} = \text{Source Duration} \times \frac{100}{\text{Speed Percentage}}$$
  Entering a target duration immediately recalculates the exact required speed percentage.
- **Variable-Speed Timeline & Speed Ramps**:
  - Add multiple speed keyframes along the clip.
  - Smooth cubic Bezier ease-in / ease-out curves and linear transitions.
  - Freeze-frame capability (hold frame at given timestamp).

### 2. Real Optical-Flow Frame Interpolation Pipeline
- **Decoding**: Streamed frame extraction via `AVAssetReader` using a bounded 2-frame window to keep RAM footprint low even on 4K clips.
- **Motion Estimation**: Apple Vision `VNGenerateOpticalFlowRequest` computes dense 2-channel 32-bit floating-point displacement vector fields $(dx, dy)$ for forward ($A \to B$) and backward ($B \to A$) motion.
- **Bidirectional Warping**:
  - Forward warps Frame $A$ by $t \cdot (dx_{AB}, dy_{AB})$
  - Backward warps Frame $B$ by $-(1 - t) \cdot (dx_{BA}, dy_{BA})$
- **Occlusion Handling**: Evaluates forward-backward motion vector consistency $|(dx_{AB} + dx_{BA})| + |(dy_{AB} + dy_{BA})|$. Occluded boundaries are weighted with confidence to suppress edge tearing and artifacts.
- **Metal / Core Image GPU Blending**: Renders final synthesized intermediate frame directly to destination pixel buffer on the iPhone GPU.

### 3. Output Frame Rates & Frame Math
- **Selectable Output Rates**: `30 FPS`, `60 FPS`, and `120 FPS` (ProMotion).
- **Intermediate Frame Allocation**:
  $$\text{Frames Per Interval} = \frac{\text{Output FPS}}{\text{Source FPS}} \times \frac{100}{\text{Speed Percentage}}$$
  *Example*: A 30 FPS source clip rendered at 25% speed with a 120 FPS target produces **16 synthesized output frames** for every original source frame interval.

### 4. Audio Processing & Synchronization
- **Pitch-Preserved Retiming**: Utilizes `AVAudioTimePitchAlgorithmTimeDomain` to time-stretch audio without pitch distortion ("chipmunk effect").
- **Mute Mode**: Optional audio mute recommended for extreme slo-mo ($< 20\%$).
- **Zero-Drift Synchronization**: Strict presentation timestamp alignment between retimed audio and video tracks.

### 5. Export & Sharing
- **Containers**: MP4 and QuickTime MOV.
- **Codecs**: Hardware-accelerated HEVC (H.265) and H.264 (AVC).
- **Resolutions**: Source, 4K UHD ($3840\times2160$), 1080p FHD, 720p HD.
- **Save to Photos**: Directly exports into the iOS Camera Roll (`PHPhotoLibrary`).
- **iOS Share Sheet**: Share exported videos via AirDrop, Messages, Files, or Cloud storage.

---

## 🏗️ Architecture

```
slomo_creator_pro/
├── lib/
│   ├── core/
│   │   ├── constants/app_colors.dart          # Dark cinematic UI palette
│   │   ├── math/
│   │   │   ├── speed_mapping_engine.dart      # Speed % formulas, durations & LUT
│   │   │   └── bezier_curve.dart              # Newton-Raphson Bezier evaluator
│   │   └── models/
│   │       ├── video_metadata.dart            # Resolution, FPS, Codec, HDR, Audio
│   │       ├── speed_keyframe.dart            # Variable speed ramp keyframes
│   │       ├── export_config.dart             # Formats, FPS, Bitrate calculation
│   │       └── render_progress.dart           # Live progress, FPS, ETA
│   ├── services/
│   │   ├── video_import_service.dart          # Photos & Files import
│   │   └── platform_bridge_service.dart       # MethodChannel & EventChannel
│   └── ui/
│       ├── screens/
│       │   ├── home_screen.dart               # Import hub & hardware specs
│       │   ├── editor_screen.dart             # Video player & speed controls
│       │   ├── speed_curve_editor.dart        # Speed ramp curve editor
│       │   ├── export_sheet.dart              # Container, Codec, FPS selector
│       │   └── render_progress_dialog.dialog  # Real-time progress & save sheet
│       └── widgets/
│           ├── speed_preset_chips.dart        # 100%, 75%, 50%, 25%, 10%, 5% chips
│           ├── duration_calculator_card.dart  # Interactive 2-way calculator
│           ├── video_metadata_card.dart       # Badges for 4K, FPS, HDR, Codec
│           └── timeline_ruler.dart            # Playhead & timecode ruler
└── ios/Runner/Engine/
    ├── VideoMetadataService.swift             # Native AVAsset inspection
    ├── OpticalFlowEngine.swift                # Apple Vision VNGenerateOpticalFlowRequest
    ├── FrameInterpolationEngine.swift         # Metal/CI bidirectional warp & blend
    ├── AudioRetimingService.swift             # Pitch-preserved AVAudio retiming
    ├── VideoExportService.swift               # AVAssetReader & AVAssetWriter bounded pipeline
    └── PlatformBridgeHandler.swift            # MethodChannel bridge
```

---

## 🧪 Testing

Automated unit tests cover all math engines, speed percentage conversions, duration integration, Bezier timing, and intermediate frame planning:

```powershell
flutter test
```

Test suite output:
```
00:00 +0: SpeedMappingEngine - Constant Speed Percentage & Durations Premiere Pro speed percentage to duration calculation
00:00 +1: SpeedMappingEngine - Constant Speed Percentage & Durations Reverse calculation: Target Duration to Speed Percentage
00:00 +2: SpeedMappingEngine - Constant Speed Percentage & Durations Slowdown and Playback multipliers
00:00 +3: SpeedMappingEngine - Constant Speed Percentage & Durations Intermediate frame ratio matches prompt specification (16x frames at 120 FPS / 25% speed)
00:00 +4: SpeedMappingEngine - Constant Speed Percentage & Durations Total output frames calculation
00:00 +5: CubicBezierCurve & Speed Ramps CubicBezier endpoints and monotonicity
00:00 +6: CubicBezierCurve & Speed Ramps Variable speed ramp output duration integration
00:00 +7: CubicBezierCurve & Speed Ramps Frame sample planning accurately brackets source frames and computes alpha
00:03 +8: App smoke test launches Home Screen
00:03 +9: All tests passed!
```

---

## 📲 Building & Sideloading (SideStore / Sideloadly)

See [`SIDELOAD_GUIDE.md`](./SIDELOAD_GUIDE.md) for full instructions on installing `SloMoCreatorPro.ipa` using a **free Apple ID** via **SideStore** or **Sideloadly**.

### Automated GitHub Actions Build
Pushing to `main` triggers `.github/workflows/build-ios.yml`:
1. Compiles Flutter & Swift release bundle with latest Xcode on macOS runner.
2. Ad-hoc signs all embedded frameworks.
3. Packages `SloMoCreatorPro.ipa`.
4. Publishes downloadable IPA under **GitHub Actions Artifacts** and **Releases**.
