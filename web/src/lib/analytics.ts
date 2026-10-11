// Umami, self-hosted beside the server (deploy/compose.yaml): cookieless page analytics for
// the public pages. The signed-in app loads no tracker and sends only the two events of `send`
// (spec/hosted.md); the server sends the launch funnel (server/src/funnel.ts).

/** Umami's id for starbridge.run; deploy/umami-setup.sh creates the website with it. */
export const WEBSITE_ID = "f3741d82-c450-47d3-8845-646cddbe392f";

/** Caddy sends /stats/script.js and /stats/api/send to Umami (deploy/Caddyfile). */
export const SCRIPT = "/stats/script.js";

/**
 * Whether this build loads Umami: only starbridge.run's, whose compose file sets
 * NEXT_PUBLIC_ANALYTICS at build time. A self-hosted build has no Umami behind /stats, so the
 * script would 404 on every page.
 */
export function analyticsOn(): boolean {
  return process.env.NEXT_PUBLIC_ANALYTICS === "umami";
}

declare global {
  interface Window {
    umami?: { track: (event?: string, data?: Record<string, string>) => Promise<void> };
  }
}

/** Records an event, or the page view with no event; a no-op where the tracker did not load. */
export function track(event?: string, data?: Record<string, string>) {
  window.umami?.track(event, data);
}

/** Umami's tracker's own opt-outs: its localStorage switch, and Do Not Track as browsers send it. */
function optedOut(): boolean {
  try {
    if (localStorage.getItem("umami.disabled")) return true;
  } catch {}
  const nav = navigator as Navigator & { msDoNotTrack?: string };
  const dnt =
    (globalThis as { doNotTrack?: string }).doNotTrack ?? nav.doNotTrack ?? nav.msDoNotTrack;
  return dnt === "1" || dnt === "yes";
}

/**
 * From the signed-in app, which loads no tracker: posts one event as Umami's tracker would, with
 * the page and its title replaced by `/` and "Starbridge" so nothing of the app's screens leaves
 * the browser. Only which error screen showed and an install as an app (#590).
 */
export function send(name: "error-screen" | "pwa-install", data?: Record<string, string>) {
  if (!analyticsOn() || optedOut()) return;
  const payload = {
    website: WEBSITE_ID,
    hostname: location.hostname,
    language: navigator.language,
    screen: `${screen.width}x${screen.height}`,
    url: "/",
    title: "Starbridge",
    name,
    ...(data ? { data } : {}),
  };
  fetch("/stats/api/send", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ type: "event", payload }),
    keepalive: true,
  }).catch(() => {});
}
