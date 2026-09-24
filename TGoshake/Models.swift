import Foundation
import CoreLocation
import SwiftUI

enum AppInfo {
    static let version = "0.0.3"
    static let buildDate = "20260925"
    static let developer = "Atex Lin"
    static let feedbackEmail = "atexapp.lin@gmail.com"
    static var displayVersion: String { "V\(version)(\(buildDate))" }
}

enum RecordingPhase: String, Codable {
    case idle
    case calibrating
    case recording
    case paused
    case processing
    case complete
    case failed

    var isActive: Bool {
        switch self {
        case .calibrating, .recording, .paused, .processing, .complete:
            return true
        case .idle, .failed:
            return false
        }
    }
}

struct TripConfiguration: Codable, Equatable {
    var routeName = "西部幹線"
    var direction = "北上"
    var trainType = "EMU3000 自強號"
    var trainNumber = ""
    var carNumber = "1"
    var seatNote = ""
    var mountPosition = "桌板"
    var note = ""
}

enum TripPresetCatalog {
    static let routes = [
        "西部幹線", "山線", "海線", "東部幹線", "宜蘭線", "北迴線", "南迴線", "台灣高鐵", "其他"
    ]

    static let trainCarLimits: [(name: String, cars: Int?)] = [
        ("EMU3000 自強號", 12),
        ("普悠瑪號", 8),
        ("太魯閣號", 8),
        ("EMU900 區間車", 10),
        ("EMU800 區間車", 8),
        ("台灣高鐵", 12),
        ("推拉式自強號", 12),
        ("莒光號", 12),
        ("柴聯自強號", 9),
        ("其他", nil)
    ]

    static var trainTypes: [String] { trainCarLimits.map(\.name) }

    static func carNumbers(for trainType: String) -> [String] {
        guard let limit = trainCarLimits.first(where: { $0.name == trainType })?.cars else {
            return ["其他"]
        }
        return (1...limit).map(String.init) + ["其他"]
    }
}

struct MotionSample: Codable, Identifiable, Equatable {
    var id: Double { elapsed }
    let elapsed: Double
    let utcTime: Date
    let totalX: Double
    let totalY: Double
    let totalZ: Double
    let userX: Double
    let userY: Double
    let userZ: Double
    let gravityX: Double
    let gravityY: Double
    let gravityZ: Double
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double
    let roll: Double
    let pitch: Double
    let yaw: Double

    var lateralMS2: Double { userX * 9.80665 }
    var longitudinalMS2: Double { userY * 9.80665 }
    var verticalMS2: Double { userZ * 9.80665 }
    var resultantMS2: Double {
        sqrt(lateralMS2 * lateralMS2 + longitudinalMS2 * longitudinalMS2 + verticalMS2 * verticalMS2)
    }
}

struct LocationSample: Codable, Identifiable, Equatable {
    var id: Date { utcTime }
    let utcTime: Date
    let elapsed: Double
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double
    let speedAccuracy: Double
    let course: Double
    let courseAccuracy: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isValid: Bool { horizontalAccuracy >= 0 }
}

enum MarkerSource: String, Codable {
    case onScreen
    case gameController
}

enum MarkerInputMode: String, Codable {
    case point
    case interval
}

struct ManualMarker: Codable, Identifiable, Equatable {
    let id: UUID
    let source: MarkerSource
    let inputMode: MarkerInputMode
    let buttonDownElapsed: Double
    let buttonUpElapsed: Double?
    let reviewStartElapsed: Double
    let reviewEndElapsed: Double
    let createdAt: Date
    let controllerName: String?
    let latitude: Double?
    let longitude: Double?
    let horizontalAccuracy: Double?
    var note: String

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum Severity: Int, Codable, CaseIterable, Comparable {
    case calm = 0
    case attention = 1
    case noticeable = 2
    case intense = 3

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .calm: return "平穩"
        case .attention: return "注意"
        case .noticeable: return "明顯"
        case .intense: return "劇烈"
        }
    }

    var color: Color {
        switch self {
        case .calm: return .green
        case .attention: return .yellow
        case .noticeable: return .orange
        case .intense: return .red
        }
    }
}

struct AnalysisWindow: Codable, Identifiable, Equatable {
    let id: UUID
    let startElapsed: Double
    let endElapsed: Double
    let lateralRMS: Double
    let longitudinalRMS: Double
    let verticalRMS: Double
    let resultantRMS: Double
    let resultantP95: Double
    let peak: Double
    let jerkRMS: Double
    let rotationRMS: Double
    var score: Double
    var percentile: Double
    var severity: Severity
    let latitude: Double?
    let longitude: Double?
    let horizontalAccuracy: Double?
    let locationUncertain: Bool
    let sampleCount: Int

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TripMetadata: Codable, Identifiable, Equatable {
    let id: UUID
    let schemaVersion: Int
    let appVersion: String
    let deviceModel: String
    let osVersion: String
    let startTime: Date
    var endTime: Date?
    let configuration: TripConfiguration
    var motionRequestedHz: Double
    var motionActualMedianHz: Double?
    var calibrationRMS: Double?
    var motionSampleCount: Int
    var locationSampleCount: Int
    var markerCount: Int
    var analysisVersion: String?
    var status: String
}

struct StoredTrip: Identifiable, Equatable {
    let id: UUID
    let folderURL: URL
    let metadata: TripMetadata
}

struct MapTrackSegment: Identifiable {
    let id = UUID()
    let start: CLLocationCoordinate2D
    let end: CLLocationCoordinate2D
    let severity: Severity
}

extension Double {
    var oneDecimal: String { formatted(.number.precision(.fractionLength(1))) }
    var twoDecimals: String { formatted(.number.precision(.fractionLength(2))) }
}
