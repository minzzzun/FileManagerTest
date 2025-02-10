import Network
import SwiftUI

class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)

    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
                print("📡 네트워크 상태: \(self.isConnected ? "온라인" : "오프라인")")
            }
        }
        monitor.start(queue: queue)
    }
}

