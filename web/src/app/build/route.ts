import { readFileSync } from "node:fs";
import { join } from "node:path";

// The build this server runs, which a page compares with the one it loaded from (lib/freshBuild.ts).
const BUILD = (() => {
  try {
    return readFileSync(join(process.cwd(), ".next/BUILD_ID"), "utf8").trim();
  } catch {
    return "development";
  }
})();

export const dynamic = "force-dynamic";

export function GET() {
  return new Response(BUILD, { headers: { "cache-control": "no-store" } });
}
