import Foundation

/// Pure geometry helper. It does not import MediaPipe or depend on the UI.
enum JointAngleCalculator {
    /// Returns the interior angle at `vertex` in degrees (0...180), or nil if
    /// the geometry is degenerate or contains invalid coordinates.
    static func angleDegrees(
        first: PoseLandmark,
        vertex: PoseLandmark,
        third: PoseLandmark
    ) -> Double? {
        guard first.hasFiniteCoordinates,
              vertex.hasFiniteCoordinates,
              third.hasFiniteCoordinates else {
            return nil
        }

        let ax = first.x - vertex.x
        let ay = first.y - vertex.y
        let bx = third.x - vertex.x
        let by = third.y - vertex.y

        let magnitudeA = hypot(ax, ay)
        let magnitudeB = hypot(bx, by)
        guard magnitudeA > 1e-9, magnitudeB > 1e-9 else {
            return nil
        }

        let dot = (ax * bx) + (ay * by)
        let cosine = min(1.0, max(-1.0, dot / (magnitudeA * magnitudeB)))
        let degrees = acos(cosine) * 180.0 / .pi
        return degrees.isFinite ? degrees : nil
    }
}
