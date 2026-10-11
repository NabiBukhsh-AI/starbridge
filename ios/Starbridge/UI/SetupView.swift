import AuthenticationServices
import StarbridgeProtocol
import SwiftUI

/** Setup, from signing in to joining the account: one screen per [Phase], as on Android. */
struct SetupView: View {
    let store: Store

    var body: some View {
        step
            .foregroundStyle(Tokens.Colors.fg.color)
            .alert("Starbridge", isPresented: showsNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.notice ?? "")
            }
    }

    private var showsNotice: Binding<Bool> {
        Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })
    }

    @ViewBuilder private var step: some View {
        switch store.phase {
        case .signedOut: SignInStep(store: store)
        case .noDevice(accountExists: true): JoinStep(store: store)
        case .noDevice(accountExists: false): NoDeviceStep(store: store)
        case .joining:
            WaitingStep(store: store, title: "Approve this iPhone", text: "Approve it on the device that shows the QR code.", digits: nil)
        case .joiningByDigits(nil, _):
            WaitingStep(store: store, title: "Compare digits", text: "Approve on your other device if the digits match.", digits: nil)
        case let .joiningByDigits(digits, false):
            WaitingStep(store: store, title: "Compare digits", text: "Does your other device show the same digits?", digits: digits, onMatch: { store.confirmDigits() })
        case let .joiningByDigits(digits, true):
            WaitingStep(store: store, title: "Compare digits", text: "Approve on your other device.", digits: digits)
        case .ready: ReadyStep(store: store)
        }
    }
}

/** A setup step: `top` from the top, its actions at the bottom. */
private struct Step<Top: View, Bottom: View>: View {
    @ViewBuilder let top: Top
    @ViewBuilder let bottom: Bottom

    var body: some View {
        GeometryReader { screen in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    top
                    Spacer(minLength: Tokens.Spacing.s8)
                    VStack(spacing: Tokens.Spacing.s3) { bottom }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Tokens.Spacing.s4)
                        .padding(.bottom, Tokens.Spacing.s6)
                }
                .frame(maxWidth: .infinity, minHeight: screen.size.height, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct Title: View {
    let text: String

    var body: some View {
        Text(text)
            .type(Tokens.Typography.title)
            .padding(.horizontal, Tokens.Spacing.s4)
            .padding(.top, Tokens.Spacing.s12)
            .padding(.bottom, Tokens.Spacing.s4)
    }
}

private struct Lede: View {
    let text: String

    var body: some View {
        Text(text)
            .type(Tokens.Typography.body)
            .foregroundStyle(Tokens.Colors.fg2.color)
            .padding(.horizontal, Tokens.Spacing.s4)
    }
}

/** The main action: filled in `fg`, the full width. */
private struct Primary: ButtonStyle {
    var busy = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label.opacity(busy ? 0 : 1)
            if busy { ProgressView().tint(Tokens.Colors.bg.color) }
        }
        .type(Tokens.Typography.action)
        .foregroundStyle(Tokens.Colors.bg.color)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Capsule().fill(Tokens.Colors.fg.color.opacity(enabled ? 1 : 0.38)))
        .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/** The second action: outlined. */
private struct Secondary: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .type(Tokens.Typography.action)
            .frame(maxWidth: .infinity, minHeight: 56)
            .overlay(Capsule().stroke(Tokens.Colors.lineStrong.color))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/** A text field on a filled box, its label above what it holds. */
private struct Filled<Field: View>: View {
    let label: String
    @ViewBuilder let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.s1) {
            Text(label).type(Tokens.Typography.caption).foregroundStyle(Tokens.Colors.fg2.color)
            field.type(Tokens.Typography.machine)
        }
        .padding(.horizontal, Tokens.Spacing.s4)
        .padding(.vertical, Tokens.Spacing.s2)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Tokens.Radius.md).fill(Tokens.Colors.surface2.color))
    }
}

/** A quieter way: underlined text. */
private struct LinkButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text).underline().type(Tokens.Typography.small).foregroundStyle(Tokens.Colors.fg2.color)
        }
        .frame(minHeight: Tokens.Sizes.tap)
    }
}

/** The step's picture: a symbol on a rounded tile. */
private struct Tile: View {
    let symbol: String

    var body: some View {
        RoundedRectangle(cornerRadius: Tokens.Radius.xl)
            .fill(Tokens.Colors.surface.color)
            .frame(height: 200)
            .overlay {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Tokens.Colors.surface2.color)
                    .frame(width: 120, height: 120)
                    .overlay { Image(systemName: symbol).font(.system(size: 52)) }
            }
            .padding(.horizontal, Tokens.Spacing.s3)
            .accessibilityHidden(true)
    }
}

private struct SignInStep: View {
    let store: Store
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var selfHosted = false
    @State private var server = ""
    @State private var token = ""

    var body: some View {
        Step {
            Lockup()
                .padding(.leading, Tokens.Spacing.s6)
                .padding(.top, 120)
            if selfHosted {
                VStack(spacing: Tokens.Spacing.s3) {
                    Filled(label: "Server") {
                        TextField("Server", text: $server, prompt: Text("https://starbridge.example.com"))
                            .keyboardType(.URL)
                            .textContentType(.URL)
                    }
                    Filled(label: "Owner token") { SecureField("Owner token", text: $token) }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, Tokens.Spacing.s4)
                .padding(.top, Tokens.Spacing.s8)
            }
        } bottom: {
            if !selfHosted {
                Button { gitHub(Store.defaultServer) } label: { Label { Text("Sign in with GitHub") } icon: { Image("GitHub").resizable().frame(width: 20, height: 20) } }
                    .buttonStyle(Primary(busy: store.busy))
                    .disabled(store.busy)
                LinkButton(text: "Use your own server") {
                    selfHosted = true
                    if server.isEmpty { server = store.saved.server == Store.defaultServer ? "" : store.saved.server }
                }
            } else {
                Button("Sign in") { Task { await store.signInWithOwnerToken(server: server, token: token) } }
                    .buttonStyle(Primary(busy: store.busy))
                    .disabled(store.busy || server.isEmpty || token.isEmpty)
                Button("Sign in with GitHub on this server") { gitHub(server) }
                    .buttonStyle(Secondary())
                    .disabled(store.busy || server.isEmpty)
                LinkButton(text: "Use starbridge.run") { selfHosted = false }
            }
        }
    }

    /**
     * Opens GitHub's sign-in in the browser sheet, which shares Safari's GitHub sign-in, and
     * ends when the server hands the code on to starbridge://auth.
     */
    private func gitHub(_ server: String) {
        guard let url = store.gitHubSignInURL(server: server) else {
            store.notice = "That server address is not a URL."
            return
        }
        Task {
            do {
                let link = try await webAuthenticationSession.authenticate(using: url, callbackURLScheme: "starbridge", preferredBrowserSession: .shared)
                await store.receiveSignIn(link)
            } catch {
                store.abandonSignIn()
                if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin { store.notice = store.describe(error) }
            }
        }
    }
}

/** The account has devices: this iPhone scans one's QR code, or compares digits with it. */
private struct JoinStep: View {
    let store: Store
    @State private var scanning = false

    var body: some View {
        Step {
            Title(text: "Add this iPhone")
            Tile(symbol: "qrcode")
        } bottom: {
            Button {
                if QRScanner.available { scanning = true } else { store.notice = "This iPhone can't scan here. Compare digits instead." }
            } label: {
                Label("Scan a QR code", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(Primary(busy: store.busy))
            .disabled(store.busy)
            LinkButton(text: "Can't scan? Compare digits") { Task { await store.askDevices() } }
            LinkButton(text: "Sign out") { Task { await store.signOut() } }
        }
        .sheet(isPresented: $scanning) {
            QRScanner { text in
                scanning = false
                Task { await store.joinWithCode(text) }
            }
            .ignoresSafeArea()
        }
    }
}

/** Signed in to an account with no device yet; the first one is set up on the web or Android. */
private struct NoDeviceStep: View {
    let store: Store

    var body: some View {
        Step {
            Title(text: "Set up your first device")
            Lede(text: "This account has no devices yet. Set it up on the web or in the Android app, then add this iPhone from there.")
        } bottom: {
            Button("Check again") { Task { await store.checkAccount() } }
                .buttonStyle(Primary(busy: store.busy))
                .disabled(store.busy)
            LinkButton(text: "Sign out") { Task { await store.signOut() } }
        }
    }
}

/** Waiting for another device to approve this one, with the digits to compare when there are some. */
private struct WaitingStep: View {
    let store: Store
    let title: String
    let text: String
    let digits: String?
    var onMatch: (() -> Void)?

    var body: some View {
        Step {
            Title(text: title)
            Lede(text: text)
            if let digits {
                Text(Joins.formatDigits(digits))
                    .font(.system(size: 40, weight: .semibold).monospacedDigit())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Spacing.s10)
                    .background(RoundedRectangle(cornerRadius: Tokens.Radius.xl).fill(Tokens.Colors.surface.color))
                    .padding(.horizontal, Tokens.Spacing.s3)
                    .padding(.top, Tokens.Spacing.s6)
                    .accessibilityLabel(digits.map(String.init).joined(separator: " "))
            }
            if onMatch == nil {
                HStack(spacing: Tokens.Spacing.s3) {
                    ProgressView()
                    Text("Waiting for the approval").type(Tokens.Typography.body).foregroundStyle(Tokens.Colors.fg2.color)
                }
                .padding(Tokens.Spacing.s4)
            }
        } bottom: {
            if let onMatch { Button("They match", action: onMatch).buttonStyle(Primary()) }
            Button("Cancel") { Task { await store.cancelJoin() } }.buttonStyle(Secondary())
        }
    }
}

/** Joined. The inbox takes this screen's place in the next step of the iOS plan. */
private struct ReadyStep: View {
    let store: Store

    var body: some View {
        Step {
            Title(text: "This iPhone is in your account")
            Lede(text: "It joined as \(store.me?.name ?? "iPhone").")
        } bottom: {
            LinkButton(text: "Sign out") { Task { await store.signOut() } }
        }
    }
}
