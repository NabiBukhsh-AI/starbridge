import { expect, test } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { readSettings } from "../../src/settings";

function read(saved: object) {
  const file = join(mkdtempSync(join(tmpdir(), "sb-settings-")), "settings.json");
  writeFileSync(file, JSON.stringify(saved));
  return readSettings(file);
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

test("the window keeps only a #rrggbb background from the page", () => {
  expect(read({ background: "#F4F4F4" }).background).toBe("#f4f4f4");
  expect(read({ background: "red; x" }).background).toBeUndefined();
});
