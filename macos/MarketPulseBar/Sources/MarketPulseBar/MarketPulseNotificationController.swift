import Foundation
import MarketPulseCore
import UserNotifications

final class MarketPulseNotificationController {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let minimumInterval: TimeInterval = 30 * 60

    private let lastNotifiedSignatureKey = "marketpulse.notifications.lastSignature"
    private let lastSentAtKey = "marketpulse.notifications.lastSentAt"

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in
            // If notifications are denied, the app remains fully usable.
        }
    }

    func consider(snapshot: MarketPulseSnapshot) {
        let signature = signature(for: snapshot)
        guard let previous = defaults.string(forKey: lastNotifiedSignatureKey) else {
            defaults.set(signature, forKey: lastNotifiedSignatureKey)
            return
        }
        guard previous != signature else { return }

        let now = Date()
        if let lastSentAt = defaults.object(forKey: lastSentAtKey) as? Date,
           now.timeIntervalSince(lastSentAt) < minimumInterval {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Market Pulse: \(snapshot.label.rawValue)"
        content.body = notificationBody(for: snapshot)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "marketpulse-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
        defaults.set(signature, forKey: lastNotifiedSignatureKey)
        defaults.set(now, forKey: lastSentAtKey)
    }

    private func signature(for snapshot: MarketPulseSnapshot) -> String {
        let conflicts = snapshot.conflicts.sorted().joined(separator: "|")
        return "\(snapshot.label.rawValue)|\(conflicts)"
    }

    private func notificationBody(for snapshot: MarketPulseSnapshot) -> String {
        if snapshot.conflicts.isEmpty {
            return "Score \(snapshot.score)/100. The market regime changed."
        }
        let conflicts = snapshot.conflicts.joined(separator: " ")
        return "Score \(snapshot.score)/100. \(conflicts)"
    }
}
