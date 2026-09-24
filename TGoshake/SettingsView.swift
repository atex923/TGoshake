import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var controllerManager: ControllerManager

    var body: some View {
        NavigationStack {
            Form {
                Section("藍牙手動打卡") {
                    if controllerManager.connectedNames.isEmpty {
                        Label("未連接相容控制器", systemImage: "gamecontroller")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controllerManager.connectedNames, id: \.self) { name in
                            Label(name, systemImage: "gamecontroller.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    Button(controllerManager.isDiscovering ? "停止搜尋" : "搜尋遊戲控制器") {
                        controllerManager.isDiscovering ? controllerManager.stopDiscovery() : controllerManager.startDiscovery()
                    }
                    Text(controllerManager.lastInputText)
                        .font(.caption.monospaced())
                    Text("支援已配對、符合 Apple Game Controller profile 的藍牙控制器。A 鍵短按標記感受點，按住超過 0.6 秒標記區間。一般自拍器不保證相容。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("記錄設定") {
                    LabeledContent("Device Motion 請求", value: "100 Hz")
                    LabeledContent("分析窗", value: "1 秒／50% 重疊")
                    LabeledContent("儲存", value: "本機 CSV／JSON")
                    Text("實際取樣率依 iPhone 硬體與系統狀態而定，App 會保存時間戳而不補造樣本。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("資料與隱私") {
                    Text("行程資料僅存於本機；匯出檔包含 GPS，分享前請確認對象。")
                    Text("本 App 僅供相對晃動篩查，不作軌道安全判定。")
                        .foregroundStyle(.secondary)
                }

                Section("版本") {
                    LabeledContent("英文名稱", value: "TGoshake")
                    LabeledContent("中文名稱", value: "火車搖起來")
                    LabeledContent("版本", value: AppInfo.displayVersion)
                    LabeledContent("程式設計者", value: AppInfo.developer)
                    Link(destination: URL(string: "mailto:\(AppInfo.feedbackEmail)")!) {
                        LabeledContent("使用回饋信箱", value: AppInfo.feedbackEmail)
                    }
                }
            }
            .navigationTitle("設定與說明")
        }
    }
}
