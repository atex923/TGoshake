import SwiftUI
import Charts

struct ActiveSessionView: View {
    @EnvironmentObject private var recorder: SessionRecorder

    var body: some View {
        Group {
            switch recorder.phase {
            case .calibrating:
                CalibrationView()
            case .recording, .paused:
                RecordingView()
            case .processing:
                ProcessingView()
            case .complete:
                ResultsView()
            case .idle, .failed:
                Color.clear
            }
        }
        .interactiveDismissDisabled(recorder.phase != .complete)
    }
}

private struct CalibrationView: View {
    @EnvironmentObject private var recorder: SessionRecorder

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
                .symbolEffect(.pulse)
            Text("保持手機固定")
                .font(.largeTitle.bold())
            Text("平放、螢幕朝上、頂端朝列車前進方向")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("\(recorder.calibrationRemaining)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            ProgressView(value: Double(5 - recorder.calibrationRemaining), total: 5)
                .padding(.horizontal, 44)
        }
        .padding()
    }
}

private struct ProcessingView: View {
    var body: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text("正在封存與分析資料…").font(.headline)
            Text("來源資料不會被濾波結果覆寫")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct RecordingView: View {
    @EnvironmentObject private var recorder: SessionRecorder
    @EnvironmentObject private var controllerManager: ControllerManager
    @State private var confirmingStop = false
    @State private var selectedAxis: MotionAxisSelection = .stacked
    @State private var selectedMarker: ManualMarker?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    controls
                    statusHeader
                    motionChart
                    markerHistory
                    sensorCards
                    bluetoothCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(recorder.phase == .paused ? "記錄已暫停" : "記錄中")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("要結束這趟記錄嗎？", isPresented: $confirmingStop, titleVisibility: .visible) {
                Button("結束並分析", role: .destructive) { recorder.stop() }
                Button("繼續記錄", role: .cancel) { }
            } message: {
                Text("結束後會封存 CSV／JSON 並建立振動熱點。")
            }
            .sheet(item: $selectedMarker) { marker in
                MarkerDetailView(marker: marker)
                    .presentationDetents([.medium])
            }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 10) {
            Text(durationText)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                Circle()
                    .fill(recorder.phase == .recording ? Color.red : Color.orange)
                    .frame(width: 10, height: 10)
                Text(recorder.phase == .recording ? "正在寫入本機資料" : "暫停期間會保留時間缺口")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Button {
                recorder.addOnScreenMarker()
            } label: {
                Label("記錄晃動", systemImage: "hand.tap.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(.purple)
            .disabled(recorder.phase != .recording)
            .accessibilityLabel("記錄目前晃動")
        }
        .cardStyle()
    }

    private var motionChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("最近 10 秒波形（m/s²）").font(.headline)
                Spacer()
                Text("隨時間移動")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("顯示軸向", selection: $selectedAxis) {
                ForEach(MotionAxisSelection.allCases) { axis in
                    Text(axis.title).tag(axis)
                }
            }
            .pickerStyle(.segmented)
            if selectedAxis == .stacked {
                VStack(spacing: 8) {
                    AxisChartCard(title: "X 橫向", color: .blue, samples: visibleSamples, domain: visibleTimeDomain, values: { $0.lateralMS2 })
                    AxisChartCard(title: "Y 縱向", color: .green, samples: visibleSamples, domain: visibleTimeDomain, values: { $0.longitudinalMS2 })
                    AxisChartCard(title: "Z 垂直", color: .red, samples: visibleSamples, domain: visibleTimeDomain, values: { $0.verticalMS2 })
                }
            } else {
                combinedChart
            }
        }
        .cardStyle()
    }

    private var combinedChart: some View {
        Chart {
            ForEach(visibleSamples) { sample in
                if selectedAxis == .all || selectedAxis == .lateral {
                    LineMark(x: .value("秒", sample.elapsed), y: .value("加速度", sample.lateralMS2), series: .value("軸", "橫向 X"))
                        .foregroundStyle(by: .value("軸", "橫向 X"))
                        .lineStyle(StrokeStyle(lineWidth: selectedAxis == .all ? 1.5 : 2.2))
                }
                if selectedAxis == .all || selectedAxis == .longitudinal {
                    LineMark(x: .value("秒", sample.elapsed), y: .value("加速度", sample.longitudinalMS2), series: .value("軸", "縱向 Y"))
                        .foregroundStyle(by: .value("軸", "縱向 Y"))
                        .lineStyle(StrokeStyle(lineWidth: selectedAxis == .all ? 1.5 : 2.2))
                }
                if selectedAxis == .all || selectedAxis == .vertical {
                    LineMark(x: .value("秒", sample.elapsed), y: .value("加速度", sample.verticalMS2), series: .value("軸", "垂直 Z"))
                        .foregroundStyle(by: .value("軸", "垂直 Z"))
                        .lineStyle(StrokeStyle(lineWidth: selectedAxis == .all ? 1.5 : 2.2))
                }
            }
        }
        .chartForegroundStyleScale(["橫向 X": .blue, "縱向 Y": .green, "垂直 Z": .red])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXScale(domain: visibleTimeDomain)
        .chartYScale(domain: -visibleYLimit...visibleYLimit)
        .chartXAxisLabel("經過時間（秒）")
        .chartYAxisLabel("加速度（m/s²）")
        .frame(height: 230)
    }

    private var markerHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("晃動記錄").font(.headline)
                Spacer()
                Text("\(recorder.markers.count) 筆")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let marker = recorder.markers.last {
                Button {
                    selectedMarker = marker
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: marker.source == .gameController ? "gamecontroller.fill" : "hand.tap.fill")
                            .foregroundStyle(.purple)
                        Text(marker.inputMode == .interval ? "最新：晃動區間" : "最新：晃動點")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(markerTimeText(marker))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text("按紫色「記錄晃動」，或使用藍牙控制器 A 鍵建立標記。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var sensorCards: some View {
        HStack(spacing: 12) {
            MetricCard(title: "取樣率", value: recorder.actualMotionHz > 0 ? "\(recorder.actualMotionHz.oneDecimal) Hz" : "等待中", icon: "waveform")
            MetricCard(title: "GPS 精度", value: gpsText, icon: "location")
            MetricCard(title: "速度", value: speedText, icon: "speedometer")
        }
    }

    private var bluetoothCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("藍牙手動打卡", systemImage: "gamecontroller.fill")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(controllerManager.connectedNames.isEmpty ? Color.orange : Color.green)
                    .frame(width: 10, height: 10)
            }
            Text(controllerManager.connectedNames.isEmpty ? "未連接控制器，可用下方紫色按鈕。" : "A 鍵短按標記感受點；按住超過 0.6 秒標記區間。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(controllerManager.lastInputText)
                .font(.caption.monospaced())
        }
        .cardStyle()
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    recorder.phase == .recording ? recorder.pause() : recorder.resume()
                } label: {
                    Label(recorder.phase == .recording ? "暫停" : "繼續", systemImage: recorder.phase == .recording ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    confirmingStop = true
                } label: {
                    Label("結束記錄", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var visibleSamples: [MotionSample] {
        recorder.liveSamples.filter { visibleTimeDomain.contains($0.elapsed) }
    }

    private var visibleTimeDomain: ClosedRange<Double> {
        let end = max(10, max(recorder.elapsed, recorder.liveSamples.last?.elapsed ?? 0))
        return (end - 10)...end
    }

    private var visibleYLimit: Double {
        let values = visibleSamples.flatMap { sample -> [Double] in
            switch selectedAxis {
            case .stacked, .all: return [sample.lateralMS2, sample.longitudinalMS2, sample.verticalMS2]
            case .lateral: return [sample.lateralMS2]
            case .longitudinal: return [sample.longitudinalMS2]
            case .vertical: return [sample.verticalMS2]
            }
        }
        return max(0.5, (values.map { abs($0) }.max() ?? 0.5) * 1.15)
    }

    private func markerTimeText(_ marker: ManualMarker) -> String {
        if let up = marker.buttonUpElapsed, marker.inputMode == .interval {
            return "\(marker.buttonDownElapsed.oneDecimal)–\(up.oneDecimal) 秒"
        }
        return "\(marker.buttonDownElapsed.oneDecimal) 秒"
    }

    private var durationText: String {
        let total = Int(recorder.elapsed)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    private var gpsText: String {
        guard let location = recorder.latestLocation, location.horizontalAccuracy >= 0 else { return "無資料" }
        return "±\(Int(location.horizontalAccuracy)) m"
    }

    private var speedText: String {
        guard let speed = recorder.latestLocation?.speed, speed >= 0 else { return "無資料" }
        return "\((speed * 3.6).oneDecimal) km/h"
    }
}

private struct AxisChartCard: View {
    let title: String
    let color: Color
    let samples: [MotionSample]
    let domain: ClosedRange<Double>
    let values: (MotionSample) -> Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(color)
            Chart(samples) { sample in
                LineMark(
                    x: .value("秒", sample.elapsed),
                    y: .value("加速度", values(sample))
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.8))
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: -yLimit...yLimit)
            .chartLegend(.hidden)
            .frame(height: 82)
        }
        .padding(8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title)波形圖")
    }

    private var yLimit: Double {
        max(0.5, (samples.map { abs(values($0)) }.max() ?? 0.5) * 1.15)
    }
}

private enum MotionAxisSelection: String, CaseIterable, Identifiable {
    case stacked
    case all
    case lateral
    case longitudinal
    case vertical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stacked: return "三排"
        case .all: return "疊圖"
        case .lateral: return "橫向"
        case .longitudinal: return "縱向"
        case .vertical: return "垂直"
        }
    }
}

private struct MarkerDetailView: View {
    let marker: ManualMarker

    var body: some View {
        NavigationStack {
            List {
                Section("記錄") {
                    LabeledContent("型態", value: marker.inputMode == .interval ? "晃動區間" : "晃動點")
                    LabeledContent("來源", value: marker.source == .gameController ? "藍牙控制器" : "畫面按鈕")
                    LabeledContent("開始時間", value: "\(marker.buttonDownElapsed.oneDecimal) 秒")
                    if let end = marker.buttonUpElapsed {
                        LabeledContent("結束時間", value: "\(end.oneDecimal) 秒")
                    }
                    LabeledContent("備註", value: marker.note)
                }
                Section("位置") {
                    if let latitude = marker.latitude, let longitude = marker.longitude {
                        LabeledContent("緯度", value: latitude.formatted(.number.precision(.fractionLength(6))))
                        LabeledContent("經度", value: longitude.formatted(.number.precision(.fractionLength(6))))
                        if let accuracy = marker.horizontalAccuracy {
                            LabeledContent("GPS 精度", value: "±\(Int(accuracy)) m")
                        }
                    } else {
                        Text("此記錄沒有可用 GPS 位置，時間標記仍已保存。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("晃動記錄")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(.indigo)
            Text(value).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}
