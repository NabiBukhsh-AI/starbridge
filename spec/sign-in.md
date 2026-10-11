# Sign-in

- The hosted server signs in with GitHub; a self-hosted server with `OWNER_TOKEN`.
- The owner can pause sign-ups (#784), for a launch-day flood or a box near its limits: a GitHub
  user with no account gets "not taking new accounts right now" on the page and in the app, while
  every existing account signs in as before. `bun server.js signups pause|resume` writes and
  removes a file beside the database, which the server reads on each new account, so it takes
  effect at once and survives restarts and deploys.
- The page shows only the sign-in methods its server offers (#670): `GET /v1/auth/methods` lists
  them, and without GitHub the landing page's and sign-in page's buttons open the owner token
  form. Until the server answers, the page shows GitHub, the hosted server's, so the landing
  page's HTML keeps its buttons.
- Android (#34, #527): the app signs in with PKCE, and GitHub binds its code to the app's
  challenge, so only the app holding the verifier can trade the code, whoever catches the
  redirect. Known gap: a hostile app can start its own sign-in, and if GitHub skips the consent
  screen it gets a session.
- On starbridge.run, GitHub redirects the app's sign-in to `/v1/auth/github/callback/app`, an
  App Link the app catches (#527). The installed web app's scope is the whole origin, so Chrome
  handed it the page's callback when no other app claimed that; where both claim a URL, Chrome
  opens the verified app. The page's sign-ins keep `/v1/auth/github/callback`, which the app does
  not claim, so they stay in the web app.
- When the browser gets the app's redirect (app missing, verification failed), the
  server passes GitHub's code on to `APP_REDIRECT_URI`: on starbridge.run the App Link
  `https://starbridge.run/app/auth`, whose page has an "Open Starbridge" button to
  `starbridge://auth`. Chrome asks "Continue to Starbridge?" before following a `starbridge://`
  redirect that no tap started; after a tap it does not. Self-hosted servers keep
  `starbridge://auth`, since the APK can bind only starbridge.run.
- `assetlinks.json` lists only the release key, which Play App Signing also uses. A debug
  keystore's password is public, and an app signed with it would verify as the App Link handler
  (#569). Dogfood builds sign with the release key instead, opted into by a gitignored
  `local.properties` line on the maintainer's machine and refused under CI; other debug builds keep
  the debug key, and their sign-in falls back to the `starbridge://auth` button.
