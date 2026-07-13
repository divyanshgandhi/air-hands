import Foundation

struct CameraCalibration: Codable, Equatable {
    var minX = 0.15
    var maxX = 0.85
    var minY = 0.15
    var maxY = 0.85
    var sensitivity = 1.0
}

struct CalibrationStore {
    private let defaults = UserDefaults.standard

    func calibration(for cameraID: String) -> CameraCalibration {
        guard let data = defaults.data(forKey: "airhands.calibration.\(cameraID)"),
              let value = try? JSONDecoder().decode(CameraCalibration.self, from: data) else { return CameraCalibration() }
        return value
    }

    func save(_ calibration: CameraCalibration, for cameraID: String) {
        defaults.set(try? JSONEncoder().encode(calibration), forKey: "airhands.calibration.\(cameraID)")
    }
}
