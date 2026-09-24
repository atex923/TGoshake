import SwiftUI

@main
struct TGoshakeApp: App {
    @StateObject private var recorder = SessionRecorder()
    @StateObject private var controllerManager = ControllerManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(recorder)
                .environmentObject(controllerManager)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var recorder: SessionRecorder
    @EnvironmentObject private var controllerManager: ControllerManager

    private var showingActiveSession: Binding<Bool> {
        Binding(
            get: { recorder.phase.isActive },
            set: { newValue in
                if !newValue { recorder.resetToHome() }
            }
        )
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("首頁", systemImage: "waveform.path.ecg") }

            HistoryView()
                .tabItem { Label("歷史", systemImage: "clock.arrow.circlepath") }

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .tint(.indigo)
        .fullScreenCover(isPresented: showingActiveSession) {
            ActiveSessionView()
                .environmentObject(recorder)
                .environmentObject(controllerManager)
        }
        .onAppear {
            controllerManager.buttonChanged = { [weak recorder] pressed, name in
                recorder?.controllerButtonChanged(isPressed: pressed, controllerName: name)
            }
        }
        .alert("火車搖起來", isPresented: Binding(
            get: { recorder.errorMessage != nil },
            set: { if !$0 { recorder.errorMessage = nil } }
        )) {
            Button("好") { recorder.resetToHome() }
        } message: {
            Text(recorder.errorMessage ?? "發生未知錯誤")
        }
    }
}

