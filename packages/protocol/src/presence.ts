import { z } from "zod";

/**
 * Presence (#848): whether the owner sits at an unlocked screen they used in the last minute. A
 * machine reads its own lock and idle state, a device its page or app in front and touched; each
 * reduces that to one bit where it is read and sends only the bit. While any source of an
 * account is present, the server holds the pushes of new questions and permission prompts, and
 * once nobody is, for the account's hold time more, then pushes those still open (#1003).
 */

/** Input this recent makes a screen present. */
export const PRESENCE_INPUT_MS = 60_000;
/** A present source says so again this often. */
export const PRESENCE_BEAT_MS = 30_000;
/** The server counts a source present this long after its last beat. */
export const PRESENCE_VALID_MS = 75_000;

/** `PUT /presence`: one bit, from a machine or a device. */
export const Presence = z.object({ present: z.boolean() });
export type Presence = z.infer<typeof Presence>;

/** No hold: every device's push goes at once, as without presence. */
export const PUSH_HOLD_OFF = 0;
/**
 * A hold that ends as soon as the owner leaves the last screen (#1060). Not 0, which stays off for
 * the clients released before it.
 */
export const PUSH_HOLD_ON_LEAVE = -1;
/** The hold choices clients offer: off, or how long after the owner left the last screen. */
export const PUSH_HOLD_CHOICES = [PUSH_HOLD_OFF, PUSH_HOLD_ON_LEAVE, 15, 30, 60] as const;
export const PUSH_HOLD_DEFAULT = 30;
export const PUSH_HOLD_MAX = 300;

/** `GET` and `PUT /settings`: the account's own settings, which the server applies. */
export const AccountSettings = z.object({
  /**
   * Seconds a held push waits once the owner left the last screen: `PUSH_HOLD_OFF` holds nothing,
   * `PUSH_HOLD_ON_LEAVE` none at all.
   */
  pushHold: z.number().int().min(PUSH_HOLD_ON_LEAVE).max(PUSH_HOLD_MAX),
});
export type AccountSettings = z.infer<typeof AccountSettings>;

/** Whether a screen counts as present: unlocked, with input in the last minute. */
export function isPresent(screen: { locked: boolean; idleMs: number }): boolean {
  return !screen.locked && screen.idleMs >= 0 && screen.idleMs < PRESENCE_INPUT_MS;
}
