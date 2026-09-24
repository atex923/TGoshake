import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var recorder: SessionRecorder
    @State private var exportTrip: StoredTrip?
    @State private var pendingDeletion: StoredTrip?
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            Group {
                if recorder.savedTrips.isEmpty {
                    ContentUnavailableView("尚無歷史記錄", systemImage: "clock.arrow.circlepath", description: Text("完成的行程會保存在 iPhone 本機。"))
                } else {
                    List(recorder.savedTrips) { trip in
                        VStack(alignment: .leading, spacing: 8) {
                            NavigationLink {
                                StoredTripDetailView(trip: trip)
                            } label: {
                                TripRow(trip: trip)
                            }
                            HStack {
                                Text("Motion \(trip.metadata.motionSampleCount) 筆")
                                Text("GPS \(trip.metadata.locationSampleCount) 筆")
                                Text("打卡 \(trip.metadata.markerCount) 筆")
                                Spacer()
                                Button { exportTrip = trip } label: {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = trip
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                            .accessibilityLabel("刪除這筆行程")
                        }
                    }
                    .refreshable { recorder.loadTrips() }
                }
            }
            .navigationTitle("歷史行程")
            .sheet(item: $exportTrip) { trip in
                ExportWarningView(folderURL: trip.folderURL)
                    .presentationDetents([.medium])
            }
            .confirmationDialog("永久刪除這筆行程？", isPresented: deletionConfirmationPresented, titleVisibility: .visible) {
                Button("永久刪除", role: .destructive) {
                    guard let trip = pendingDeletion else { return }
                    do {
                        try recorder.deleteTrip(trip)
                    } catch {
                        deletionError = error.localizedDescription
                    }
                    pendingDeletion = nil
                }
                Button("取消", role: .cancel) {
                    pendingDeletion = nil
                }
            } message: {
                Text("Motion、GPS、晃動標記與分析檔案都會刪除，且無法復原。")
            }
            .alert("無法刪除", isPresented: deletionErrorPresented) {
                Button("好", role: .cancel) { deletionError = nil }
            } message: {
                Text(deletionError ?? "未知錯誤")
            }
        }
    }

    private var deletionConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private var deletionErrorPresented: Binding<Bool> {
        Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )
    }
}

private struct StoredTripDetailView: View {
    let trip: StoredTrip
    @State private var showingExport = false

    var body: some View {
        List {
            Section("行程") {
                LabeledContent("路線", value: trip.metadata.configuration.routeName)
                LabeledContent("方向", value: trip.metadata.configuration.direction)
                LabeledContent("車種", value: trip.metadata.configuration.trainType.isEmpty ? "未填寫" : trip.metadata.configuration.trainType)
                LabeledContent("車次", value: trip.metadata.configuration.trainNumber.isEmpty ? "未填寫" : trip.metadata.configuration.trainNumber)
                LabeledContent("車廂", value: trip.metadata.configuration.carNumber.isEmpty ? "未填寫" : trip.metadata.configuration.carNumber)
                LabeledContent("座位", value: trip.metadata.configuration.seatNote.isEmpty ? "未填寫" : trip.metadata.configuration.seatNote)
                LabeledContent("放置位置", value: trip.metadata.configuration.mountPosition)
            }
            Section("紀錄摘要") {
                LabeledContent("開始", value: trip.metadata.startTime.formatted(date: .abbreviated, time: .standard))
                if let end = trip.metadata.endTime {
                    LabeledContent("結束", value: end.formatted(date: .abbreviated, time: .standard))
                }
                LabeledContent("Motion", value: "\(trip.metadata.motionSampleCount) 筆")
                LabeledContent("GPS", value: "\(trip.metadata.locationSampleCount) 筆")
                LabeledContent("晃動打卡", value: "\(trip.metadata.markerCount) 筆")
                LabeledContent("App 版本", value: trip.metadata.appVersion)
            }
            Section {
                Button {
                    showingExport = true
                } label: {
                    Label("查看／分享完整紀錄", systemImage: "doc.zipper")
                }
            }
        }
        .navigationTitle("行程紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExport) {
            ExportWarningView(folderURL: trip.folderURL)
                .presentationDetents([.medium])
        }
    }
}
