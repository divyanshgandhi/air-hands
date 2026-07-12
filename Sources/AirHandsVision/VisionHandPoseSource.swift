#if canImport(Vision) && canImport(AVFoundation)
import AVFoundation
import AirHandsCore
import Foundation
import Vision

/// Camera → Apple Vision hand pose → normalized fingertips (macOS 13+ / iOS 16+).
///
/// Coordinates match the AirHands convention: origin top-left, x mirrored so
/// the user's rightward motion moves right on screen (selfie view).
public final class VisionHandPoseSource: NSObject, HandFrameSource {
    public var onFrame: (([RawFingertip], Double) -> Void)?
    public var onHands: (([RawHand], Double) -> Void)?

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
    private static let jointMap: [(VNHumanHandPoseObservation.JointName, HandJoint)] = [
        (.wrist, .wrist),
        (.thumbCMC, .thumbCMC), (.thumbMP, .thumbMP), (.thumbIP, .thumbIP), (.thumbTip, .thumbTip),
        (.indexMCP, .indexMCP), (.indexPIP, .indexPIP), (.indexDIP, .indexDIP), (.indexTip, .indexTip),
        (.middleMCP, .middleMCP), (.middlePIP, .middlePIP), (.middleDIP, .middleDIP), (.middleTip, .middleTip),
        (.ringMCP, .ringMCP), (.ringPIP, .ringPIP), (.ringDIP, .ringDIP), (.ringTip, .ringTip),
        (.littleMCP, .littleMCP), (.littlePIP, .littlePIP), (.littleDIP, .littleDIP), (.littleTip, .littleTip),
    ]

    private static let fingertipMap: [(VNHumanHandPoseObservation.JointName, FingerID)] = [
        (.thumbTip, .thumb),
        (.indexTip, .index),
        (.middleTip, .middle),
        (.ringTip, .ring),
        (.littleTip, .pinky),
    ]

    private static func normalized(
        _ point: VNRecognizedPoint,
        mirror: Bool
    ) -> Point {
        // Vision uses a bottom-left origin; AirHands uses top-left.
        Point(x: mirror ? 1 - point.location.x : point.location.x, y: 1 - point.location.y)
    }

    private func normalizedPoint(
        _ joint: VNHumanHandPoseObservation.JointName,
        in points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]
    ) -> Point? {
        guard let point = points[joint], point.confidence >= minConfidence else { return nil }
        return Self.normalized(point, mirror: mirror)
    }

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
        var hands: [RawHand] = []
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
            var joints: [HandJoint: Point] = [:]
            for (joint, mapped) in Self.jointMap {
                guard let point = points[joint], point.confidence >= minConfidence else { continue }
                joints[mapped] = Self.normalized(point, mirror: mirror)
            }

            var handTips: [RawFingertip] = []
            for (joint, finger) in Self.fingertipMap {
                guard let point = points[joint], point.confidence >= minConfidence else { continue }
                let normalized = Self.normalized(point, mirror: mirror)
                let tip = RawFingertip(x: normalized.x, y: normalized.y, hand: hand, finger: finger)
                handTips.append(tip)
                tips.append(tip)
            }

            let wrist = normalizedPoint(.wrist, in: points)
            let middleMCP = normalizedPoint(.middleMCP, in: points)
            let palmCenter = middleMCP ?? wrist
            let handScale: Double?
            if let wrist, let middleMCP {
                handScale = hypot(wrist.x - middleMCP.x, wrist.y - middleMCP.y)
            } else {
                handScale = nil
            }
            hands.append(
                RawHand(
                    hand: hand,
                    joints: joints,
                    fingertips: handTips,
                    palmCenter: palmCenter,
                    handScale: handScale
                ))
        }

        let tsMs = ProcessInfo.processInfo.systemUptime * 1000
        onFrame?(tips, tsMs)
        onHands?(hands, tsMs)
    }
}
#endif
