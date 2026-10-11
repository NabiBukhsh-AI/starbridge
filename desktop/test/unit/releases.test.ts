import { expect, test } from "bun:test";
import { feedTags, pickRelease } from "../../src/releases";

// Newest first, as GitHub's feed lists them: an rc after the latest final, that final's rc, a
// withdrawn final.
const TAGS = ["v0.2.0-rc.1", "v0.1.4", "v0.1.4-rc.3", "v0.1.3"];

test("an app follows finals, or rcs and finals, and never a withdrawn final", () => {
  expect(pickRelease("v0.1.4", TAGS, false)).toBe("v0.1.4");
  expect(pickRelease("v0.1.4", TAGS, true)).toBe("v0.2.0-rc.1");
  expect(pickRelease("v0.1.2", TAGS.slice(2), true)).toBe("v0.1.4-rc.3");
  expect(pickRelease("v0.1.4", ["v0.1.4-rc.9"], true)).toBe("v0.1.4");
  expect(pickRelease(null, [], false)).toBeNull();
});

test("the feed's tags are its release links", () => {
  const atom = `<entry><link rel="alternate" type="text/html" href="https://github.com/T0mSIlver/starbridge/releases/tag/v0.1.4-rc.3"/></entry>`;
  expect(feedTags(atom)).toEqual(["v0.1.4-rc.3"]);
});
