import UIKit
import SwiftUI // 1. Tambahkan import SwiftUI
import imi_dolphin_livechat_ios

class ViewController: UIViewController {
    
    let config = ChatConfig.current
    let notificationConnectionStatus = "com.connector.connectionStatus"
    var connector: Connector?

    var dolphinProfile: DolphinProfile = DolphinProfile(
        name: "huhui", email: "huhui@gmail.com", phoneNumber: "0812345678", customerId: "", uid: "12345"
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(doUpdateConnectionStatus(_:)),
            name: Notification.Name(rawValue: notificationConnectionStatus),
            object: nil
        )
        
        connector = Connector.shared
        connector?.setupConnection(
            baseUrl: config.baseUrl,
            clientId: config.clientId,
            clientSecrect: config.clientSecret,
            botId: config.botId,
            generativeBaseUrl: config.generativeBaseUrl,
            jwtToken: config.jwtToken,
            graphAuthUrl: config.graphAuthUrl,
            graphUsername: config.graphUsername,
            graphPassword: config.graphPassword
        )
        connector?.enableGetQueue(isEnable: true)
        connector?.constructConnector(profile: dolphinProfile)

        let chatScreen = ChatScreen()
        let hostingController = UIHostingController(rootView: chatScreen)
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func doUpdateConnectionStatus(_ notification: Notification) {
        guard let status = (notification.object as? Int) ?? (notification.object as? NSNumber)?.intValue else {
            print("Status Koneksi: Menerima notifikasi tetapi object tidak berupa Int (\(String(describing: notification.object)))")
            return
        }
        
        switch status {
        case 1:
            print("Status Koneksi [1]: Sedang Menghubungkan... (Connecting)")
        case 2:
            print("Status Koneksi [2]: Terhubung! (Connected)")
        case 3:
            print("Status Koneksi [3]: Menghubungkan Ulang... (Reconnecting)")
        case 4:
            print("Status Koneksi [4]: Terputus (Disconnected karena keluar dari chat)")
        case 5:
            print("Status Koneksi [5]: Terputus (Error dari sisi server / Kredensial Salah)")
        case 6:
            print("Status Koneksi [6]: Error upload lampiran (Attachment error)")
        default:
            print("Status tidak diketahui: \(status)")
        }
    }
}
