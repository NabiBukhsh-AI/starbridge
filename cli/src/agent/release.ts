/**
 * The agent's update check (#1050): every hour it reads GitHub's latest release when the last
 * read is a day old, and tells the server which release this machine runs and the latest it
 * knows, whenever either changed since the server last took it, so devices show "Update
 * available". Every failure is silent and tried again an hour later.
 */
import type { MachineRelease } from "@starbridge/protocol";
import { session } from "../context";
import { checkLatest, updateCheckOn } from "../latest";
import { VERSION } from "../version";
import { type Feature, type Hub, pause } from "./server";

export const TICK_MS = 3_600_000;

export class Release implements Feature {
  /** What the server last took from this machine. */
  private sent: string | undefined;

  constructor(private readonly hub: Hub) {}

  async tick(): Promise<void> {
    const ctx = this.hub.ctx;
    const on = updateCheckOn(ctx);
    const latest = on ? ((await checkLatest(ctx))?.version ?? null) : null;
    if (!ctx.store.machine()) return;
    const body: MachineRelease = { version: VERSION, latest };
    const key = JSON.stringify(body);
    if (key === this.sent) return;
    try {
      await session(ctx).api.release(body, AbortSignal.timeout(10_000));
      this.sent = key;
    } catch {}
  }

  async run(signal: AbortSignal): Promise<void> {
    while (!signal.aborted) {
      await this.tick();
      await pause(TICK_MS, signal);
    }
  }
}
