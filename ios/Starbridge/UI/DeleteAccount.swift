import SwiftUI

/** Delete account's confirmation: what it does, and "delete" typed before it goes (#1104). */
enum DeleteAccount {
    /** From the inbox: what the server deletes. */
    static let paired = "The server deletes your devices, machines, questions, answers and push targets, and signs out every phone, browser and machine. This can't be undone."

    /**
     * From the join screen: why deleting is the way out for someone with no device and no
     * recovery key (#1117), since no one else holds a key that reads the account or vouches for
     * a new device.
     */
    static let unpaired = "Your questions and answers are end-to-end encrypted: without one of your devices or the recovery key, nobody can read them or add this iPhone, not even the server. Deleting the account lets you start over. It signs out every phone, browser and machine, and can't be undone."
}

private struct DeleteAccountAlert: ViewModifier {
    let store: Store
    @Binding var isPresented: Bool
    let text: String
    @State private var word = ""

    func body(content: Content) -> some View {
        content.alert("Delete your account?", isPresented: $isPresented) {
            TextField("Type delete to confirm", text: $word)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Delete account", role: .destructive) {
                word = ""
                Task { await store.deleteAccount() }
            }
            .disabled(word.trimmingCharacters(in: .whitespaces).lowercased() != "delete")
            Button("Cancel", role: .cancel) { word = "" }
        } message: {
            Text(text)
        }
    }
}

extension View {
    func deleteAccount(store: Store, isPresented: Binding<Bool>, text: String) -> some View {
        modifier(DeleteAccountAlert(store: store, isPresented: isPresented, text: text))
    }
}
