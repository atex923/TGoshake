import Foundation
import CoreMotion
import CoreLocation
import UIKit

final class SessionRecorder: NSObject, ObservableObject {
    @Published private(set) var phase: RecordingPhase = .idle
    @Published private(set) var calibrationRemaining = 5
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var actualMotionHz: Double = 0
    @Published private(set) var latestMotion: MotionSample?
    @Published private(set) var latestLocation: LocationSample?
    @Published private(set) var liveSamples: [MotionSample] = []
    @Published private(set) var markers: [ManualMarker] = []
    @Published private(set) var analysisWindows: [AnalysisWindow] = []
    @Published private(set) var savedTrips: [StoredTrip] = []
    @Published var errorMessage: String?

    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "TGoshake.Motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private var motionSamples: [MotionSample] = []
    private var locationSamples: [LocationSample] = []
    private var calibrationSamples: [Double] = []
    private var motionHandle: FileHandle?
    private var locationHandle: FileHandle?
    private var sessionFolder: URL?
    private var metadata: TripMetadata?
    private var anchorUTC = Date()
    private var anchorUptime: TimeInterval = 0
    private var displayTimer: Timer?
    private var calibrationTimer: Timer?
    private var controllerDown: (time: Double, name: String?)?
    private var liveUpdateCounter = 0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        loadTrips()
    }

    var isDeviceMotionAvailable: Bool { motionManager.isDeviceMotionAvailable }
    var locationAuthorization: CLAuthorizationStatus { locationManager.authorizationStatus }
    var currentFolderURL: URL? { sessionFolder }
    var currentMetadata: TripMetadata? { metadata }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func calibrateAndStart(configuration: TripConfiguration) {
        guard phase == .idle || phase == .failed else { return }
        guard motionManager.isDeviceMotionAvailable else {
            fail("此裝置無法提供 Device Motion。模擬器不能取代實體 iPhone 感測測試。")
            return
        }

        errorMessage = nil
        calibrationSamples.removeAll(keepingCapacity: true)
        calibrationRemaining = 5
        phase = .calibrating
        motionManager.deviceMotionUpdateInterval = 0.01
        motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] data, error in
            guard let self else { return }
            if let error {
                self.fail("靜止檢查失敗：\(error.localizedDescription)")
                return
            }
            if let data {
                let magnitude = sqrt(
                    data.userAcceleration.x * data.userAcceleration.x +
                    data.userAcceleration.y * data.userAcceleration.y +
                    data.userAcceleration.z * data.userAcceleration.z
                )
                self.calibrationSamples.append(magnitude)
            }
        }

        calibrationTimer?.invalidate()
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.calibrationRemaining -= 1
            if self.calibrationRemaining <= 0 {
                timer.invalidate()
                self.motionManager.stopDeviceMotionUpdates()
                self.beginRecording(configuration: configuration)
            }
        }
    }

    private func beginRecording(configuration: TripConfiguration) {
        guard calibrationSamples.count >= 50 else {
            fail("靜止檢查收到的 Motion 資料不足，請保持 App 在前景後重新開始。")
            return
        }
        do {
            try prepareSession(configuration: configuration)
        } catch {
            fail("無法建立記錄檔：\(error.localizedDescription)")
            return
        }

        anchorUTC = Date()
        anchorUptime = ProcessInfo.processInfo.systemUptime
        motionSamples.removeAll(keepingCapacity: true)
        locationSamples.removeAll(keepingCapacity: true)
        markers.removeAll(keepingCapacity: true)
        analysisWindows.removeAll(keepingCapacity: true)
        liveSamples.removeAll(keepingCapacity: true)
        elapsed = 0
        actualMotionHz = 0
        phase = .recording
        UIApplication.shared.isIdleTimerDisabled = true

        motionManager.deviceMotionUpdateInterval = 0.01
        motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: motionQueue) { [weak self] data, error in
            guard let self, let data else {
                if let error {
                    DispatchQueue.main.async { self?.errorMessage = "Motion 更新錯誤：\(error.localizedDescription)" }
                }
                return
            }
            self.consumeMotion(data)
        }

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()
        startDisplayTimer()
    }

    func pause() {
        guard phase == .recording else { return }
        phase = .paused
        motionManager.stopDeviceMotionUpdates()
        locationManager.stopUpdatingLocation()
        appendManifest(status: "paused")
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .recording
        motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: motionQueue) { [weak self] data, error in
            guard let self, let data else {
                if let error { DispatchQueue.main.async { self?.errorMessage = error.localizedDescription } }
                return
            }
            self.consumeMotion(data)
        }
        locationManager.startUpdatingLocation()
        appendManifest(status: "recording")
    }

    func stop() {
        guard phase == .recording || phase == .paused else { return }
        phase = .processing
        motionManager.stopDeviceMotionUpdates()
        locationManager.stopUpdatingLocation()
        displayTimer?.invalidate()
        displayTimer = nil
        UIApplication.shared.isIdleTimerDisabled = false

        motionQueue.waitUntilAllOperationsAreFinished()
        closeHandles()
        let windows = TripAnalyzer.analyze(motion: motionSamples, locations: locationSamples)
        analysisWindows = windows
        persistDerivedData(windows)
        finalizeMetadata()
        loadTrips()
        phase = .complete
    }

    func resetToHome() {
        motionManager.stopDeviceMotionUpdates()
        locationManager.stopUpdatingLocation()
        displayTimer?.invalidate()
        calibrationTimer?.invalidate()
        closeHandles()
        UIApplication.shared.isIdleTimerDisabled = false
        phase = .idle
        liveSamples = []
        latestMotion = nil
        latestLocation = nil
        analysisWindows = []
        markers = []
        sessionFolder = nil
        metadata = nil
        errorMessage = nil
        actualMotionHz = 0
    }

    func addOnScreenMarker(note: String = "使用者感受晃動較大") {
        guard phase == .recording else { return }
        addMarker(source: .onScreen, mode: .point, down: elapsed, up: nil, controllerName: nil, note: note)
    }

    func samples(around window: AnalysisWindow) -> [MotionSample] {
        motionSamples.filter { $0.elapsed >= window.startElapsed - 5 && $0.elapsed <= window.endElapsed + 5 }
    }

    func controllerButtonChanged(isPressed: Bool, controllerName: String?) {
        guard phase == .recording else { return }
        let now = ProcessInfo.processInfo.systemUptime - anchorUptime
        if isPressed {
            guard controllerDown == nil else { return }
            controllerDown = (now, controllerName)
        } else if let down = controllerDown {
            controllerDown = nil
            let duration = max(now - down.time, 0)
            let mode: MarkerInputMode = duration >= 0.6 ? .interval : .point
            addMarker(
                source: .gameController,
                mode: mode,
                down: down.time,
                up: now,
                controllerName: down.name,
                note: mode == .interval ? "藍牙控制器：晃動區間" : "藍牙控制器：感受晃動較大"
            )
        }
    }

    private func addMarker(
        source: MarkerSource,
        mode: MarkerInputMode,
        down: Double,
        up: Double?,
        controllerName: String?,
        note: String
    ) {
        let location = nearestLocation(to: down)
        let end = up ?? down
        let marker = ManualMarker(
            id: UUID(),
            source: source,
            inputMode: mode,
            buttonDownElapsed: down,
            buttonUpElapsed: up,
            reviewStartElapsed: max(0, down - (mode == .point ? 3 : 1)),
            reviewEndElapsed: end + (mode == .point ? 5 : 1),
            createdAt: Date(),
            controllerName: controllerName,
            latitude: location?.latitude,
            longitude: location?.longitude,
            horizontalAccuracy: location?.horizontalAccuracy,
            note: note
        )
        markers.append(marker)
        persistMarkers()
    }

    private func nearestLocation(to elapsed: Double) -> LocationSample? {
        guard let location = latestLocation,
              location.isValid,
              abs(location.elapsed - elapsed) <= 10 else { return nil }
        return location
    }

    private func consumeMotion(_ data: CMDeviceMotion) {
        let sampleElapsed = data.timestamp - anchorUptime
        guard sampleElapsed >= 0 else { return }
        let sample = MotionSample(
            elapsed: sampleElapsed,
            utcTime: anchorUTC.addingTimeInterval(sampleElapsed),
            totalX: data.userAcceleration.x + data.gravity.x,
            totalY: data.userAcceleration.y + data.gravity.y,
            totalZ: data.userAcceleration.z + data.gravity.z,
            userX: data.userAcceleration.x,
            userY: data.userAcceleration.y,
            userZ: data.userAcceleration.z,
            gravityX: data.gravity.x,
            gravityY: data.gravity.y,
            gravityZ: data.gravity.z,
            rotationX: data.rotationRate.x,
            rotationY: data.rotationRate.y,
            rotationZ: data.rotationRate.z,
            roll: data.attitude.roll,
            pitch: data.attitude.pitch,
            yaw: data.attitude.yaw
        )
        motionSamples.append(sample)
        writeMotion(sample)
        liveUpdateCounter += 1
        if liveUpdateCounter % 100 == 0 {
            let recent = Array(motionSamples.suffix(200))
            let intervals = zip(recent.dropFirst(), recent)
                .map { $0.0.elapsed - $0.1.elapsed }
                .filter { $0 > 0 }
                .sorted()
            if !intervals.isEmpty {
                let measuredHz = 1 / intervals[intervals.count / 2]
                DispatchQueue.main.async { [weak self] in self?.actualMotionHz = measuredHz }
            }
        }
        if liveUpdateCounter % 5 == 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.latestMotion = sample
                self.liveSamples.append(sample)
                if self.liveSamples.count > 240 { self.liveSamples.removeFirst(self.liveSamples.count - 240) }
            }
        }
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, self.phase == .recording else { return }
            self.elapsed = max(0, ProcessInfo.processInfo.systemUptime - self.anchorUptime)
        }
    }

    private func prepareSession(configuration: TripConfiguration) throws {
        let id = UUID()
        let root = try sessionsRoot()
        let folder = root.appendingPathComponent("\(id.uuidString).tgoshake", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        sessionFolder = folder
        metadata = TripMetadata(
            id: id,
            schemaVersion: 1,
            appVersion: AppInfo.version,
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            startTime: Date(),
            endTime: nil,
            configuration: configuration,
            motionRequestedHz: 100,
            motionActualMedianHz: nil,
            calibrationRMS: sqrt(calibrationSamples.reduce(0) { $0 + $1 * $1 } / Double(calibrationSamples.count)),
            motionSampleCount: 0,
            locationSampleCount: 0,
            markerCount: 0,
            analysisVersion: nil,
            status: "recording"
        )

        let motionURL = folder.appendingPathComponent("motion.csv")
        let locationURL = folder.appendingPathComponent("location.csv")
        try Data(MotionCSV.header.utf8).write(to: motionURL, options: .atomic)
        try Data(LocationCSV.header.utf8).write(to: locationURL, options: .atomic)
        motionHandle = try FileHandle(forWritingTo: motionURL)
        locationHandle = try FileHandle(forWritingTo: locationURL)
        try motionHandle?.seekToEnd()
        try locationHandle?.seekToEnd()
        persistMetadata()
        appendManifest(status: "recording")
    }

    private func writeMotion(_ sample: MotionSample) {
        let line = MotionCSV.line(sample)
        try? motionHandle?.write(contentsOf: Data(line.utf8))
    }

    private func writeLocation(_ sample: LocationSample) {
        let line = LocationCSV.line(sample)
        try? locationHandle?.write(contentsOf: Data(line.utf8))
    }

    private func closeHandles() {
        try? motionHandle?.synchronize()
        try? locationHandle?.synchronize()
        try? motionHandle?.close()
        try? locationHandle?.close()
        motionHandle = nil
        locationHandle = nil
    }

    private func finalizeMetadata() {
        guard var value = metadata else { return }
        value.endTime = Date()
        value.motionActualMedianHz = actualMotionHz
        value.motionSampleCount = motionSamples.count
        value.locationSampleCount = locationSamples.count
        value.markerCount = markers.count
        value.analysisVersion = TripAnalyzer.analysisVersion
        value.status = "complete"
        metadata = value
        persistMetadata()
        appendManifest(status: "complete")
    }

    private func persistMetadata() {
        guard let metadata, let sessionFolder else { return }
        let encoder = JSONEncoder.tgoshake
        if let data = try? encoder.encode(metadata) {
            try? data.write(to: sessionFolder.appendingPathComponent("metadata.json"), options: .atomic)
        }
    }

    private func persistMarkers() {
        guard let sessionFolder, let data = try? JSONEncoder.tgoshake.encode(markers) else { return }
        try? data.write(to: sessionFolder.appendingPathComponent("markers.json"), options: .atomic)
    }

    private func persistDerivedData(_ windows: [AnalysisWindow]) {
        guard let sessionFolder, let data = try? JSONEncoder.tgoshake.encode(windows) else { return }
        try? data.write(to: sessionFolder.appendingPathComponent("events.json"), options: .atomic)
        persistMarkers()
    }

    private func appendManifest(status: String) {
        guard let sessionFolder, let metadata else { return }
        let object: [String: Any] = [
            "sessionID": metadata.id.uuidString,
            "schemaVersion": metadata.schemaVersion,
            "status": status,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: sessionFolder.appendingPathComponent("manifest.json"), options: .atomic)
        }
    }

    private func sessionsRoot() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = documents.appendingPathComponent("TGoshakeSessions", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func loadTrips() {
        guard let root = try? sessionsRoot(),
              let folders = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            savedTrips = []
            return
        }
        let decoder = JSONDecoder.tgoshake
        savedTrips = folders.compactMap { folder in
            let url = folder.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: url),
                  let value = try? decoder.decode(TripMetadata.self, from: data) else { return nil }
            return StoredTrip(id: value.id, folderURL: folder, metadata: value)
        }.sorted { $0.metadata.startTime > $1.metadata.startTime }
    }

    func deleteTrip(_ trip: StoredTrip) throws {
        guard phase == .idle || phase == .failed else {
            throw SessionDeletionError.recordingInProgress
        }
        let root = try sessionsRoot().standardizedFileURL
        let target = trip.folderURL.standardizedFileURL
        guard target.deletingLastPathComponent() == root,
              target.pathExtension == "tgoshake" else {
            throw SessionDeletionError.invalidFolder
        }
        try FileManager.default.removeItem(at: target)
        loadTrips()
    }

    private func fail(_ message: String) {
        motionManager.stopDeviceMotionUpdates()
        locationManager.stopUpdatingLocation()
        closeHandles()
        UIApplication.shared.isIdleTimerDisabled = false
        errorMessage = message
        phase = .failed
    }
}

enum SessionDeletionError: LocalizedError {
    case recordingInProgress
    case invalidFolder

    var errorDescription: String? {
        switch self {
        case .recordingInProgress:
            return "記錄進行中，現在不能刪除歷史資料。"
        case .invalidFolder:
            return "資料夾位置不符合 TGoshake 記錄格式，已取消刪除。"
        }
    }
}

extension SessionRecorder: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        objectWillChange.send()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard phase == .recording else { return }
        for location in locations {
            let sampleElapsed = location.timestamp.timeIntervalSince(anchorUTC)
            guard sampleElapsed >= 0 else { continue }
            let sample = LocationSample(
                utcTime: location.timestamp,
                elapsed: sampleElapsed,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude,
                horizontalAccuracy: location.horizontalAccuracy,
                verticalAccuracy: location.verticalAccuracy,
                speed: location.speed,
                speedAccuracy: location.speedAccuracy,
                course: location.course,
                courseAccuracy: location.courseAccuracy
            )
            motionQueue.addOperation { [weak self] in
                self?.locationSamples.append(sample)
                self?.writeLocation(sample)
            }
            latestLocation = sample
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "定位更新暫時失敗：\(error.localizedDescription)"
    }
}

private enum MotionCSV {
    static let header = "elapsed_s,utc_time,total_x_g,total_y_g,total_z_g,user_x_g,user_y_g,user_z_g,gravity_x_g,gravity_y_g,gravity_z_g,rotation_x_rad_s,rotation_y_rad_s,rotation_z_rad_s,roll_rad,pitch_rad,yaw_rad,lateral_m_s2,longitudinal_m_s2,vertical_m_s2\n"

    static func line(_ s: MotionSample) -> String {
        let values: [String] = [
            f(s.elapsed), ISO8601DateFormatter.tgoshake.string(from: s.utcTime),
            f(s.totalX), f(s.totalY), f(s.totalZ), f(s.userX), f(s.userY), f(s.userZ),
            f(s.gravityX), f(s.gravityY), f(s.gravityZ), f(s.rotationX), f(s.rotationY), f(s.rotationZ),
            f(s.roll), f(s.pitch), f(s.yaw), f(s.lateralMS2), f(s.longitudinalMS2), f(s.verticalMS2)
        ]
        return values.joined(separator: ",") + "\n"
    }

    private static func f(_ value: Double) -> String { String(format: "%.7f", locale: Locale(identifier: "en_US_POSIX"), value) }
}

private enum LocationCSV {
    static let header = "elapsed_s,utc_time,latitude,longitude,altitude_m,horizontal_accuracy_m,vertical_accuracy_m,speed_m_s,speed_accuracy_m_s,course_deg,course_accuracy_deg\n"

    static func line(_ s: LocationSample) -> String {
        let values = [
            f(s.elapsed), ISO8601DateFormatter.tgoshake.string(from: s.utcTime), f(s.latitude), f(s.longitude),
            f(s.altitude), f(s.horizontalAccuracy), f(s.verticalAccuracy), f(s.speed), f(s.speedAccuracy),
            f(s.course), f(s.courseAccuracy)
        ]
        return values.joined(separator: ",") + "\n"
    }

    private static func f(_ value: Double) -> String { String(format: "%.7f", locale: Locale(identifier: "en_US_POSIX"), value) }
}

private extension JSONEncoder {
    static var tgoshake: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var tgoshake: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension ISO8601DateFormatter {
    static let tgoshake: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
