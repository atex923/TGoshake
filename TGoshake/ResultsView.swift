import SwiftUI
import MapKit
import Charts

struct ResultsView: View {
    @EnvironmentObject private var recorder: SessionRecorder
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedWindow: AnalysisWindow?
    @State private var showingExport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    summary
                    map
                    legend
                    eventList
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("行程結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { recorder.resetToHome() }
                }
                if let folder = recorder.currentFolderURL {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingExport = true } label: { Image(systemName: "square.and.arrow.up") }
                            .sheet(isPresented: $showingExport) {
                                ExportWarningView(folderURL: folder)
                                    .presentationDetents([.medium])
                            }
                    }
                }
            }
            .sheet(item: $selectedWindow) { window in
                EventDetailView(window: window, samples: recorder.samples(around: window))
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recorder.currentMetadata?.configuration.routeName ?? "本次行程")
                .font(.title2.bold())
            HStack {
                SummaryItem(title: "分析窗", value: "\(recorder.analysisWindows.count)")
                SummaryItem(title: "人工打卡", value: "\(recorder.markers.count)")
                SummaryItem(title: "紅色區段", value: "\(recorder.analysisWindows.filter { $0.severity == .intense }.count)")
            }
            Text("顏色只代表本趟相對程度，不是軌道安全判定。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var map: some View {
        Map(position: $mapPosition) {
            ForEach(trackSegments) { segment in
                MapPolyline(coordinates: [segment.start, segment.end])
                    .stroke(segment.severity.color, lineWidth: 6)
            }
            ForEach(recorder.analysisWindows.filter { $0.severity >= .noticeable }) { window in
                if let coordinate = window.coordinate {
                    MapCircle(center: coordinate, radius: max(20, window.horizontalAccuracy ?? 20))
                        .foregroundStyle(window.severity.color.opacity(0.18))
                        .stroke(window.severity.color, lineWidth: 1)
                }
            }
            ForEach(recorder.markers) { marker in
                if let coordinate = marker.coordinate {
                    Annotation("人工感受", coordinate: coordinate) {
                        Button { selectNearestWindow(to: marker.buttonDownElapsed) } label: {
                            Image(systemName: "hand.tap.fill")
                                .padding(8)
                                .background(.purple, in: Circle())
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                    }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .frame(height: 390)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .topLeading) {
            if recorder.analysisWindows.allSatisfy({ $0.coordinate == nil }) {
                Text("沒有可用 GPS，振動資料仍已保存")
                    .font(.caption.bold())
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(10)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(Severity.allCases, id: \.self) { level in
                Label(level.title, systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(level.color)
            }
            Label("人工", systemImage: "hand.tap.fill")
                .font(.caption)
                .foregroundStyle(.purple)
        }
        .frame(maxWidth: .infinity)
    }

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("明顯區段").font(.headline)
            let events = recorder.analysisWindows.filter { $0.severity >= .noticeable }
            if events.isEmpty {
                Text("本趟沒有產生橘色或紅色分析窗。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events.prefix(30)) { window in
                    Button { selectedWindow = window } label: {
                        HStack {
                            Circle().fill(window.severity.color).frame(width: 10, height: 10)
                            VStack(alignment: .leading) {
                                Text("\(window.startElapsed.oneDecimal)–\(window.endElapsed.oneDecimal) 秒")
                                Text("垂直 RMS \(window.verticalRMS.twoDecimals) m/s²・P\(Int(window.percentile * 100))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .cardStyle()
    }

    private var trackSegments: [MapTrackSegment] {
        let located = recorder.analysisWindows.compactMap { window -> (AnalysisWindow, CLLocationCoordinate2D)? in
            guard let coordinate = window.coordinate else { return nil }
            return (window, coordinate)
        }
        guard located.count > 1 else { return [] }
        return zip(located, located.dropFirst()).map { current, next in
            MapTrackSegment(start: current.1, end: next.1, severity: current.0.severity)
        }
    }

    private func selectNearestWindow(to elapsed: Double) {
        selectedWindow = recorder.analysisWindows.min { abs($0.startElapsed - elapsed) < abs($1.startElapsed - elapsed) }
    }
}

struct ExportWarningView: View {
    @Environment(\.dismiss) private var dismiss
    let folderURL: URL
    @State private var acknowledged = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("這個行程包含精確 GPS", systemImage: "location.fill")
                        .foregroundStyle(.orange)
                    Text("分享完整 .tgoshake 資料夾會包含乘車時間、路線、座標、速度、定位精度、Motion 與人工打卡。只分享給你信任的對象。")
                        .font(.subheadline)
                    Toggle("我了解分享內容包含精確位置", isOn: $acknowledged)
                }
                Section {
                    ShareLink(item: folderURL) {
                        Label("分享完整行程資料", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!acknowledged)
                }
                Section {
                    Text("移除 GPS 的匿名匯出會在後續版本加入。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("匯出確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }
}

private struct SummaryItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(value).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EventDetailView: View {
    let window: AnalysisWindow
    let samples: [MotionSample]

    var nearbySamples: [MotionSample] {
        samples.filter { $0.elapsed >= window.startElapsed - 5 && $0.elapsed <= window.endElapsed + 5 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("相對程度") {
                    LabeledContent("級別", value: window.severity.title)
                    LabeledContent("百分位", value: "P\(Int(window.percentile * 100))")
                    LabeledContent("時間", value: "\(window.startElapsed.oneDecimal)–\(window.endElapsed.oneDecimal) 秒")
                }
                Section("三軸 RMS") {
                    LabeledContent("橫向", value: "\(window.lateralRMS.twoDecimals) m/s²")
                    LabeledContent("縱向", value: "\(window.longitudinalRMS.twoDecimals) m/s²")
                    LabeledContent("垂直", value: "\(window.verticalRMS.twoDecimals) m/s²")
                    LabeledContent("合成", value: "\(window.resultantRMS.twoDecimals) m/s²")
                    LabeledContent("峰值", value: "\(window.peak.twoDecimals) m/s²")
                }
                Section("位置品質") {
                    LabeledContent("GPS", value: window.locationUncertain ? "位置不確定" : "可使用")
                    if let accuracy = window.horizontalAccuracy {
                        LabeledContent("平面精度", value: "±\(Int(accuracy)) m")
                    }
                }
                if !nearbySamples.isEmpty {
                    Section("事件前後波形") {
                        Chart(nearbySamples) { sample in
                            LineMark(x: .value("秒", sample.elapsed), y: .value("垂直", sample.verticalMS2))
                                .foregroundStyle(.red)
                        }
                        .frame(height: 180)
                    }
                }
                Section {
                    Text("這是本趟相對熱點，不代表軌道故障或危險。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("熱點詳情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
