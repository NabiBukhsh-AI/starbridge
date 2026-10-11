"use client";

import { useEffect } from "react";
import { desktop } from "./desktop";

/** How often a hidden page asks whether the server runs a new build. */
const CHECK_MS = 5 * 60_000;

const build = () =>
  fetch("/build", { cache: "no-store" }).then(
    (r) => (r.ok ? r.text() : null),
    () => null,
  );

/** The desktop app's window says whether it is on screen; the page's visibility does not there. */
const hidden = () => (desktop?.shown ? !desktop.shown() : document.visibilityState === "hidden");

/**
 * Loads a new deploy while nobody looks. A page of an older build reloads in full on its next
 * navigation that reaches the server: a blank window for up to a second in the desktop app, which
 * stays open for days. So a hidden page that finds a new build reloads then, unless `busy`.
 */
export function useFreshBuild(busy: () => boolean): void {
  useEffect(() => {
    // The build that served this page (app/layout.tsx).
    const own = document.querySelector<HTMLMetaElement>('meta[name="starbridge-build"]')?.content;
    if (!own) return;
    let timer: ReturnType<typeof setInterval> | undefined;
    const check = async () => {
      const now = await build();
      if (now && now !== own && hidden() && !busy()) location.reload();
    };
    const onChange = () => {
      clearInterval(timer);
      if (!hidden()) return;
      check();
      timer = setInterval(check, CHECK_MS);
    };
    // Also when it loads hidden: an app opened at login, or after this very reload.
    onChange();
    document.addEventListener("visibilitychange", onChange);
    desktop?.onShown?.(onChange);
    return () => {
      clearInterval(timer);
      document.removeEventListener("visibilitychange", onChange);
      desktop?.onShown?.(null);
    };
  }, [busy]);
}
