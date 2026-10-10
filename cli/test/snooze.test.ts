import { afterEach, expect, setSystemTime, test } from "bun:test";
import { snoozeLine } from "../src/decisions";

const zone = process.env.TZ;
afterEach(() => {
  if (zone === undefined) delete process.env.TZ;
  else process.env.TZ = zone;
  setSystemTime();
});

// What the e2e's snooze step reads near local midnight (#994): a snooze 3 minutes out says when it
// ends today, or tomorrow once it crosses midnight, whatever the machine's zone.
test.each(["Europe/Paris", "Pacific/Kiritimati"])("a snooze near midnight in %s", (tz) => {
  process.env.TZ = tz;
  for (const [h, m, said] of [
    [23, 50, "23:53"],
    [23, 57, "tomorrow 00:00"],
    [23, 58, "tomorrow 00:01"],
    [0, 30, "00:33"],
  ] as const) {
    setSystemTime(new Date(2026, 9, 9, h, m));
    const until = new Date(Date.now() + 3 * 60_000).toISOString();
    expect(snoozeLine("d_1", "Ship the docs?", until, new Date())).toBe(
      `Snoozed d_1 (Ship the docs?) until ${said}: no answer before then.`,
    );
  }
});
