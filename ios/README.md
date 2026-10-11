# Starbridge for iPhone

The native iPhone app: SwiftUI on [`StarbridgeProtocol`](StarbridgeProtocol), the Swift port of
`packages/protocol`. So far it signs in and joins the account; the inbox comes next (the plan is
in the planning repo's `research/ios-app.md`).

- **Sign-in** goes through the browser with PKCE, as on Android (PROTOCOL.md, "Auth"):
  `ASWebAuthenticationSession` opens `/v1/auth/github?app=1&challenge=…` and ends on
  `starbridge://auth`, where the app trades GitHub's code and its verifier for the session.
  Self-hosted servers also take the owner token.
- **Joining** follows Android: scan the QR code that a device already in the account shows, or
  compare digits with it (PROTOCOL.md, "Joining by digits").
- **Keys** and the session are one keychain item, readable after the first unlock and never
  copied to another device; the rest of the state is a file in Application Support.
- **Design tokens** are `Starbridge/Theme/Tokens.swift`, written from DESIGN.md by
  `bun web/scripts/tokens.ts`; type is SF Pro, scaled with Dynamic Type.

## Build and test

On a Mac with Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen), which
writes `Starbridge.xcodeproj` from `project.yml` (edit the YAML, not the project):

```bash
xcodegen generate
```

```bash
xcodebuild -project Starbridge.xcodeproj -scheme Starbridge -destination "platform=iOS Simulator,name=iPhone 16" test
```

`JoinTests` joins an account on a real server, playing the device that approves. It runs when the
test process gets a self-hosted server with no device yet, started from the repository root with
`PORT=18731 DB_PATH=/tmp/sb.db OWNER_TOKEN=test bun run server/src/main.ts`:

```bash
TEST_RUNNER_STARBRIDGE_TEST_SERVER=http://localhost:18731 TEST_RUNNER_STARBRIDGE_TEST_OWNER_TOKEN=test xcodebuild -project Starbridge.xcodeproj -scheme Starbridge -destination "platform=iOS Simulator,name=iPhone 16" test
```

CI runs both, with the server, in `.github/workflows/ios.yml`. Builds are for the simulator until
signing lands with the TestFlight upload.
