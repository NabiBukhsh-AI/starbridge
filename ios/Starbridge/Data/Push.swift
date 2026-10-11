import Foundation
import StarbridgeProtocol
import UIKit
import UserNotifications

/**
 * Notifications on the app's side (#1137): asking for them, subscribing the APNs token, and
 * answering from a notification's buttons through the outbox (#329), as Android's receivers do.
 * The notification service extension writes what each notification says.
 */
extension Store {
    /** Asks once to notify, then registers for pushes; says on the server whether it notifies. */
    func enableNotifications() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        let state = await center.notificationSettings().authorizationStatus
        try? await api().notificationState(state == .denied ? "blocked" : granted ? "on" : "off")
        // The categories without per-question buttons; the extension adds each question's own.
        let categories = await center.notificationCategories()
        if !categories.contains(where: { $0.identifier == "permission" }) {
            center.setNotificationCategories(categories.union([Notify.category("permission", Notify.permissionActions)]))
        }
        if granted { UIApplication.shared.registerForRemoteNotifications() }
    }

    /** APNs gave this iPhone its token: debug builds talk to APNs' sandbox, others to production. */
    func registered(token: Data) async {
        guard phase == .ready else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        do {
            let id = try await api().subscribe(apnsToken: token.map { String(format: "%02x", $0) }.joined(), environment: environment)
            var s = saved
            s.pushId = id
            persist(s)
        } catch {
            // The next launch registers again; the inbox still reads the server while open.
        }
    }

    /** Fetches item `id` and keeps it, when it opens; for a notification the inbox has not read yet. */
    func fetch(_ id: String) async throws {
        if directory == nil { try await syncDirectory() }
        let listed = try await api().item(id)
        if directory?.members[listed.item.from] == nil { try await syncDirectory() }
        guard let o = open(listed.item, entries: saved.entries.compactMap { try? JSON.parse($0) }) else { return }
        var s = saved
        switch listed.item.kind {
        case .decision:
            guard let d = try? SavedDecision(from: o.from, text: o.text, answeredAt: listed.answeredAt), decision(id) == nil else { return }
            s.decisions.append(d)
        case .permission:
            guard let p = try? SavedPrompt(from: o.from, text: o.text, answeredAt: listed.answeredAt), prompt(id) == nil else { return }
            s.prompts.append(p)
        default:
            return
        }
        persist(s)
    }

    /**
     * Answers from a notification's button or Reply, with the time iOS gives it in the
     * background: fetches the question when the inbox has not read it, then sends as a tap does.
     * Tells the notification how it ended: gone once sent, else "waiting to send" or "Not sent".
     */
    func answerFromNotification(_ id: String, choice: String?, text: String?) async {
        let sent: Sent
        do {
            sent = try await serial {
                if self.decision(id) == nil { try await self.fetch(id) }
                return try await self.send(id, choice: choice, text: text)
            }
        } catch {
            sent = .failed(describe(error))
        }
        switch sent {
        case .answered, .elsewhere:
            await Self.removeDelivered(about: id)
        case let .queued(answer):
            await replace(id, with: "\(answer) · waiting to send")
        case let .failed(why):
            notSent[id] = why
            await replace(id, with: "Not sent: \(why)")
        }
    }

    /**
     * Deny from a notification: for this call only, as from the inbox. The notification goes once
     * the server took it; else it stays, saying why, so the owner can deny from the app.
     */
    func denyFromNotification(_ id: String) async {
        do {
            try await serial { if self.prompt(id) == nil { try await self.fetch(id) } }
        } catch {}
        let sent = await answerPrompt(id, allow: false)
        // Answered, expired, gone, or its machine revoked: no deny will ever land, so the notification goes too.
        let moot = prompt(id).map { !$0.isOpen || directory?.members[$0.from]?.active == false } ?? true
        if sent || moot {
            notice = sent ? notice : nil
            await Self.removeDelivered(about: id)
        } else {
            let why = notice ?? "the server did not take it."
            notice = nil
            await replace(id, with: "Deny not sent: \(why)", kind: "permission", title: prompt(id).map(\.headline), source: prompt(id)?.body.source)
        }
    }

    /** The item's notification again, quiet, saying how its answer ended. */
    private func replace(_ id: String, with note: String, kind: String = "decision", title: String? = nil, source: Source? = nil) async {
        let content = UNMutableNotificationContent()
        if let title = title ?? decision(id)?.body.question { content.title = title }
        if let source = source ?? decision(id)?.body.source { content.subtitle = Notify.header(source) }
        content.body = note
        content.interruptionLevel = .passive
        content.userInfo = ["p": ["v": 1, "kind": kind, "id": id]]
        await Self.removeDelivered(about: id)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    /** Closes every notification about item `id`: answered, settled, or snoozed elsewhere. */
    static func removeDelivered(about id: String) async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.deliveredNotifications()
            .filter { $0.request.identifier == id || Notify.payload($0.request.content.userInfo).flatMap(Notify.item) == id }
            .map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /**
     * A background push: an answer from anywhere, a settled notice or a snooze closes its
     * notification; then the inbox reads what changed.
     */
    func backgroundPush(_ userInfo: [AnyHashable: Any]) async {
        guard let p = Notify.payload(userInfo), let id = Notify.item(p) else { return }
        if ["answered", "settled", "snooze"].contains(p["kind"]?.string) { await Self.removeDelivered(about: id) }
        try? await serial { try await self.sync() }
    }
}

/** Routes notifications for the app: pushes, taps and buttons. */
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    lazy var store = Store(deviceName: UIDevice.current.name)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in await store.registered(token: deviceToken) }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await store.backgroundPush(userInfo)
        return .newData
    }

    /** In front, a question still shows its banner: the owner may be looking at another one. */
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let p = Notify.payload(response.notification.request.content.userInfo), let id = Notify.item(p) else { return }
        let text = (response as? UNTextInputNotificationResponse)?.userText
        await handle(response.actionIdentifier, id: id, kind: p["kind"]?.string, text: text)
    }

    private func handle(_ action: String, id: String, kind: String?, text: String?) async {
        switch action {
        case "reply":
            let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty { await store.answerFromNotification(id, choice: nil, text: text) }
        case "deny":
            await store.denyFromNotification(id)
        case "page":
            if let url = store.decision(id)?.body.answerIn.flatMap({ URL(string: $0.url) }) { await UIApplication.shared.open(url) }
            store.openRequest = .decision(id)
        case _ where action.hasPrefix(Notify.optionPrefix):
            await store.answerFromNotification(id, choice: String(action.dropFirst(Notify.optionPrefix.count)), text: nil)
        default:
            // A tap, or Allow, which opens the prompt to read the whole input first (#356).
            let prompt = kind == "permission"
            store.openRequest = prompt ? .prompt(id) : .decision(id)
            let store = store
            try? await store.serial { if prompt ? store.prompt(id) == nil : store.decision(id) == nil { try await store.fetch(id) } }
        }
    }
}
