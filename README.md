# Social Dating

A premium dating app, built with Flutter. **This repository currently contains
Phases 0–12 plus a first ASP.NET Core auth slice in `backend/`.** There is no
SMS provider, payment server, or production API. Debug `flutter run` still
uses labelled **mocks**. A UI that builds is not production readiness.

## What is included

### Phase 0: foundation

- Design tokens (colour, typography, spacing, radius, elevation, size, icon and
  motion) and light/dark themes in `lib/core/theme/`.
- Branded splash and welcome screens, native launch screens, global error
  handling, persisted theme mode.
- A Dio API client that **rejects every request** while
  `ApiConfig.networkEnabled` is `false`, plus a lazily-created secure token
  storage abstraction (unused).

### Phase 1: UI foundation and navigation

- **Components** (`lib/core/widgets/`): five button variants (primary,
  secondary, outlined, text, destructive), text fields with validation and a
  phone-number field that formats as you type, profile avatar, image carousel,
  profile card, verified badge, interest chip, pill, match card, chat preview,
  chat bubble, wallet summary, subscription plan card, menu tile, section and
  screen headers, loading skeletons, empty/error/retry states, offline banner,
  dialogs, bottom sheets, snackbars, top app bar, bottom navigation.
- **Screens**: phone sign-in and code verification, profile completion,
  discovery, likes, matches, chat list and conversation, profile hub,
  subscription, wallet, referrals, notifications, settings (appearance), safety
  (tips and report flow) and account (sign out, delete account).
- **Navigation** (`lib/core/routing/`): one GoRouter with a five-tab shell
  (Discover, Likes, Matches, Chat, Profile) that keeps each tab's state, with
  every other destination as a full-screen route. Paths live in `AppRoutes`.
### Phase 2: sign-in and first-time onboarding

- **Welcome**: logo, positioning, "Create account" and "Log in", links to the
  Terms and Privacy Policy, and a one-time "signed out" / "account deleted"
  notice.
- **Phone entry**: country selector (Nepal, +977 by default; searchable list),
  digit grouping as you type, a numeric keyboard, a submit button that is
  disabled until the number is plausible, and errors that appear only when
  they help (never while a short number is still being typed).
- **Code entry**: six grouped digit boxes driven by one hidden text field (so
  paste, SMS autofill and screen readers behave normally), a visible focus
  ring, loading state, incorrect/expired messages, a 30 second resend timer,
  a resend button, and "Change number".
- **Terms, privacy and age**: three required acknowledgements with readable
  (placeholder) documents.
- **Date of birth**: typed day/month/year with live 18+ feedback and clear
  messages for impossible or future dates.
- **Progress and completion**: "Step N of 5" on every setup screen, then a
  completion screen before entering the app.
- **Failures**: network error with retry, generic sign-in failure with retry,
  an under-age blocked screen, and a session-expired screen.
- **Logout and session expiry**: sign out from Account (or from any setup
  screen), delete account, and a debug "Simulate expired session" tile.

### Phase 4: discovery feed and swipe cards

- **Discovery home**: one large profile card (photos, name, age, coarse
  location, bio, interest chips). Photos change by tapping the left or right
  edge of the card; dragging sideways is reserved for swiping the card.
- **Swipe gestures**: horizontal drags move the card with rotation, fading and
  LIKE / NOPE stamps (icon plus word, not colour alone). A swipe commits past
  30% of the card width or with a quick fling; otherwise it springs back.
  Vertical drags never swipe. The pass and like buttons run exactly the same
  flow, so the gesture is never required.
- **Profile detail**: tap the card for a full-screen, vertically scrolling
  profile with a photo gallery. Scrolling there never swipes. Its pass and
  like buttons close it and run the normal swipe flow.
- **Preferences**: age range, approximate distance, show-me, verified only and
  shared interests, with reset and an active-count badge.
- **States**: loading skeleton, "no more profiles", "no results" (with reset)
  and a retry state. A failed swipe puts the card back with a message.
- **New match**: a celebration dialog triggered by mock data (right-swiping
  `mock-2`, `mock-10` or `mock-14`).
- **Undo** is shown disabled by default. Start the app with
  `--dart-define=UNDO_SWIPE=true` to enable it as a labelled mock feature.

#### Swipe rules as presented (mock behaviour)

| Rule | What the UI does |
| --- | --- |
| First 5 swipes | Allowed before the profile is complete (the "explore first" preview). The counter reads "N of 5 preview swipes left". |
| Profile gate | After 5 swipes with an incomplete profile, the deck is replaced by "Finish your profile to keep swiping". |
| Free swipes | Male accounts get 20 free swipes per Nepal calendar day after the profile is complete. Left and right share one count. |
| Extra swipes | NPR 0.10 each (10 paisa, held as an integer). Every paid swipe shows the cost, the mock wallet balance and the balance after, and needs an explicit confirmation. Cancelling charges nothing and the card springs back. |
| Insufficient balance | If the mock balance is below NPR 0.10, a sheet explains this, nothing is charged and the card stays. |
| Daily reset | At midnight in Nepal time (UTC+5:45), whatever the device time zone is. |
| Other accounts | In this simulation they have no daily limit and are never charged. |

**All counting and pricing here is mock behaviour.** The counters live in an
in-memory `MockSwipeRepository`, are labelled "Mock" in the UI, and reset when
the app restarts. The server must be authoritative later: it must own the
count, the Nepal-day boundary, prices, balances and matching, and it must
reject any swipe the client lets through. The client only predicts the result
so swipes feel instant, then defers to the repository. If the repository
disagrees, the card comes back and the counters snap to its values.

Assumptions to confirm with product:

- Preview swipes (before the profile is complete) are a separate counter and do
  not use up the first day's 20 free swipes.
- Undo, if ever enabled, rolls back the count and refunds a paid swipe.
- The free-limit gender comes from the account. Here it is a mock setting.
- The paid-swipe price is shown to the paisa; rounding rules for larger
  amounts are not defined yet.

### Phase 5: likes, matches, preferences and match management

Frontend only. One in-memory mock (`MockMatchingRepository`) stands in for the
service and is the single source of truth for discovery, likes, matches and
chat, so they cannot disagree. Nothing is created on a real service, and the
app says so wherever a match appears ("Mock data: this match exists on this
device only").

- **Likes** has Received and Sent views. Received: "Like back" (with a pending
  state and the celebration), "Not now", tap for a profile preview. Sent: shows
  "Waiting for a reply" and "Withdraw like".
- **Matches**: new matches in a strip, everyone else in a list, with matched
  times and recently-active hints ("Active now", "Active 3h ago"). Header icons
  open **Match history** and **Match preferences**.
- **Match detail** (`/matches/:id`): full profile, "Send a message", and a
  "Manage this match" section (report or get help, unmatch, block). Unmatch and
  block always ask first and show progress, failure and success.
- **Match preferences** (`/matches/preferences`, also in Settings): eligible
  accounts (woman or transgender in the mock) choose a daily match preference.
  The screen separates the *preference* ("up to 5 per day", never guaranteed)
  from today's sample count. Other accounts see why it is unavailable and can
  still change the pause and activity settings.
- **Match history** (`/matches/history`): matched, unmatched and blocked.

Rules enforced by the mock (and to be enforced by the service):

- A pair has at most one match. The id is derived from the person (`match-<id>`)
  and every path is idempotent, so double taps or repeats never create a second
  card. A match's chat id is derived the same way.
- A mutual like (a received like, or a person in the mock "likes back" list)
  creates the match. Undoing a swipe reverts it.
- Unmatching or blocking removes the match and closes the conversation. Blocked
  and unmatched people never return to the deck.

Assumptions to confirm with product:

- Eligibility for the daily preference comes from the account, not from this
  screen. The mock bases it on the mock account type.
- The preference does not change which matches the mock creates; the service
  decides how (or whether) it is applied.
- There is no unblock screen yet, and the history is not deleted when someone is
  blocked.
- "Show when I'm active" is stored but the mock still shows activity.
- State resets when the app restarts, and signing out does not clear it.

### Phase 6: conversations and paid-message presentation

Frontend only. Conversations live in an in-memory `MockMessagingRepository`
owned by `MockMatchingRepository`. There is no SignalR connection and no
backend. Unmatching or blocking still closes the chat.

- **Messages list**: avatars (local sample portraits), latest preview, unread
  badge, relative time, mute mark, search, and a long-press confirmation to
  hide a conversation (the match stays).
- **Conversation**: incoming and outgoing bubbles, date separators, a mock
  typing indicator, jump-to-latest, delivery states (sending, sent, failed)
  with retry, a keyboard-aware composer, character/word counters, and sample
  photo attachments from `assets/portraits/` only.
- **Header**: profile shortcut (avatar/name and Match details) plus mute,
  hide, report, unmatch and block. Report opens the safety centre. Hide,
  unmatch and block always ask first.

#### Paid messaging as presented (mock behaviour)

| Rule | What the UI does |
| --- | --- |
| Who pays | Male accounts, in this simulation. |
| Price | NPR 0.10 (10 paisa) per eligible word. |
| Eligible word | A whitespace-separated token that contains at least one letter. Punctuation-only and digit-only tokens do not count. The function is `countEligibleWords` in `lib/core/constants/message_rules.dart`. |
| Points | 100 points = NPR 1, so 1 point = 1 paisa in this mock. The composer and confirm dialog show NPR and points. |
| Confirm | A paid send shows the estimated deduction, balance after, and an 80% recipient / 20% platform breakdown **as explanation only**. Cancelling charges nothing. |
| Failed sends | Stored as failed, never deducted. Retry asks again if the draft is still paid. |
| Double-send | The composer locks until the in-flight send finishes. |

**None of this is a real charge, transfer or payout.** Copy always says Mock.
Change prices, the 80/20 split, the word rule and the points rate in
`message_rules.dart` only. The server must later own counting, who pays,
balances and allocation, and must reject anything the client lets through.

Assumptions to confirm with product:

- Other account types are not charged for messages in this mock.
- Image-only messages have no eligible words and are not quoted as paid.
- Hiding a conversation does not unmatch; unmatch and block still close it.
- Typing is a seeded mock (Quinn) and stops after you send in that thread.

### Phase 7: subscription discovery and mock checkout

Frontend only. Plans, quotes and prototype payment outcomes live in
`MockSubscriptionRepository`. There is no payment gateway, app-store billing
or subscription API.

- **Overview** compares Premium (NPR 100, one-time) with Premium Monthly
  (NPR 100 per month, recurring in the mock). After a successful prototype
  purchase, it shows the active membership and benefits.
- **NPR 100 detail** and **checkout review** show the amount due, 3,000
  promotional points (stated NPR 30 equivalent) and, when a mock referral
  code is applied, an NPR 10 direct commission and NPR 60 company allocation.
- **Payment methods** are illustrative (eSewa, Khalti, Card) and are not
  connected. Confirming creates a **pending** mock purchase. Success, failure
  and cancelled are chosen on the pending screen and labelled as a prototype
  demonstration. Nothing auto-succeeds.
- **History**, **FAQ / billing help**, and **renewal/cancellation** (monthly
  plan only). The one-time NPR 100 plan does not show cancel/renew.

| Rule | What the UI does |
| --- | --- |
| Standard NPR 100 | 3,000 buyer points, stated NPR 30 equivalent, not withdrawable. |
| Referral-linked NPR 100 | Same points, plus NPR 10 referral commission and NPR 60 company allocation (explanatory). |
| Taxes / fees | Shown only if `SubscriptionRules` supplies them. This mock adds none. |
| Points kinds | Promotional (purchase), earned (activity), cash-convertible (referral commission) are explained separately. |
| Double tap | Confirm and prototype-outcome buttons lock until the mock call finishes. |

**None of this is a real charge.** Copy always says Mock. Change prices,
points, the 80/20-style referral split, withdrawability and fees in
`lib/core/constants/subscription_rules.dart` only.

Assumptions to confirm with product:

- The NPR 100 one-time plan does not auto-renew.
- Promotional points stay non-withdrawable unless policy changes.
- Referral commission is for the referrer, not cash the buyer can take out.

### Phase 8: wallet dashboard and points

Frontend only. Balances, NPR equivalents and withdrawal requests live in
`MockWalletRepository`. There is no bank, payment gateway, payout provider or
backend ledger.

- **Overview** shows promotional and earned points as separate cards, each
  with a stated NPR equivalent (100 points = NPR 1). Copy states that an
  equivalent is not necessarily withdrawable cash.
- **Activity** is a filterable timeline (All, Promotional, Earned, Added,
  Spent) with a detail screen for each mock record.
- **Welcome bonus** explains 1,000 promotional points: not cash, not
  withdrawable.
- **Subscription reward** appears as 3,000 promotional points (stated NPR 30
  equivalent) under the configured redemption policy (not withdrawable).
- **Spends** include a paid swipe (NPR 0.10 = 10 points) and paid messaging
  charged to the point wallet.
- **Withdrawals** are visible to female, LGBTQ+ and other accounts. A request
  form appears only with at least 500 earned, withdrawable points (NPR 5
  equivalent). Promotional points never count. Men and other account types
  see why the form is hidden. Below 500 earned points is an insufficient
  balance state.
- **Recording a request** saves a mock hold on this device. Statuses are
  recorded, cancelled or declined — never paid. Help and fees screens show
  only `WalletRules` values (this mock adds no extra fees).

| Rule | What the UI does |
| --- | --- |
| 100 points = NPR 1 | Stated equivalent only; 1 point = 1 paisa in this mock. |
| Welcome 1,000 | Promotional, non-cash, non-withdrawable. |
| Subscription 3,000 | Promotional, stated NPR 30, not withdrawable. |
| Paid swipe | NPR 0.10 = 10 points if charged to the point wallet. |
| Minimum withdrawal | 500 earned points (NPR 5 equivalent). Promo excluded. |
| Fees / processing | Shown only from `WalletRules`. No provider guarantees. |

**None of this is a real withdrawal or payout.** Copy always says Mock.
Change conversion, bonuses, the 500-point threshold, fees and processing
notes in `lib/core/constants/wallet_rules.dart` only.

Assumptions to confirm with product:

- Only female, LGBTQ+ and other accounts see the request form in this mock.
- Promotional welcome and subscription points stay non-withdrawable unless
  policy changes.
- A recorded mock request is not a submission to a bank.

### Phase 9: referral sharing and earnings

Debug `flutter run` still uses `MockReferralRepository` (`MOCK-0000`,
labelled mock link). API mode (`DATA_SOURCE=api`) uses unique codes and
attribution stored in PostgreSQL.

- **Overview** shows the person’s code, copy, share, optional “apply a
  friend’s code”, invite/joined/pending stats, and the NPR 100 split.
- **Qualifying NPR 100 split** is NPR 60 company, NPR 30 buyer reward
  equivalent, NPR 10 direct referrer commission. Copy states this is not
  guaranteed income.
- **History** lists people who used the code (joined, purchase recorded,
  refunded).
- **Earnings** show pending, approved, reversed and paid balances. Pending
  stays pending until a qualifying purchase is confirmed. Reversed amounts
  are not earnings. Paid is not a bank payout until a payout provider exists.
- **Help** covers eligibility, refund reversals, and that there is no
  multi-level commission.

| Rule | What happens |
| --- | --- |
| NPR 100 referral purchase | Proposed split NPR 60 / NPR 30 / NPR 10. |
| Pending | Until a qualifying purchase is confirmed. |
| Reversed | After a refund. Not counted as paid. |
| Multi-level | Not built. Direct referrer only. |

Mock copy still says Mock. API copy is live for codes and joins; payouts
are still not sent. Change the split in `subscription_rules.dart`
(via `referral_rules.dart`).

### Phase 10: notifications, safety, privacy and account

Frontend only. The inbox, preferences, reports and deletion requests live in
`MockNotificationRepository`, `MockSettingsRepository` and the matching mock.
There is no push service, background scheduler, moderator queue or production
account deletion.

- **Notification inbox** shows unread and read items. Tapping marks an item
  read on this device. Preferences cover push types, a profile-completion
  reminder every 3–5 days, and quiet hours. Copy states that nothing is sent
  or scheduled.
- **Privacy** lists what is public (name, age, city, photos, bio) and what
  stays private (phone number, exact location, date of birth). Toggles are
  saved on this device only.
- **Blocked users** lists people blocked from matching. Unblocking needs
  confirmation.
- **Report a person** requires a category, with optional details and a sample
  photo. The confirmation screen records a mock report on this device and
  never claims it was sent to moderators.
- **Help center**, **Terms of Service** and **Privacy Policy** remain labelled
  placeholders / mock answers.
- **Account** shows a masked number, a change-phone UI that sends no SMS, sign
  out with confirmation, and a deletion request that explains consequences and
  a future backend retention policy before ending the local session.
- **Accessibility and theme** cover reduce-motion, bold text and light/dark.
  Text size follows the system setting.

| Rule | What the UI does |
| --- | --- |
| Preferences | Saved on this device (mock). No push or reminder is scheduled. |
| Reports | Stored locally. Not sent to moderators. |
| Deletion | Confirmation plus consequences. Ends the local sample session. |
| Phone / location | Masked number only. City-level location. Never the exact place. |

**None of this is a live safety or account-deletion pipeline.** Copy always
says Mock where a real backend would be required.

### Phase 11: quality audit and UI polish

Frontend only. No backend, billing provider, SMS, or push service was added.

- Duplicate-tap guards on change-phone save and blocked-user unblock.
- Screen-reader labels on payment-method tiles, chat headers, and sample
  photos. Missing-image fallbacks on report and chat attachments.
- Keyboard dismiss-on-drag on checkout, report, and withdrawal request.
- Verify and phone screens no longer imply that an SMS was sent.
- Widget tests added for profile completion into discovery, paid-message
  deduction, and the 499 / 500 earned-point withdrawal boundary.
- This README lists every mock-only feature and what must be integrated later.

**The app is not production-ready.** Passing `flutter test` only proves the
mock UI. Route guards are UX, not security.

### Phase 12: prepare for a future ASP.NET Core backend

Dio does not open a socket unless `DATA_SOURCE=api`, `API_BASE_URL` and
`API_NETWORK=true` are all set. Auth `/v1` is confirmed in
`backend/CONTRACT.md` and implemented by `ApiAuthRepository`. Other API
repositories still refuse until their contracts exist.

- Typed DTOs for auth, profiles, discovery, swipes, likes, matches, chat,
  subscriptions, payment status, point balances, transactions, referrals,
  notifications, reports and account settings. Money is integer paisa.
  Points, statuses and IDs are typed. Private phone / geo fields are rejected.
- Repository interfaces plus API implementations. Unconfirmed features throw
  `ApiContractMissingFailure` instead of recording fake financial success.
- Mock implementations are unchanged. Debug `flutter run` still selects them.
- Environment labels `development` / `staging` / `production` via `APP_ENV`.
  Hosts come only from `API_BASE_URL`. No secrets and no compiled-in URLs.
- Central error mapping for validation, unauthorized, forbidden, rate-limited,
  network, cancelled and server failures.
- Cursor pagination (`Page` / `PageRequest`) and Dio `CancelToken` on the
  page request.
- Client-side pricing, swipe quotes and wallet conversion remain **display
  previews**. A future backend response is authoritative.
- Release builds default to the API data source. `DATA_SOURCE=mock` in
  release requires `ALLOW_MOCK_DATA=true`.

The app is still not production-ready.

## Mock sign-in (development only)

The authentication repository is `MockAuthRepository`
(`lib/data/repositories/mock_auth_repository.dart`). **No SMS is sent and no
phone number is checked.** Every sign-in screen says so. Do not mistake it for
verification. Use these published test inputs:

| Input                         | Result                                  |
| ----------------------------- | --------------------------------------- |
| Code `123456`                 | accepted                                |
| Code `000000`                 | "code expired"                          |
| Code `111111`                 | generic sign-in failure (every time)    |
| Code `222222`                 | network error once, accepted on retry   |
| Any other code                | "incorrect code"                        |
| Phone number ending `0000`    | network error once when sending         |
| Phone number ending `1111`    | generic failure when sending            |

All validation (phone digits, code length, date of birth, age) is for UX only.
A real backend must validate everything again.

Journey: welcome, phone, code, terms, date of birth, profile, completion, app.
An 18-or-older birth date goes on to profile completion. A younger one shows
the blocked screen, and the router keeps every dating screen out of reach.

### Sessions and app restart

Session state lives in one Riverpod provider (`sessionProvider`). After a
restart the app resumes from a small snapshot in `SharedPreferences`:

- It holds the setup step, a **masked** number for display (`+977 ••••••4567`),
  the first name, the mock account's outcomes (terms accepted, age eligible)
  and a timestamp.
- It never holds a token, the full phone number, or the birth date. The birth
  date is used once to compute eligibility and then discarded.
- A snapshot older than 30 days becomes "session expired". An under-age block
  does not expire into a normal sign-in.
- Signing out or deleting the account clears it.

Mock limits: accounts live in memory, so after a *restart* only the account in
the snapshot is remembered. Signing in again after a session expiry resumes
that account; signing in with a different number after signing out starts a
new one.

## Route guards are not security

`sessionRedirect` (`lib/core/routing/route_guards.dart`) sends people to the
one screen that makes sense for the current mock session:

| Session              | Everything else goes to    | Allowed                          |
| -------------------- | -------------------------- | -------------------------------- |
| Logged out           | `/welcome`                 | welcome, sign-in screens         |
| Session expired      | `/session-expired`         | expired screen, sign-in screens  |
| Needs terms          | `/onboarding/terms`        | that screen                      |
| Needs birth date     | `/onboarding/birthdate`    | that screen                      |
| Under age            | `/onboarding/ineligible`   | that screen                      |
| Incomplete profile   | `/profile-completion`      | that screen and `/discover`      |
| Setup complete       | `/onboarding/complete`     | that screen                      |
| Logged in            | `/discover` (from auth)    | the whole app                    |

`/legal/*`, `/splash` and debug routes are reachable in every state.

This is **UX routing only**. Client-side checks can always be bypassed, so a
real backend must authenticate and authorise every request itself (including
the 18+ rule). Unknown paths are never redirected and show the not-found
screen.

## Visual conventions

- **Icons**: every icon comes from `AppIcons` (Material rounded). Emoji are
  never used as icons. `test/design_conventions_test.dart` fails if `Icons.`
  appears outside `app_icons.dart`, or if emoji appear in `lib/`.
- **Tokens, not literals**: feature screens use theme tokens and the
  `AppPalette` extension. The same test fails on raw colours in
  `lib/features/` (the debug gallery is exempt).
- **Accessibility**: 48dp minimum touch targets, text scaling up to 1.5x
  verified on every screen at 360dp wide, reduced-motion support, semantic
  labels on custom controls, and contrast-checked colour pairs in both themes.

## Requirements

- Flutter stable (developed on Flutter 3.35.1 / Dart 3.9.0)
- Android Studio / Xcode toolchains for the platforms you target

Check your setup with `flutter doctor`.

## Setup and run

```bash
flutter pub get
flutter run                  # pick a connected device or emulator
flutter run -d <device-id>   # a specific device (see `flutter devices`)
```

Android emulator (if none is running):

```bash
flutter emulators --launch <emulator-id>   # list ids with `flutter emulators`
flutter run
```

Browser preview (Edge or Chrome) is available for quick UI iteration only; the
supported targets are Android and iOS:

```bash
flutter run -d edge
```

iOS builds require macOS and Xcode (`flutter run -d <ios-simulator-id>`).

Quality checks:

```bash
dart format .
flutter analyze
flutter test
```

### Debug gallery and mock controls

In debug builds, the welcome screen and Settings show a link to
`/dev/design-system`: a gallery of every shared component plus **mock
controls** to jump the session to any of its eight states, list the mock
sign-in test inputs, toggle the offline banner, and switch the sample-data
scenario between data, empty and error. A "Swipe rules (mock)" section sets
the account type, the swipes used today, the preview swipes used and the wallet
balance so the free, paid and insufficient-balance states are one tap away, and
previews the match, paid-swipe and limit sheets. Choosing a session state replaces the
saved mock session. That route is registered only when `kDebugMode` is true
and is never redirected by the session guard.

## Project structure

```
lib/
  app/                 App widget, bootstrap and the tabbed MainShell
  core/
    constants/         App constants, storage keys
    theme/             Tokens (colour, type, spacing, radii, elevation, sizes,
                       icons, motion) + ThemeData
    routing/           GoRouter config, route paths, session guard
    utils/             Validators, phone formatter, time/number formatting,
                       responsive helpers, offline flag
    widgets/           Reusable UI components
    errors/            AppFailure types and global error handler
  features/            One folder per feature: onboarding, auth, profile,
                       discovery, likes, matches, chat, subscription, wallet,
                       referrals, notifications, settings, safety
  data/
    models/            App-level models
    dto/               Proposed wire DTOs (typed ids, paisa, points, statuses)
    api/               Pagination helpers
    repositories/      Contracts, mocks, refusing API stubs, provider seam
    services/          Dio client, secure storage, local preferences, providers
test/                  Widget and unit tests (no `integration_test/` suite)
```

## Mock data policy

Sample data lives only in files prefixed `mock_` and is clearly labelled
(prices read "(sample)", the invite code is `MOCK-0000`, all IDs start with
`mock-`, and every person is fictional).

Production code reaches mocks through exactly two seams:

- `data/repositories/repository_providers.dart` (repositories, including
  `authRepositoryProvider`, the single place the mock authentication
  repository is chosen, and `swipeRepositoryProvider` for the mock swipe
  server)
- `features/auth/providers/session_provider.dart` (session)

UI and routing import only these seams. Replacing a mock with a real
implementation means changing one provider declaration. The allow-list is
enforced by `test/mock_isolation_test.dart`, which fails if any other file
imports a `mock_` source.

## Networking and secrets

- No network calls are made at startup or anywhere else in the default debug
  mock build. `NetworkGuardInterceptor` rejects every Dio request while
  `ApiConfig.networkEnabled` is `false`.
- Environment and data source are dart-defines only:

  ```
  flutter run
  # debug default: DATA_SOURCE=mock, APP_ENV=development, no host

  flutter run \
    --dart-define=DATA_SOURCE=api \
    --dart-define=API_BASE_URL=<host supplied at run time> \
    --dart-define=API_NETWORK=true

  flutter build apk --release \
    --dart-define=APP_ENV=production \
    --dart-define=DATA_SOURCE=api \
    --dart-define=API_BASE_URL=<host supplied at build time> \
    --dart-define=API_NETWORK=true
  ```

  Or `scripts/build_production.ps1` (web, Windows, APK, API publish) and
  `scripts/run_api_production.ps1` (API with `ASPNETCORE_ENVIRONMENT=Production`).
  Local API origin: see `backend/CONTRACT.md`. Do not compile a host into
  `lib/`. Card checkout, SMS, push and payouts are still unconfirmed. A
  release binary talks to the API; it is not a store-ready product.
- Release binaries default to `DATA_SOURCE=api`. They will not silently use
  mock wallet, checkout or referral success. `DATA_SOURCE=mock` in release
  requires `--dart-define=ALLOW_MOCK_DATA=true`.
- `SharedPreferences` stores only non-sensitive values: theme mode, mock
  notification/privacy/accessibility preferences, and the session snapshot
  described above. Tokens belong in `flutter_secure_storage` via
  `TokenStorage`. They exist only after a live verify against the API.

## API contracts the backend team must supply

Do not connect a feature until the ASP.NET Core team confirms the items
below. Proposed JSON field names live in `lib/data/dto/` and are **not**
an endpoint specification. Paths, verbs, auth, versioning and error bodies
must come from the backend.

| Feature | Contract still required |
| --- | --- |
| Auth | Confirmed: `POST /v1/auth/code`, `verify`, `refresh`, `sign-out`. Access JWT 15 min, hashed refresh 30d. OTP hashed at rest. See `backend/CONTRACT.md`. |
| Onboarding | Confirmed: `POST /v1/me/terms`, `age`, `profile`; `GET`/`DELETE /v1/me`. Profile completion sends name, bio, 3–8 interests, city and gender. |
| Profiles | Confirmed: public fields on discovery/match payloads plus profile photos (`GET`/`POST /v1/me/photos`, reorder, delete, signed `GET /v1/media/{id}`). Forbid E.164, birth date, exact coordinates on the client. |
| Discovery | Confirmed: `GET /v1/discovery/candidates`, `quota`; `POST /v1/discovery/swipes`, `undo`. Nepal-day quota. Extra male swipes charge 10 paisa after confirm. |
| Likes / matches | Confirmed: likes received/sent, like-back, decline, withdraw, `GET /v1/matches`, unmatch, seen, block/unblock. Still required: match history and daily match preferences. |
| Chat | Confirmed: list, messages, send, read, mute, hide, chat photos (`POST /v1/chats/{id}/photos` then `imageId` on send), SignalR `/v1/hubs/chat`. Conversation id is the match id. Client `MessageQuote` is display-only; men are charged from the point wallet. |
| Subscriptions | Plan catalog, quote, checkout, payment status, entitlements, cancel/resume renewal. Client NPR 100 split is display-only. Never treat a client quote as a charge. |
| Wallet | Confirmed: `GET /v1/wallet`, transactions. 1,000 promotional welcome points. Extra swipes and paid words debit the ledger. Paid-message recipients receive earned points. |
| Withdrawals | Confirmed: eligibility, submit, cancel, history. Female / LGBTQ+ / other, 500 earned-point minimum. Holds are never paid. Payout provider still required. |
| Referrals | Confirmed: unique codes, claim, pending NPR 10 commissions. Approving or paying a commission is still later. |
| Notifications | Confirmed: `GET /v1/notifications`, mark one/all read. Like, match and message events. Push and preference flags are still later. |
| Reports / deletion | Submit report, acknowledgement, retention for deletion. Client must not claim a moderator received the report until the queue exists. |
| Account settings | Masked phone label, public/private flags. Change-phone with a new OTP. |
| Errors | RFC 7807 Problem Details for 400/401/403/404/422/429/5xx, including `retry-after` on 429. |
| Pagination | Cursor + `limit` query, `{ items, nextCursor }` envelope. |

Keep `DATA_SOURCE=mock` for local UI work. Point at the API only when you
intend to exercise the confirmed auth slice.

## Mock-only features (must be integrated later)

Nothing in this table is a live service. The UI describes mock behaviour so it
cannot be mistaken for production OTP, payment, wallet or commission systems.

| Mock today | What the UI does | Must be integrated later |
| --- | --- | --- |
| Sign-in OTP (`123456` and related codes) | Mock: no SMS, labelled development-only. API mode: random 6-digit code in the **server log** (`Auth:LogOtps`). | SMS/OTP provider. |
| Phone change | Updates a masked label on this device. No SMS. | Verified number change with a new OTP. |
| Session / account deletion | Mock: local snapshot. API mode: server session + soft-delete. Guards remain UX, not security. | Retention policy, SMS-backed recovery. |
| Discovery swipes and paid-swipe dialog | In-memory counters and NPR 0.10 display. Nothing is charged. | Server-side allowances, billing for extra swipes. |
| Matches, likes, blocks | In-memory. Unmatch/block stay on this device. | Matching service as source of truth. |
| Chat messages and word-price preview | Stored in memory. Male senders see NPR 0.10/word. Confirming deducts mock points only. | Message transport, paid-message ledger, receipts. |
| Subscription checkout | Illustrative methods. "Confirm mock purchase" does not charge a card. | Payment provider, tax, receipts, entitlements. |
| Wallet balances and conversions | 100 points = NPR 1 display only. Welcome/subscription points are promotional and not cash. | Ledger, payout provider, real conversion. |
| Withdrawals | Eligibility UI. Recorded/cancelled/declined are never paid. 500 earned-point threshold is mock. | KYC, payout rails, fee/tax from a provider. |
| Referral code `MOCK-0000` and `mock://` link | Mock: demonstration-only. API: unique codes and joins in PostgreSQL; commissions stay pending. | Qualifying-purchase confirmation, payout provider. |
| Notifications, quiet hours, 3–5 day reminder | Device preferences. No push, no scheduling. | Push provider, reminder jobs. |
| Safety reports | Saved on this device. Not sent to moderators. | Moderation queue, evidence storage. |
| Terms / Privacy Policy | Placeholder copy. | Reviewed legal documents. |
| Photos | Mock: bundled sample portraits. API: signed local-disk media. | CDN, moderation, chat image upload. |
| Network | Dio rejects every request while networking is disabled. Unconfirmed API repos still refuse. | Remaining contracts, `DATA_SOURCE=api`, host, tokens. |

A passing widget test suite does **not** mean the product can go live.

## Fonts

The app uses platform system fonts so there are no runtime font downloads. To
adopt a brand typeface, bundle the font asset and set `fontFamily` in
`lib/core/theme/app_typography.dart`.
