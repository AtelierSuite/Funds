import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let hostingController = UIHostingController(rootView: NotificationCategoryGrid(categories: []))

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    func didReceive(_ notification: UNNotification) {
        let categories = (try? loadTodayBudgetEntry().categories) ?? []
        hostingController.rootView = NotificationCategoryGrid(categories: categories)
        preferredContentSize = hostingController.sizeThatFits(
            in: CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude)
        )
    }
}
