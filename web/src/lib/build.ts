import { readFileSync } from "node:fs";
import { join } from "node:path";

/** The build this server runs: written into each page, and served at /build (lib/freshBuild.ts). */
export const BUILD = (() => {
  try {
    return readFileSync(join(process.cwd(), ".next/BUILD_ID"), "utf8").trim();
  } catch {
    return "development";
  }
})();
