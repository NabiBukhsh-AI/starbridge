# Starbridge spec

What Starbridge does and why, one file per area under `spec/`. Each rule names the issue where it
was decided, which holds the discussion. `PROTOCOL.md` has the wire format and `DESIGN.md` the
look; the spec covers what they don't. Read the files your change touches, not all of them.

A change that makes or changes a decision edits its area's file: the rule, why in a clause, and
the issue. It replaces what it supersedes, and says once what platforms share, in `clients.md`,
with each platform's file saying only what differs. A file past about 4,000 words splits by
topic.

| File | Decides |
|---|---|
| [product.md](spec/product.md) | What Starbridge is, its principles, positioning, the platforms it runs on, the brand |
| [architecture.md](spec/architecture.md) | The pieces, the stack and why, how CodexBar is read |
| [keys-and-trust.md](spec/keys-and-trust.md) | Members, signing and sealing, the directory, pairing, the recovery key, revocation, key storage per client, format versions |
| [sign-in.md](spec/sign-in.md) | GitHub sign-in, self-hosting, sessions |
| [server.md](spec/server.md) | Bounds, retention, sizes, long-polls, re-sealing, migrations, caps and usage counts |
| [push.md](spec/push.md) | Push to phones and browsers, the relay, held pushes, the hand-off to the desktop app |
| [machines.md](spec/machines.md) | The local agent, its files and socket, Windows, presence, answers on the machine, pairing a machine, setup, install and update |
| [harnesses.md](spec/harnesses.md) | How an answer reaches each harness's session, the skill and rule, each harness's own ask tool, permission prompts per harness |
| [items.md](spec/items.md) | Questions, permission prompts, runs and quotas: what each carries, how it settles, quota alerts and order |
| [clients.md](spec/clients.md) | What every client does: inbox order, cards, answers, drafts, history, find, settings, devices |
| [web.md](spec/web.md) | What only the web page does: headers, shortcuts, polling, layout checks |
| [android.md](spec/android.md) | What only Android does: channels, notifications, snooze, haptics, widgets, the update screen |
| [desktop.md](spec/desktop.md) | What only the desktop app does: the bridge, the menu bar, the window, its widget, pairing links |
| [parity.md](spec/parity.md) | Which client has each feature: web, Android, desktop and iOS |
| [releases.md](spec/releases.md) | Releases and release candidates, Play, release notes, versions, deploys, CI, monitoring |
| [hosted.md](spec/hosted.md) | starbridge.run: stack, limits, capacity, abuse handling, privacy, analytics, the demo server |
| [platform-facts.md](spec/platform-facts.md) | What the code relies on in each harness, CodexBar, browsers and Android, with the versions checked |

## Open questions

- Should cloud sessions get a machine? The agent can read its key from the environment.
- Android App Links on starbridge.run, on top of PKCE, would close the hostile-app sign-in gap for
  the hosted domain (#34).
- Does Safari on iOS lose X25519 keys as WebKit does (#116)?
- Tap targets under 44 px and contrast under 3:1 are listed by the layout checks, not failed,
  until a ruling (#305).
- An offline banner on the web (#332).
- Revoking the old machine in a `pair --force` approval would need a `replaces` field (#287).
