# Agent instructions

The Starbridge plugin gives every Claude Code session two rules. The agent
reaches you through Starbridge for decisions that are yours and for work that
waits on you. It also wraps commands that take over your machine in
`starbridge run`. Anything else you want to hear about goes in your harness's
instruction files, in your words. Starbridge never writes to them.

<a id="what-each-agent-supports"></a>

## What each harness supports

A harness is the tool the agent runs in: Claude Code, Codex, Pi, opencode, Cursor or Antigravity.

| | Claude Code | Codex | Pi | opencode | Cursor | Antigravity |
|---|---|---|---|---|---|---|
| Questions | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Answers into the live session¹ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| "Waiting for you" | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Runs | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Permission prompts² | Opt-in | Opt-in | Opt-in | Opt-in | No | Opt-in |
| The harness's own ask tool³ | ✓ | ✓ | ✓ | ✓ | No | ✓ |

¹ An answer arrives as the session's next prompt. A headless run (`claude -p`, `codex exec`,
`pi -p`, `opencode run`, `cursor-agent -p`, `agy -p`) has no next prompt, so there the agent
waits for the answer with `starbridge wait` before it ends its turn.

² Off until you run `starbridge config permissions on`. Your devices can then allow a call once
or deny it.

³ The question shows in the harness and on your devices at once. The first answer wins and closes
the other.

### Claude Code

Needs Claude Code 2.1.287 or later. The Starbridge mod, which runs inside Claude Code, submits
each answer as the session's next prompt, in the terminal, the desktop app, IDEs and Remote
Control. Agent SDK scripts wait, as `claude -p` does.

A permission prompt shows at the keyboard and on your devices at once, and the first answer wins.
Besides allowing once, your devices offer "this session" or "always" when Claude Code does.
`AskUserQuestion` asks in Claude Code's picker and on your devices at once.

### Codex

Needs Codex CLI 0.160 or later. Codex asks you once, at its next launch after setup, to trust the
Starbridge plugin's hooks; until you do, sessions start without the rules.

Codex asks the Starbridge hook before it opens its own permission prompt, so a prompt is never
open in both places. With `starbridge config presence on`, a prompt goes to the terminal while
you are at this machine and to your devices while you are away. Without presence, or on a machine
with no screen, it waits up to 10 minutes for your devices, then Codex asks in the terminal.

Codex's own question tool, which it offers only in Plan mode, also asks on your devices, except on
Windows. A typed reply reaches Codex as a note.

Codex runs commands in a sandbox with no network, so it asks you once at the keyboard to run
`starbridge run` outside it.

### Pi

The Starbridge Pi package puts each answer into the TUI or RPC session.

Permission prompts need
[pi-permission-system](https://github.com/gotgenes/pi-packages/tree/main/packages/pi-permission-system)
(`pi install npm:@gotgenes/pi-permission-system`); `starbridge config permissions on` then offers
to add Starbridge to it. Prompts from tool rules, such as `read` or `bash`, reach your devices.
Prompts from `path` and `external_directory` rules stay at the keyboard, since
pi-permission-system lets no authorizer allow those. While your devices hold a prompt, "Answer
here" in Pi takes it back.

Pi has no ask tool of its own. If you add `ask_user_question` from
@juicesharp/rpiv-ask-user-question, its questions reach your devices too.

### opencode

The Starbridge opencode plugin puts each answer into the TUI or `opencode serve` session.

A permission prompt stays open at the keyboard while it reaches your devices, and the first answer
wins. `opencode run` rejects every prompt itself, so none reaches your devices.

Each question of opencode's `question` tool reaches your devices, its options as one-tap answers.
A question with more than 4 options takes a typed reply; to pick several where the agent allows
it, reply with their names.

### Cursor

In `cursor-agent`, when a chat ends its turn with a question open, Cursor holds the chat, shown as
busy, for up to 10 minutes; your answer comes in as the next prompt. Past 10 minutes, and in the
Cursor IDE, which doesn't tell a command which chat runs it, the agent waits with `starbridge wait`.
The IDE is untested.

Cursor's permission prompts stay at the keyboard. Cursor shows its own prompt even after a hook
allows the call, so an Allow from your phone could not take effect. Cursor's `askQuestion` runs no hooks either, so the rules
tell the agent to use `starbridge ask` instead.

### Antigravity

Answers and prompts go through the conversation's language server, which only a command the
agent runs can reach. So with permission prompts on, the plugin has each new conversation run
`starbridge hello` first. A permission prompt or `ask_question` stays open at the keyboard while it
reaches your devices, and the first answer wins.

Checked with `agy`; the Antigravity app and IDE are untested.

## What setup installs

`starbridge setup` installs Starbridge in each harness it finds, and prints one
line per harness; `starbridge uninstall --agent <name>` removes it from one, and
setup then leaves that harness alone until `starbridge setup --agent <name>`:

- Claude Code: the Starbridge plugin, which brings the rules above, the skill
  and the hooks, and allow rules so that `starbridge ask`, `waiting`,
  `working`, `wait` and `settle` run without a permission prompt. Beside it,
  the Starbridge mod, a [Claude Code mod](https://code.claude.com/docs/en/plugins/mods/overview) (code that runs
  inside Claude Code, 2.1.287 or later), submits each answer into the live
  session as its next prompt, in the terminal, the desktop app and Remote
  Control.
- Codex: the skill, in `~/.codex/skills/starbridge` (or under `$CODEX_HOME`),
  so it knows how to write a question, and the Starbridge Codex plugin, whose
  hooks bring the rules above and send permission prompts once you turn them on. Codex installs plugins from a
  marketplace, so setup writes a local one in `~/.codex/starbridge` and installs
  the plugin from it. Codex asks once, at its next launch, to trust the hooks
  ("Hooks need review"); until you trust them, sessions start without the rules,
  and `codex exec` skips them without a word. A later setup updates
  the skill and the rules when the CLI carries newer ones. Codex runs commands in a sandbox with no network, so setup also writes
  `~/.codex/rules/starbridge.rules`, which runs `starbridge ask`, `waiting`,
  `working`, `wait` and `settle` outside it.
- Pi: the Starbridge Pi package (`pi install
  git:github.com/T0mSIlver/starbridge@v<version>`, at your CLI's version), which brings the skill, the rules and
  the extension that puts each answer into the session. With
  pi-permission-system, setup adds, and `starbridge config permissions on` offers,
  allow rules, so that Pi loads the `starbridge` skill and reads the files in its
  folder without a prompt, and the Starbridge link in its `authorizerChain`, which
  runs `starbridge ask`, `waiting`, `working`, `wait` and `settle` without one
  when the command is only that. Other reads and commands still ask.
- opencode: the skill, in `~/.config/opencode/skills/starbridge`, and the
  Starbridge plugin, in `~/.config/opencode/plugins/starbridge.ts` with its code
  in `~/.config/opencode/starbridge/`. The plugin brings the rules, puts each
  answer into the session and sends permission prompts. A later setup, or the
  local agent once `starbridge update` restarts it, updates both when the CLI carries
  newer ones.
- Cursor: the skill, in `~/.cursor/skills/starbridge`, and hooks that bring the
  rules and put each answer into the chat: their scripts in `~/.cursor/starbridge`,
  their entries added to your `~/.cursor/hooks.json` beside your own. A chat
  started after setup has them. Setup also adds allow rules to
  `cursor-agent`'s `~/.cursor/cli-config.json`, so that `starbridge ask`,
  `waiting`, `working`, `wait` and `settle` run without a prompt there.
- Antigravity (the app, the IDE and `agy`): the Starbridge plugin, in
  `~/.gemini/config/plugins/starbridge`, which all three load. It brings the
  rules and the skill. For `agy`, setup also adds allow entries to
  `~/.gemini/antigravity-cli/settings.json` so that `starbridge ask`, `waiting`,
  `working`, `wait`, `settle` and `hello` run without a permission prompt, and outside
  `--sandbox`, when the command is only that; the plugin's hook makes any other
  line that runs them ask. In the app and the IDE they still ask the first time.
  A later setup updates the plugin when the CLI carries a newer one.

## Where the lines go

Put your lines in a file only you use. A repo's `AGENTS.md` or `CLAUDE.md` is
committed, so lines there apply to everyone who works on the repo.

<dl>
<dt>Claude Code</dt>
<dd>Every repo: <code>~/.claude/CLAUDE.md</code>. One repo: <code>CLAUDE.local.md</code>.</dd>
<dt>Codex</dt>
<dd>Every repo: <code>~/.codex/AGENTS.md</code>. One repo: <code>AGENTS.override.md</code>.</dd>
<dt>Pi</dt>
<dd>Every repo: <code>~/.pi/agent/AGENTS.md</code>. One repo: <code>AGENTS.override.md</code>.</dd>
<dt>opencode</dt>
<dd>Every repo: <code>~/.config/opencode/AGENTS.md</code>. One repo: a file you name in <code>instructions</code> in <code>.opencode/opencode.json</code>, such as <code>["AGENTS.local.md"]</code>.</dd>
<dt>Antigravity</dt>
<dd>Every repo: <code>~/.gemini/GEMINI.md</code>. One repo: a file in <code>.agents/rules/</code>, such as <code>.agents/rules/local.md</code>.</dd>
</dl>

The one-repo files go at the repo root. Add the file's name to
`.git/info/exclude` to keep it out of git, and for opencode `.opencode/opencode.json`
too. Antigravity's go in `.agents/rules/`: exclude the file you add.

Claude Code reads `CLAUDE.local.md` in addition to the repo's `CLAUDE.md`.
`AGENTS.override.md` replaces the repo's `AGENTS.md` instead, so in a repo that
has an `AGENTS.md`, put your lines in the every-repo file.

Checked on 2026-10-05 with Claude Code 2.1.289, Codex CLI 0.160.0 and Pi
0.87.1, and on 2026-10-06 with opencode 1.18.31.

## Rules for Codex

Setup used to have you paste the rules into `~/.codex/AGENTS.md`, since Codex had no plugins.
The Starbridge Codex plugin now brings them: once `starbridge status` says `Codex plugin:
installed` and you have trusted its hook, remove the pasted rules, or Codex reads them twice.

## Lines to copy

Paste the lines you want and edit them to fit.

```
Ask me through Starbridge before you deploy.
Ask me through Starbridge (`starbridge ask`) before you merge a pull request.
Ask me through Starbridge before you force-push or delete data.
When CI fails and the fix is not obvious, ask me through Starbridge what to do.
When a long task is done, ask me through Starbridge which next step to take.
Run the e2e tests that take over my Mac through `starbridge run`.
Tell me through `starbridge run` when you run local inference.
```
