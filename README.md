# Starbridge

Know the moment your agent is stuck.

When a coding agent stops for a question, Starbridge puts it on your phone and in your browser.
You answer with one tap, and your answer comes back as the session's next prompt. Claude Code,
Codex, Pi, opencode, Cursor and Antigravity sessions on every machine reach you in one place. An
agent also stops when its quota runs out, so Starbridge shows what's left on each AI plan, read
from CodexBar, with an optional alert before a window runs out. CodexBar is optional: setup asks
before installing it, `--no-quota` skips it, and questions, runs and permission prompts work
without it. You also follow the runs that affect you, such as an eval on a rented GPU or a
release, and can answer permission prompts from your phone once you turn them on.

Your phone, browsers and machines encrypt everything they send each other, so the server stores
your content only as ciphertext; it still sees who sent each item, to which
devices, its kind, size and times.
[What the server sees](https://starbridge.run/docs/faq#what-does-the-server-see) has the details
and the limits. Use the free server at [starbridge.run](https://starbridge.run), or host your own.

![Claude Code asks which model to run a paid eval with; the question reaches the phone, one tap answers it, and the session carries on](docs/media/demo.gif)

Launch week: [known issues](https://github.com/T0mSIlver/starbridge/issues?q=is%3Aissue%20label%3Aknown-issue).

## Get the app

- **Android:** the signed APK from [GitHub Releases](https://github.com/T0mSIlver/starbridge/releases),
  or add the repository to [Obtainium](https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/T0mSIlver/starbridge)
  to get each release; with Obtainium's "Include prereleases" on, you also get each release
  candidate. The APK is signed with the same key as the Google Play build, so a Play install later
  updates it in place.
- **macOS:** the desktop app from [GitHub Releases](https://github.com/T0mSIlver/starbridge/releases/latest),
  the `arm64` DMG for Apple silicon or the `x64` one for Intel. It is signed and notarized, adds a
  menu bar light and a notification per question with its options as buttons, and updates itself.
  Check Get Release Candidates in its menu bar icon's menu to also get each release candidate.
- **Google Play:** in closed testing, and looking for testers. Join
  [the group](https://groups.google.com/g/starbridge-testers), then
  [opt in](https://play.google.com/apps/testing/dev.starbridge.app). Testers get each release
  candidate and each release.
- **iOS:** add [starbridge.run](https://starbridge.run) to the Home Screen from Safari to get
  notifications, on iOS 16.4 and later. A native iPhone app is in progress and not released.
- **Any browser:** [starbridge.run](https://starbridge.run).

## Install the CLI

Sign in at [starbridge.run](https://starbridge.run) or in the Android app, then install the CLI
on each machine that runs your harnesses:

```bash
curl -fsSL https://starbridge.run/install.sh | sh
```

On Windows, in PowerShell:

```powershell
irm https://starbridge.run/install.ps1 | iex
```

Or with Homebrew:

```bash
brew install T0mSIlver/starbridge/starbridge
```

Or with npm:

```bash
npm install -g starbridge
```

The script runs `starbridge setup`, which pairs the machine, installs Starbridge in each harness it
finds and ends by offering to send a test question to your devices. After Homebrew or npm, run
`starbridge setup` yourself. [Start](https://starbridge.run/docs#start) goes on to your agent's
first question.
[One notification per question](https://starbridge.run/docs/notifications) turns off your
harnesses' own notifications for what Starbridge already sends.

## What each harness supports

A harness is the tool the agent runs in: Claude Code, Codex, Pi, opencode, Cursor or Antigravity.
A question picker is a harness's own tool for asking you a question with options, such as Claude
Code's `AskUserQuestion`.

| | Claude Code | Codex | Pi | opencode | Cursor | Antigravity |
|---|---|---|---|---|---|---|
| Question picker raced on your devices | ✓ | ✓ | With add-on | ✓ | No | ✓ |
| Answer comes back without polling | ✓ | ✓ | ✓ | ✓ | CLI only | ✓ |
| Permission prompts on your devices | Opt-in | Opt-in | Opt-in | Opt-in | No | Opt-in |
| Runs | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| "Waiting for you" | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

Your answer to a `starbridge ask` question comes back as the session's next prompt. In Claude
Code, the Starbridge mod submits it. A
[Claude Code mod](https://code.claude.com/docs/en/plugins/mods/overview) is code that runs inside
Claude Code; setup installs it beside the Starbridge plugin. A headless run (`claude -p`,
`codex exec`, `pi -p`, `opencode run`, `cursor-agent -p`, `agy -p`) has no next prompt, so there
the agent waits with `starbridge wait` before it ends its turn.

[What each harness supports](https://starbridge.run/docs/tell-your-agents#what-each-harness-supports)
lists the version and setup each one needs.

CI runs the CLI's tests on Linux and macOS, and its platform tests on Windows, on every change
to the CLI.
A release publishes nothing until its APK passes a smoke test on an Android emulator.

## Docs

[starbridge.run/docs](https://starbridge.run/docs): getting started, the CLI, telling your agents
when to reach you, self-hosting, and the [FAQ](https://starbridge.run/docs/faq), with what the
server can and can't see.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Report vulnerabilities privately: [SECURITY.md](SECURITY.md).

## Licence

[MIT](LICENSE)
