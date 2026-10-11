import type { Database } from "bun:sqlite";
import { Hono } from "hono";
import { deleteCookie } from "hono/cookie";
import { randomToken, requireCaller, SESSION_COOKIE } from "../auth";
import type { Deps, Env } from "../env";

/**
 * Tables holding an account's rows, children first. The triggers on `items` leave `item_totals`
 * rows at zero, which go after them.
 */
export const ACCOUNT_TABLES = [
  "boxes",
  "items",
  "item_totals",
  "push_subscriptions",
  "joins",
  "pairings",
  "machine_tokens",
  "sessions",
  "members",
  "directory",
] as const;

/**
 * Deletes everything the database holds for `account` (#1104), and returns the ids of what
 * waits on it. Today's usage events keep their count under a random subject, so no row names the
 * account; the sessions go without a `revoked_sessions` row, which would only say why.
 */
export function deleteAccount(
  db: Database,
  account: string,
): { members: string[]; joins: string[]; rendezvous: string[] } | null {
  return db.transaction(() => {
    if (!db.query("SELECT 1 FROM accounts WHERE id = ?").get(account)) return null;
    const ids = (sql: string) => (db.query(sql).all(account) as { id: string }[]).map((r) => r.id);
    const waits = {
      members: ids("SELECT id FROM members WHERE account_id = ?"),
      joins: ids("SELECT id FROM joins WHERE account_id = ?"),
      rendezvous: ids("SELECT rendezvous AS id FROM pairings WHERE account_id = ?"),
    };
    for (const table of ACCOUNT_TABLES)
      db.query(`DELETE FROM ${table} WHERE account_id = ?`).run(account);
    // A subject is the account id, or the account id, a slash and a member id.
    db.query(
      `UPDATE usage_events SET subject = ?2 || substr(subject, length(?1) + 1)
       WHERE subject = ?1 OR substr(subject, 1, length(?1) + 1) = ?1 || '/'`,
    ).run(account, randomToken("gone_"));
    db.query("DELETE FROM accounts WHERE id = ?").run(account);
    return waits;
  })();
}

/** Forgets what memory holds for the account, and ends its waits: each rechecks and gets 401. */
function forgetAccount(
  deps: Deps,
  account: string,
  waits: NonNullable<ReturnType<typeof deleteAccount>>,
) {
  deps.presence.forget(account);
  deps.appSignIns.forget(account);
  deps.usage.forget(account);
  deps.limiter.forget(account);
  deps.quotaAsks.delete(account);
  for (const m of waits.members) deps.answers.wake(`${account}/${m}`);
  deps.quotas.wake(account);
  deps.joins.wake(`account:${account}`);
  for (const j of waits.joins) deps.joins.wake(`join:${j}`);
  for (const r of waits.rendezvous) deps.pairings.wake(r);
}

export const accountRoutes = new Hono<Env>();

/**
 * Deletes the caller's account and signs out every session and machine. Any signed-in session
 * may, paired or not: an app must let whoever signed in delete the account (App Store
 * 5.1.1(v)), and the GitHub sign-in that makes a session already controls the account.
 */
accountRoutes.delete("/account", requireCaller("device"), (c) => {
  const { account } = c.var.caller;
  const waits = deleteAccount(c.var.db, account);
  if (waits) forgetAccount(c.var, account, waits);
  deleteCookie(c, SESSION_COOKIE, { path: "/" });
  return c.body(null, 204);
});
