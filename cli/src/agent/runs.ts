/**
 * Runs in the agent: `starbridge run` hands it each update of a wrapped command, and the agent
 * seals it to every device and posts it with the machine's keys.
 */

import { RUN_LOST_MS } from "../autoupdate";
import { session } from "../context";
import { postRun, type RunInput } from "../run";
import { type Feature, HttpError, type Hub } from "./server";

export class Runs implements Feature {
  /** Each run's last update through this agent: when, and whether it was the exit. */
  private readonly last = new Map<string, { at: number; exited: boolean }>();

  constructor(private readonly hub: Hub) {}

  /**
   * How many runs are in flight (#1266): not exited, and heard from in the last RUN_LOST_MS,
   * after which devices call a run lost.
   */
  inFlight(): number {
    const now = this.hub.ctx.now().getTime();
    let n = 0;
    for (const [id, r] of this.last) {
      if (r.exited || r.at < now - RUN_LOST_MS) this.last.delete(id);
      else n++;
    }
    return n;
  }

  routes = [
    {
      method: "POST",
      path: "/v1/runs",
      handle: async (req: { body: unknown }) => {
        const run = (req.body as { run?: unknown } | undefined)?.run;
        if (typeof run !== "object" || run === null)
          throw new HttpError(400, "bad-request", "post {run: {id, title, reason, ...}}");
        const input = run as RunInput;
        // Counted before the post: a run whose updates the server refuses still runs here.
        if (typeof input.id === "string")
          this.last.set(input.id, { at: this.hub.ctx.now().getTime(), exited: !!input.exit });
        const posted = await postRun(this.hub.ctx, session(this.hub.ctx), input);
        return { id: posted.id };
      },
    },
  ];
}
