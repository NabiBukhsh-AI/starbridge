# Parity

Which client has each feature a user sees. A cell is `yes`, `no` with why, `n/a`, or `not yet`;
an issue number points at the work. What a feature does is in its area's file; this table says
only where it exists. A PR that adds or changes a feature in one client updates its row, and
opens an issue for each client the row says should follow.

| Feature | Web | Android | Desktop | iOS |
|---|---|---|---|---|
| Inbox order (runs, prompts, waiting, rest; group by machine / waiting) | yes | yes | yes | yes (#1122: one feed; grouping by machine or waiting not yet) |
| Question card and answer buttons (setting: Always / When the agent waits / Never, under 1100 px) | yes | yes | yes | yes (#1122: buttons always on cards; the setting not yet) |
| Typed reply (field under the options, Enter sends) | yes | yes | yes | yes (#1122: field in the detail, the arrow sends; Return starts a new line) |
| Drafts | yes (until the page reloads) | yes (survives rotation and process death) | yes (as web) | yes (#1122: until the app quits) |
| Snooze | yes | yes | yes | not yet: snoozed questions show under Snoozed (#1122); snoozing from the iPhone not yet |
| Swipe to snooze | no (Android gesture; web has the Snooze control only) | yes (#692) | no (as web) | not yet |
| History | yes | yes | yes | yes (#1122: answered questions, with how; prompts not listed) |
| Find | yes (rail box) | yes (Material 3 search view) | yes | not yet |
| Permission prompts, answer from the device (Allow / Deny) | yes | yes | yes | yes (#1122: Allow, Deny with a note, offered scopes) |
| Runs (section, progress, dismiss) | yes | yes | yes | yes (#1122) |
| Quotas tab | yes | yes | yes | not yet |
| Quota alerts per window (settings) | yes | yes | yes | not yet |
| Widgets | n/a | yes (#894: Needs you, Quotas) | yes (#1031: Needs you only; no Quotas widget by owner's choice) | not yet |
| Notification: questions | yes (Web Push) | yes | yes | not yet |
| Notification: permission prompts | yes (taps open the page; no Allow/Deny) | yes (Allow / Deny buttons) | yes (no Allow/Deny; opens window) | not yet |
| Notification: runs | yes (#1064: pass or fail, while a page is open; runs skip Web Push) | yes (Live Update on Android 16) | yes (#1064: pass or fail, the page's own, shown by the app) | not yet |
| Notification: quota alerts | yes (only while a page is open) | yes (low-importance channel) | yes (the page's own, shown by the app) | not yet |
| Answer from a notification: option buttons | yes (only if every option fits the browser's action limit) | yes (at most 3 options) | yes | not yet |
| Answer from a notification: typed reply | no (service worker has no input action) | yes (RemoteInput "Your answer") | yes (Reply button) | not yet |
| Presence (holds other devices' pushes) | yes (#848) | yes (#848) | yes (#945, uses Mac lock/idle) | not yet |
| Offline outbox / no answer lost | no (retries 502/503 for 20 s; unsent answer kept in page memory only) | yes (#329, #331: sealed, stored, sent by WorkManager) | no (as web) | yes (#1122: sealed and stored; sent while the app is open, every 10 s and on pull to refresh; background sending comes with step 6) |
| Update screen / update notice | yes (426 shows a reload-only screen) | yes (#497: "Update Starbridge" screen) | yes (auto-updater from GitHub Releases; 426 as web) | yes (#1122: 426 shows "Update Starbridge"; answers stay in the outbox) |
| Recovery key: copy / save | yes (Copy the key; saved checkbox) | yes (copy to clipboard, #817; save) | yes (as web) | yes at first-device setup (#1116: Copy, clearing after a minute, and "I stored this key"; no Save, since iOS lets no app add a password to the password manager); Replace in Devices not yet |
| Devices list (notifies state, app icon, Revoke) | yes | yes | yes | not yet |
| Pairing: show QR for a new phone | yes | yes | yes | not yet |
| Pairing: scan a QR | no (no scanner in web) | yes (Play services code scanner) | no (as web) | yes, to join this iPhone (VisionKit, #1105); a machine's QR not yet |
| Pairing: link (`/pair#code`) | yes | yes (App Link and `starbridge://pair`) | yes (`starbridge://pair`) | not yet |
| Pairing: typed code | yes | yes | yes | not yet |
| Keyboard shortcuts (J K 1-4 A D /) | yes (from 1100 px) | no (only Enter to send, Esc in Find) | yes (as web) | not yet |
| Sound | yes (off by default, only while a page is open) | yes (system notification channel sound) | yes (macOS default sound; Basso on "Answer not sent"; web Sound row hidden) | not yet |
| Recover with the recovery key (revokes every other member) | yes | yes | yes (as web) | yes (#1116) |
| Delete account (Settings, typed confirmation) | yes (#1104) | yes (#1104) | yes (as web) | not yet |

Only on desktop: the menu bar light, the Dock or menu bar choice, Open at Login, ⌃⌥S, and notifications while no browser runs.
