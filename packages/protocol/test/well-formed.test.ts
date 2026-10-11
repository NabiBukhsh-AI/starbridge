import { beforeAll, expect, test } from "bun:test";
import { generateMemberKeys, ready, sign, toWellFormed } from "../src";

beforeAll(() => ready);

// Readers refuse a lone surrogate (vectors: schemas.json `text`), so signers must too (#1090).
test("sign refuses a lone surrogate, toWellFormed replaces it", () => {
  const body = { op: "add", member: { name: "Tom's \ud83d phone" } };
  const key = generateMemberKeys().sign.privateKey;
  expect(() => sign("directory", body as never, "phone", key)).toThrow("bad-schema");
  const fixed = toWellFormed(body);
  expect(fixed.member.name).toBe("Tom's � phone");
  expect(toWellFormed<object>({ "\udc00": ["🚀"] })).toEqual({ "�": ["🚀"] });
  sign("directory", fixed as never, "phone", key);
});
