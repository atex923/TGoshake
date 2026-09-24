import SwiftUI
import UIKit
import CoreLocation

struct HomeView: View {
    @EnvironmentObject private var recorder: SessionRecorder
    @EnvironmentObject private var controllerManager: ControllerManager
    @State private var showingSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    readinessCard
                    controllerCard
                    recentTrips
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("火車搖起來")
            .sheet(isPresented: $showingSetup) {
                TripSetupView()
                    .environmentObject(recorder)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Image(systemName: "tram.fill")
                .font(.system(size: 54))
                .foregroundStyle(.indigo)
                .symbolEffect(.pulse)
            Text("記錄列車位置與三軸晃動")
                .font(.title2.bold())
            Text("找出本趟相對劇烈的區段。結果僅供初步篩查，不代表軌道故障或安全判定。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingSetup = true
            } label: {
                Label("開始新記錄", systemImage: "record.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            Text(AppInfo.displayVersion)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var readinessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("裝置狀態", systemImage: "iphone.gen3")
                .font(.headline)
            StatusRow(title: "Device Motion", ready: recorder.isDeviceMotionAvailable, detail: recorder.isDeviceMotionAvailable ? "可使用" : "需使用實體 iPhone")
            StatusRow(title: "定位權限", ready: locationReady, detail: locationText)
        }
        .cardStyle()
    }

    private var controllerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("藍牙手動打卡", systemImage: "gamecontroller.fill")
                .font(.headline)
            Text(controllerManager.connectedNames.isEmpty ? "未連接相容控制器；記錄時仍可用畫面按鈕。" : "已連接：\(controllerManager.connectedNames.joined(separator: "、"))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    @ViewBuilder
    private var recentTrips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近記錄")
                .font(.headline)
            if recorder.savedTrips.isEmpty {
                ContentUnavailableView("尚無記錄", systemImage: "map", description: Text("完成第一趟實機記錄後會顯示在這裡。"))
                    .frame(minHeight: 150)
            } else {
                ForEach(recorder.savedTrips.prefix(3)) { trip in
                    TripRow(trip: trip)
                    if trip.id != recorder.savedTrips.prefix(3).last?.id { Divider() }
                }
            }
        }
        .cardStyle()
    }

    private var locationReady: Bool {
        recorder.locationAuthorization == .authorizedWhenInUse || recorder.locationAuthorization == .authorizedAlways
    }

    private var locationText: String {
        switch recorder.locationAuthorization {
        case .authorizedAlways, .authorizedWhenInUse: return "可使用"
        case .denied, .restricted: return "未授權"
        case .notDetermined: return "開始前詢問"
        @unknown default: return "未知"
        }
    }
}

private struct TripSetupView: View {
    @EnvironmentObject private var recorder: SessionRecorder
    @Environment(\.dismiss) private var dismiss
    @State private var config = TripConfiguration()
    @State private var customRoute = ""
    @State private var customTrainType = ""
    @State private var customCarNumber = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("行程") {
                    Picker("路線名稱", selection: $config.routeName) {
                        ForEach(TripPresetCatalog.routes, id: \.self) { Text($0).tag($0) }
                    }
                    if config.routeName == "其他" {
                        TextField("手動輸入路線名稱", text: $customRoute)
                    }
                    Picker("方向", selection: $config.direction) {
                        Text("北上").tag("北上")
                        Text("南下").tag("南下")
                        Text("其他").tag("其他")
                    }
                    Picker("車種", selection: $config.trainType) {
                        ForEach(TripPresetCatalog.trainTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: config.trainType) { _, newValue in
                        let allowed = TripPresetCatalog.carNumbers(for: newValue)
                        if !allowed.contains(config.carNumber) { config.carNumber = allowed.first ?? "其他" }
                    }
                    if config.trainType == "其他" {
                        TextField("手動輸入車種", text: $customTrainType)
                    }
                    TextField("車次", text: $config.trainNumber)
                    Picker("車廂", selection: $config.carNumber) {
                        ForEach(TripPresetCatalog.carNumbers(for: config.trainType), id: \.self) { car in
                            Text(car == "其他" ? "其他／手動輸入" : "第 \(car) 車").tag(car)
                        }
                    }
                    if config.carNumber == "其他" {
                        TextField("手動輸入車廂", text: $customCarNumber)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    TextField("座位／位置（手動輸入）", text: $config.seatNote)
                }

                Section("手機固定") {
                    Picker("放置處", selection: $config.mountPosition) {
                        ForEach(["桌板", "座椅", "地板", "支架", "機車頭", "機車尾", "其他"], id: \.self) { Text($0) }
                    }
                    Label("平放、螢幕朝上、手機頂端朝列車前進方向", systemImage: "iphone.landscape")
                        .font(.subheadline)
                    Text("不可手持或放在鬆軟包包中；需要移動手機時請先暫停。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("藍牙控制器") {
                    Text("已配對的 iOS 遊戲控制器可用 A 鍵打卡：短按標記感受點，按住超過 0.6 秒標記區間。")
                    Text("未連接時可使用記錄頁的紫色畫面按鈕。")
                        .foregroundStyle(.secondary)
                }

                Section("備註") {
                    TextField("天候、載客或其他情況", text: $config.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Text("開始後先做 5 秒靜止檢查。記錄期間螢幕會保持喚醒，GPS 與感測資料只保存在本機。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新記錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("開始檢查") {
                        if config.routeName == "其他" { config.routeName = customRoute.trimmingCharacters(in: .whitespacesAndNewlines) }
                        if config.trainType == "其他" { config.trainType = customTrainType.trimmingCharacters(in: .whitespacesAndNewlines) }
                        if config.carNumber == "其他" { config.carNumber = customCarNumber.trimmingCharacters(in: .whitespacesAndNewlines) }
                        recorder.requestLocationPermission()
                        recorder.calibrateAndStart(configuration: config)
                        dismiss()
                    }
                    .disabled(!setupIsValid)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .accessibilityLabel("隱藏鍵盤")
            }
        }
    }

    private var setupIsValid: Bool {
        let route = config.routeName == "其他" ? customRoute : config.routeName
        let train = config.trainType == "其他" ? customTrainType : config.trainType
        let car = config.carNumber == "其他" ? customCarNumber : config.carNumber
        return !route.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !train.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !car.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct StatusRow: View {
    let title: String
    let ready: Bool
    let detail: String

    var body: some View {
        HStack {
            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ready ? .green : .orange)
            Text(title)
            Spacer()
            Text(detail).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

struct TripRow: View {
    let trip: StoredTrip

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.metadata.configuration.routeName).font(.headline)
                Text("\(trip.metadata.configuration.direction)・\(trip.metadata.startTime.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(trip.metadata.status == "complete" ? "完成" : "未完成")
                .font(.caption.bold())
                .foregroundStyle(trip.metadata.status == "complete" ? .green : .orange)
        }
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
