import { expect, test } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { readSettings } from "../../src/settings";

function read(saved: object, version?: string) {
  const file = join(mkdtempSync(join(tmpdir(), "sb-settings-")), "settings.json");
  writeFileSync(file, JSON.stringify(saved));
  return readSettings(file, version);
}

test("the app stays in the menu bar unless set otherwise", () => {
  expect(read({}).place).toBe("menu");
  expect(read({ place: "dock" }).place).toBe("dock");
  expect(read({ place: "taskbar" }).place).toBe("menu");
});

test("an app that already notified is not asked about notifications again", () => {
  expect(read({}).notificationsAsked).toBe(false);
  expect(read({ notified: ["q_1"] }).notificationsAsked).toBe(true);
  expect(read({ notified: ["q_1"], notificationsAsked: false }).notificationsAsked).toBe(false);
});

test("an app installed from a release candidate follows them until the owner says otherwise", () => {
  expect(read({}, "1.2.0").releaseCandidates).toBe(false);
  expect(read({}, "1.2.0-rc.3").releaseCandidates).toBe(true);
  expect(read({ releaseCandidates: false }, "1.2.0-rc.3").releaseCandidates).toBe(false);
});
