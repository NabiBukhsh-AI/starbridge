import SwiftUI

@main
struct StarbridgeApp: App {
    @State private var store = Store(deviceName: UIDevice.current.name)

    var body: some Scene {
        WindowGroup {
            SetupView(store: store)
                .background(Tokens.Colors.bg.color.ignoresSafeArea())
                .tint(Tokens.Colors.fg.color)
                // A sign-in finished in Safari rather than in the app's sign-in sheet.
                .onOpenURL { url in Task { await store.receiveSignIn(url) } }
        }
    }
}
