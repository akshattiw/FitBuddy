import Vision
import CoreMedia
import ImageIO
import Foundation

// MARK: - Native On-Device Pose Detector (Apple Vision Pipeline)
/// High-performance, zero-latency on-device human body pose detection utilizing Apple Vision.
/// Runs asynchronously on a dedicated serial queue with frame-dropping to prevent buffer backlog.
/// Converts recognized body joints into app-owned `PoseLandmark` and `PoseFrame` models.
final class PoseDetector: @unchecked Sendable {
    private let processingQueue = DispatchQueue(label: "com.fitbuddy.pose.processing", qos: .userInteractive)
    private var isProcessingFrame = false
    
    init() {}
    
    /// Processes a single camera sample buffer. Drops frames if inference is currently active.
    func process(
        sampleBuffer: CMSampleBuffer,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (PoseFrame?) -> Void
    ) {
        guard !isProcessingFrame else {
            // Drop frame to preserve real-time throughput and avoid backlog
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            completion(nil)
            return
        }
        
        isProcessingFrame = true
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampMs = Int64(time.seconds * 1000.0)
        
        processingQueue.async { [weak self] in
            defer { self?.isProcessingFrame = false }
            
            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            
            do {
                try handler.perform([request])
                guard let observation = request.results?.first else {
                    completion(nil)
                    return
                }
                
                let landmarks = self?.extractLandmarks(from: observation) ?? []
                let frame = PoseFrame(timestampMilliseconds: timestampMs, landmarks: landmarks)
                completion(frame)
            } catch {
                completion(nil)
            }
        }
    }
    
    private func extractLandmarks(from observation: VNHumanBodyPoseObservation) -> [PoseLandmark] {
        var landmarks: [PoseLandmark] = []
        
        let jointMapping: [(VNHumanBodyPoseObservation.JointName, PoseLandmarkID)] = [
            (.nose, .nose),
            (.leftShoulder, .leftShoulder),
            (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow),
            (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist),
            (.rightWrist, .rightWrist),
            (.leftHip, .leftHip),
            (.rightHip, .rightHip),
            (.leftKnee, .leftKnee),
            (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle),
            (.rightAnkle, .rightAnkle)
        ]
        
        for (jointName, landmarkId) in jointMapping {
            if let recognizedPoint = try? observation.recognizedPoint(jointName),
               recognizedPoint.confidence > 0.05 {
                // Vision normalized coordinates have origin at bottom-left (0,0).
                // Standard image coordinates expect top-left (0,0), so invert y.
                let x = min(1.0, max(0.0, Double(recognizedPoint.location.x)))
                let y = min(1.0, max(0.0, Double(1.0 - recognizedPoint.location.y)))
                let confidence = min(1.0, max(0.0, Double(recognizedPoint.confidence)))
                
                landmarks.append(PoseLandmark(
                    id: landmarkId,
                    x: x,
                    y: y,
                    z: 0.0,
                    confidence: confidence
                ))
            }
        }
        
        return landmarks
    }
}
