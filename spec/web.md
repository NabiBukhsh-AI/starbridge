# Web

- **Security headers** (#312). Next sets a per-request nonce CSP in `web/src/proxy.ts`: scripts
  need the nonce or `'strict-dynamic'`, `'wasm-unsafe-eval'` lets libsodium compile, and an inline
  script sets Zod's `jitless`. Styles allow `'unsafe-inline'` (React style attributes), images
  `data:` and `blob:`, `frame-ancestors 'none'`. Every page renders per request, except the
  landing page below. Caddy adds HSTS, `nosniff` and `Referrer-Policy: same-origin`.
- **Landing page HTML** (#694). A request for `/` without the session cookie gets the whole
  landing page from the server, with its own title, description and link preview
  (`public/og.png`), so link previews and crawlers see it and a first visit is never blank. The
  proxy renders it once per origin and serves that copy with a fresh nonce: Next's one thread
  filled near 18 visitors a second (#593), and a copy costs less than a render. With the cookie,
  `/` is the app as before; the page swaps to sign-in when the browser holds a device, after a
  failed sign-in, or on "Use your own server".
- **Keyboard shortcuts** (#970) are written down once, in Settings → Inbox: J and K, 1 to 4, A
  and D from 1100 px, and / anywhere. Hints on the buttons and the Find box crowded the detail,
  and hints in some places but not others read as missing ones.
- **Back** (#347). Under 1100 px an open item is `/?item=<id>`, its own history entry, so Back
  returns to the list. Dialogs are modal `<dialog>`s, which Chrome on Android closes on Back.
- **Backoff** (#332). All calls in a page share one backoff, 250 ms doubling to 30 s with jitter,
  ended by any answer or the browser's online event. Pollers skip their turn while it waits.
- **Polling without push** (#664). Until a push reaches it, a visible page reads its inbox and
  open prompts every 5 s rather than 20 s, as Android does at 10 s (#445): it cannot tell a browser
  without Web Push from a server that sends none, and the owner may be watching it for a question.
  That is 24 reads a minute per visible page, inside the per-address limit; 100 such pages cost
  about a tenth of a core (#664 has the numbers). A hidden page still reads nothing, except in
  the desktop app, which notifies from its inbox and prompts and so reads them while hidden (#886).
- **Notifications.** The service worker shows one per question and closes it once answered. Its
  actions answer only for the account it was shown for (#274). Signing out, revocation or adopting
  new keys closes them all (#311).
- **Sound**: off by default, while a page is open only; a service worker cannot play audio.
- **Layout.** Panes resize by dragging or arrow keys. From an 840 px page, Quotas is one table and
  providers reorder by drag or keys; a group that "Running out first" pins shows a pin with a
  popover explaining why (#296, #351). The detail pane widens with the window (DESIGN.md `wide`).
- **Layout checks fail CI** (#305): every e2e screenshot at 390 and 1280 px, rechecked at 320,
  fails on overflow, clipped text without an ellipsis, overlapping text, or a CSP violation.
