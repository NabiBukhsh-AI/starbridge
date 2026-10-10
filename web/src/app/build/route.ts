import { BUILD } from "@/lib/build";

export const dynamic = "force-dynamic";

export function GET() {
  return new Response(BUILD, { headers: { "cache-control": "no-store" } });
}
