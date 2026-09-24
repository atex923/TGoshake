import Foundation
import GameController

final class ControllerManager: ObservableObject {
    @Published private(set) var connectedNames: [String] = []
    @Published private(set) var isDiscovering = false
    @Published private(set) var lastInputText = "尚未收到按鍵"

    var buttonChanged: ((Bool, String?) -> Void)?

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.configure(controller)
            self?.refreshControllers()
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.refreshControllers()
        })
        GCController.controllers().forEach(configure)
        refreshControllers()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        GCController.stopWirelessControllerDiscovery()
    }

    func startDiscovery() {
        isDiscovering = true
        GCController.startWirelessControllerDiscovery { [weak self] in
            DispatchQueue.main.async {
                self?.isDiscovering = false
                self?.refreshControllers()
            }
        }
    }

    func stopDiscovery() {
        GCController.stopWirelessControllerDiscovery()
        isDiscovering = false
    }

    private func refreshControllers() {
        connectedNames = GCController.controllers().map(\.vendorName).map { $0 ?? "藍牙控制器" }
    }

    private func configure(_ controller: GCController) {
        let name = controller.vendorName ?? "藍牙控制器"
        let handler: GCControllerButtonValueChangedHandler = { [weak self] _, _, pressed in
            DispatchQueue.main.async {
                self?.lastInputText = pressed ? "已按下：\(name)" : "已放開：\(name)"
                self?.buttonChanged?(pressed, name)
            }
        }
        controller.extendedGamepad?.buttonA.pressedChangedHandler = handler
        controller.microGamepad?.buttonA.pressedChangedHandler = handler
    }
}
