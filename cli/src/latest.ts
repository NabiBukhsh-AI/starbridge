/**
 * Saying a new release is out (#1050). The local agent reads GitHub's latest release at most
 * once a day and keeps it in `latest.json`; commands a person runs print one line on stderr when
 * it is newer than this binary. Nothing updates by itself: `starbridge update` does.
 */
import type { LatestRelease } from "./config";
import type { Ctx } from "./context";
import { compareVersions, type InstallKind } from "./release";
import { MANAGED } from "./update";
import { VERSION } from "./version";

/** GitHub's latest release that is neither a draft nor a pre-release. */
export const LATEST_URL = "https://api.github.com/repos/T0mSIlver/starbridge/releases/latest";

export const CHECK_EVERY_MS = 24 * 3_600_000;

/** Off with `starbridge config update-check off`, or `STARBRIDGE_NO_UPDATE_CHECK=1` where it runs. */
export function updateCheckOn(ctx: Ctx): boolean {
  const env = ctx.env.STARBRIDGE_NO_UPDATE_CHECK;
  if (env && env !== "0") return false;
  return ctx.store.agentConfig().updateCheck?.enabled !== false;
}

/**
 * Reads the latest release unless it was read in the last day, and saves it. Any failure leaves
 * `latest.json` as it was, so the next call tries again; it never throws.
 */
export async function checkLatest(ctx: Ctx, now = ctx.now()): Promise<LatestRelease | undefined> {
  const saved = ctx.store.latest();
  if (saved && now.getTime() - Date.parse(saved.checkedAt) < CHECK_EVERY_MS) return saved;
  try {
    const res = await fetch(ctx.env.STARBRIDGE_LATEST_URL ?? LATEST_URL, {
      headers: {
        accept: "application/vnd.github+json",
        "user-agent": `starbridge/${VERSION}`,
        ...(saved?.etag ? { "if-none-match": saved.etag } : {}),
      },
      signal: AbortSignal.timeout(10_000),
    });
    let next: LatestRelease | undefined;
    if (res.status === 304 && saved) next = { ...saved, checkedAt: now.toISOString() };
    else if (res.ok) {
      const tag = ((await res.json()) as { tag_name?: unknown }).tag_name;
      const version = typeof tag === "string" ? tag.replace(/^v/, "") : "";
      compareVersions(version, "0.0.0");
      const etag = res.headers.get("etag");
      next = { checkedAt: now.toISOString(), version, ...(etag ? { etag } : {}) };
    }
    if (!next) return saved;
    ctx.store.saveLatest(next);
    return next;
  } catch {
    return saved;
  }
}

/** The latest release when it is newer than this binary, from the agent's last read. */
export function newerRelease(ctx: Ctx): string | undefined {
  try {
    const latest = ctx.store.latest()?.version;
    return latest && compareVersions(latest, VERSION) > 0 ? latest : undefined;
  } catch {
    return undefined;
  }
}

/** How this install updates: brew and npm through their manager, as `update` says. */
export function updateCommand(install: InstallKind): string {
  return install.kind === "binary" ? "`starbridge update`" : MANAGED[install.kind].update;
}

/** The line a command a person ran ends with when a newer release is out, else undefined. */
export function updateLine(ctx: Ctx, install: () => InstallKind): string | undefined {
  if (!updateCheckOn(ctx)) return undefined;
  const latest = newerRelease(ctx);
  if (!latest) return undefined;
  return `Starbridge ${latest} is out (you have ${VERSION}): run ${updateCommand(install())}`;
}
