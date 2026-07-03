#if canImport(Vision) && canImport(AVFoundation)
import AVFoundation
import AirHandsCore
import Foundation
import Vision

/// Camera → Apple Vision hand pose → normalized fingertips (macOS 13+ / iOS 16+).
///
/// Coordinates match the AirHands convention: origin top-left, x mirrored so
/// the user's rightward motion moves right on screen (selfie view).
public final class VisionHandPoseSource: NSObject, HandPoseSource {
    public var onFrame: (([RawFingertip], Double) -> Void)?

    /// Minimum Vision confidence for a fingertip to be reported.
    public var minConfidence: Float = 0.3
    /// Mirror horizontally (true for user-facing cameras).
    public var mirror = true

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "airhands.vision.capture")
    private let request: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()
    private var configured = false

    public enum SourceError: Error {
        case noCamera
        case cannotAddInput
        case cannotAddOutput
    }

    public func start() throws {
        if !configured {
            try configure()
            configured = true
        }
        queue.async { [session] in
            session.startRunning()
        }
    }

    public func stop() {
        queue.async { [session] in
            session.stopRunning()
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .vga640x480

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw SourceError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw SourceError.cannotAddInput }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw SourceError.cannotAddOutput }
        session.addOutput(output)
    }
}

extension VisionHandPoseSource: AVCaptureVideoDataOutputSampleBufferDelegate {
    private static let jointMap: [(VNHumanHandPoseObservation.JointName, FingerID)] = [
        (.thumbTip, .thumb),
        (.indexTip, .index),
        (.middleTip, .middle),
        (.ringTip, .ring),
        (.littleTip, .pinky),
    ]

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return // skip the frame; the capture loop continues
        }

        var tips: [RawFingertip] = []
        for observation in request.results ?? [] {
            // Vision reports chirality as seen by the camera; mirroring for the
            // user swaps it (same convention as the MediaPipe web adapter).
            let hand: Hand
            switch observation.chirality {
            case .left: hand = mirror ? .right : .left
            case .right: hand = mirror ? .left : .right
            case .unknown: hand = .right
            @unknown default: hand = .right
            }

            guard let points = try? observation.recognizedPoints(.all) else { continue }
            for (joint, finger) in Self.jointMap {
                guard let point = points[joint], point.confidence >= minConfidence else { continue }
                // Vision uses a bottom-left origin; AirHands uses top-left.
                let x = mirror ? 1 - point.location.x : point.location.x
                let y = 1 - point.location.y
                tips.append(RawFingertip(x: x, y: y, hand: hand, finger: finger))
            }
        }

        let tsMs = ProcessInfo.processInfo.systemUptime * 1000
        onFrame?(tips, tsMs)
    }
}
#endif
