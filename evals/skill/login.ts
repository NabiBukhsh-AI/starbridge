/**
 * The logins the eval runs on, none of which refreshes: for Claude, a long-lived token from
 * `claude setup-token` (CLAUDE_CODE_OAUTH_TOKEN or `~/.config/starbridge/secrets/claude-eval-token`);
 * for Codex, an OpenAI API key (OPENAI_API_KEY or `.../secrets/codex-eval-key`); for Antigravity,
 * a Gemini API key (GEMINI_API_KEY or `.../secrets/gemini-eval-key`); for Cursor, an API key
 * (CURSOR_API_KEY or `.../secrets/cursor-eval-key`), else a login of its own in
 * `.../secrets/cursor-eval-home`, which the runs share rather than copy. Copies of
 * `~/.claude/.credentials.json` or `~/.codex/auth.json` would each refresh on their own, and a
 * rotated refresh token signs the original out.
 */
import { existsSync, readFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";

const secrets = join(homedir(), ".config/starbridge/secrets");

function secret(env: string, name: string, how: string): string {
  const file = join(secrets, name);
  const value = process.env[env] ?? (existsSync(file) ? readFileSync(file, "utf8").trim() : "");
  if (!value) throw new Error(`no ${env}: ${how} and save it in ${file}`);
  return value;
}

export const claudeToken = () =>
  secret("CLAUDE_CODE_OAUTH_TOKEN", "claude-eval-token", "run `claude setup-token`");

export const codexKey = () =>
  secret("OPENAI_API_KEY", "codex-eval-key", "create an OpenAI API key");

export const geminiKey = () =>
  secret("GEMINI_API_KEY", "gemini-eval-key", "create a Gemini API key at aistudio.google.com/apikey");

/**
 * Cursor's login: an API key, else the folder of a login made for the eval alone with
 * `env -i PATH=$PATH HOME=<dir> XDG_CONFIG_HOME=<dir>/.config cursor-agent login`. That login
 * refreshes in place, so the runs read it from there, one at a time, never from copies.
 */
export function cursorLogin(): { CURSOR_API_KEY: string } | { CURSOR_CONFIG_DIR: string } {
  const dir = join(secrets, "cursor-eval-home/.config/cursor");
  if (!process.env.CURSOR_API_KEY && existsSync(join(dir, "auth.json"))) return { CURSOR_CONFIG_DIR: dir };
  return {
    CURSOR_API_KEY: secret(
      "CURSOR_API_KEY",
      "cursor-eval-key",
      `create a Cursor API key, or log in to ${dir} as login.ts says,`,
    ),
  };
}

/** A `claude -p` under the home folder would read an ancestor's CLAUDE.md. */
export function tmpOutsideHome(): string {
  if (`${tmpdir()}/`.startsWith(`${homedir()}/`)) throw new Error("TMPDIR must be outside your home");
  return tmpdir();
}
