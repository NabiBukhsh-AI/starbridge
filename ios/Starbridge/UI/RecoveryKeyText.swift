import StarbridgeProtocol
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/** What the recovery key screens say about a typed key, in Android's words, and its copy. */
enum RecoveryKeyText {
    static let chars = 28

    static func status(_ reading: RecoveryKeyReading) -> String { "\(reading.count) of \(chars) characters" }

    static func problem(_ reading: RecoveryKeyReading) -> String? {
        switch reading.problem {
        case nil: nil
        case let .badCharacter(index, char): "Character \(index + 1), \"\(char)\", is not in a recovery key."
        case let .length(count): "A recovery key has \(chars) characters; this has \(count)."
        case .checksum: "A character is wrong. Check each group against what you wrote down."
        }
    }

    /** Copies the key for a minute, on this iPhone only: never to the universal clipboard. */
    static func copy(_ key: String) {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: key]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)]
        )
    }
}

/** Covers the screen while the app is not active, so the app switcher's snapshot shows no key. */
private struct PrivacyCover: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.overlay {
            if scenePhase != .active { Tokens.Colors.bg.color.ignoresSafeArea() }
        }
    }
}

extension View {
    func privacyCover() -> some View { modifier(PrivacyCover()) }
}
