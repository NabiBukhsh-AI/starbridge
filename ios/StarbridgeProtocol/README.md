# StarbridgeProtocol

`packages/protocol` in Swift, for the iPhone app: signing and sealing, the directory chain and its
heads, pairing and joining by digits, the recovery key, decision images, the context subset,
the item schemas, and quota pace and alerts. It is ported by hand, as Android's `protocol/` is,
and passes every file in `packages/protocol/vectors` byte for byte. `ProtocolVectorsTests` fails
when a vector file appears that it does not read, so a new file needs a test here as well.

The cryptography is libsodium, through [swift-sodium](https://github.com/jedisct1/swift-sodium)'s
`Clibsodium`: the bundled framework on Apple platforms, the system library on Linux. This package
only frames the calls, as the TypeScript does:

- Secret keys live in `SecretKey`, memory the package allocates and wipes when the last reference
  goes; keys derived inside it (the join's MAC key, the pairing key, the recovery signing key)
  never pass through a Swift array.
- MACs are checked with `crypto_auth_verify`, and hashes and commitments with `sodium_memcmp`.
- Nonces are libsodium's: a sealed box makes an ephemeral key per box, and an image blob draws a
  random nonce and key per seal.

Bodies are read and written through `JSON`, which parses as `JSON.parse` and writes as
`JSON.stringify` (key order kept, numbers and escapes as JavaScript writes them), so a body this
package signs is the text the TypeScript would sign. The schemas check what zod checks; lengths
count code points and times follow zod's `iso.datetime({ offset: true })`.

One difference remains: a Swift `String` cannot hold a lone UTF-16 surrogate, which a JavaScript
string can, so a `\ud800` escape reads here as U+FFFD. A decision option holding one shows
changed, and an answer naming it would not match the machine's option.

## Test

On a Mac with Xcode, or on Linux with Swift 6 and `libsodium-dev`:

```bash
swift test
```

The tests read the vectors from `../../packages/protocol/vectors`, so run them in a checkout of
the whole repository. CI runs them on macOS and Linux, and builds the package for iOS
(`.github/workflows/ios.yml`).
