# Auth contract (v1)

Confirmed by `SocialDating.Api`. Field names match the Flutter DTOs in
`lib/data/dto/auth_dtos.dart`. Money is not used on these endpoints.

`ApiAuthRepository` implements this contract. Debug `flutter run` stays on
mocks until `DATA_SOURCE=api`, `API_BASE_URL`, and `API_NETWORK=true` are set.

## Host

- Development: `http://localhost:5088`
- Production: supply via `--dart-define=API_BASE_URL=...` only. Never compile a host into the app. `ASPNETCORE_ENVIRONMENT=Production` refuses `Auth:LogOtps` and does not seed demo profiles.

Run locally from `backend/src/SocialDating.Api` with `dotnet run`. Connection string and JWT signing key live in `dotnet user-secrets` (`UserSecretsId`: `social-dating-api`). They are not in the repo.

## Errors

RFC 7807 Problem Details. `detail` and `title` are short client-safe sentences
(no URLs, no traces). Status usage:

| HTTP | Meaning |
| --- | --- |
| 400 | Validation (phone, code length, birth date, name, bio, interests, city, gender, swipe direction, photo type/size/count/order) |
| 401 | Wrong/expired code, or missing/invalid session |
| 404 | Like, match, conversation, photo, notification or person is no longer available |
| 429 | OTP resend cooldown or too many verify attempts. `Retry-After` is seconds. |
| 500 | Unexpected |

## Endpoints

### `POST /v1/auth/code`

Request:

```json
{ "phone": "+9779841234567" }
```

Response `200`:

```json
{ "retryAfterSeconds": 30, "registered": false }
```

`registered` is `true` when this number already has an account. The app still
asks for the code. After a correct code, a registered number opens the app;
a new number continues to gender and full name.

No SMS is sent until a provider is wired. While `Auth:SmsEnabled` is false,
every issued code is `Auth:StaticOtp` (`123456`). The API never writes that
code to logs. In Development, `Auth:LogOtps=true` only logs a generated code
when `StaticOtp` is empty. Set `SmsEnabled` true when an SMS provider sends
random codes.

### `POST /v1/auth/verify`

Request:

```json
{ "phone": "+9779841234567", "code": "123456", "login": false }
```

`login` is optional. A number that already has an account is a returning user:
missing profile fields are filled and the app opens. A **new** number gets
terms and age recorded, then continues to gender and full name.
`login: true` also finishes a first-time number. Under-age accounts stay blocked.

Response `200` (`AuthVerifyResponseDto`) after a new number:

```json
{
  "account": {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "termsAccepted": true,
    "isAgeEligible": true,
    "displayName": null,
    "gender": null
  },
  "accessToken": "<jwt>",
  "refreshToken": "<opaque>",
  "expiresAt": "2026-10-29T03:00:00.0000000+00:00"
}
```

`account` never includes `phone`, `e164`, `birthDate`, or `dateOfBirth`.

### `POST /v1/auth/refresh`

```json
{ "refreshToken": "<opaque>" }
```

Returns the same shape as verify. The previous refresh token is revoked.

### `POST /v1/auth/sign-out`

Requires `Authorization: Bearer <accessToken>`. Optional body
`{ "refreshToken": "<opaque>" }` revokes one token; omit to revoke all.

### `GET /v1/me`

Bearer required. Returns `account` object only (`AccountStateDto`).

### `POST /v1/me/terms`

Bearer required. Idempotent. Returns account.

### `POST /v1/me/age`

```json
{ "birthDate": "2000-01-15" }
```

Server computes 18+ in UTC calendar dates, stores the date **privately**
(never on JSON), and returns only `isAgeEligible`. A second call is a no-op.

Under-age accounts still receive `200` with `"isAgeEligible": false` so the
app can show the blocked screen.

### `POST /v1/me/gender`

```json
{ "gender": "female" }
```

Bearer required. Stores `male`, `female`, `lgbtq`, or `other`. Returns
account state including `gender`.

### `POST /v1/me/profile`

```json
{
  "displayName": "Ada",
  "bio": "Hikes on Saturday.",
  "interests": ["Hiking", "Coffee", "Film"],
  "city": "Kathmandu",
  "gender": "female"
}
```

`displayName` is 2–30 letters. `bio` is optional, max 300 characters.
`interests` must be 3–8 values from the app list. `city` is one of
Kathmandu, Lalitpur, Bhaktapur, Pokhara, Biratnagar, Bharatpur, Dharan,
Nepalgunj. `gender` is `male`, `female`, `lgbtq`, or `other`. Older
`man` / `woman` / `nonBinary` / `transgender` values are still accepted
and stored as the matching new name.
Returns account state only (no bio/city/gender echo). Account JSON still
never includes `phone` or `birthDate`.

### `GET /v1/me/personal-info` / `PUT /v1/me/personal-info`

Bearer required. Extended Personal Information (appearance, lifestyle,
education, dating preferences, personality, prompts). Tables:
`user_profiles`, `user_lifestyles`, `user_preferences`,
`user_personalities`, `user_prompts`, `user_verifications`.

`PUT` merges fields. Never returns a full phone — only a masked
`phoneLabel`. Birth date is accepted once and never echoed as a full
private value beyond ISO date for the owner’s own GET.

## Discovery

Bearer required. Public profiles include age (from the private birth date),
city, gender, bio and interests. They never include phone, birth date, or
coordinates. Profile photos are signed relative paths on `photoUrls`.
Empty `photoUrls` means the app shows placeholders.
Distance is omitted until geo exists, so a client distance filter is ignored.
`verifiedOnly=true` returns an empty deck (no verification yet).

Extra swipes after the free male daily limit (20, Nepal calendar day
UTC+05:45) charge 10 paisa from the point wallet after confirm. Other
genders have no daily cap. Incomplete profiles get 5 preview swipes.
Female, LGBTQ+ and other accounts have every Premium feature at no charge.
Only male accounts can buy a subscription. Payments are not enabled yet.

Males without a paid subscription receive **100 promotional points once per
Nepal day** (`dailyFreePoints`). Super like (`direction: "super"`), discovery
direct message (`POST /v1/discovery/message`), and rewind
(`POST /v1/discovery/undo` with `confirmedPaid`) each cost **100 points** for
those males; the debit is credited to the seeded admin wallet
(`+9779800000000`). Complimentary accounts are not charged for those actions.

Development seeds eight demo profiles (`+9779811000001` … `0008`) so a new
database has a deck.

### `GET /v1/discovery/candidates`

The deck is filtered by the viewer’s gender: male accounts see female
and LGBTQ+ (including stored `transgender`); female, LGBTQ+ and other
accounts see male. `showMe` (`everyone` / `women` / `men`) can narrow
that further. Query: `minAge`, `maxAge`, `showMe`, `verifiedOnly`
(default false), `interests` (comma-separated). Response:

```json
{ "items": [ { "id": "...", "displayName": "Asha", "age": 28, "city": "Kathmandu", "bio": "", "interests": [], "isVerified": false, "isOnline": false, "photoCount": 0, "gender": "female", "photoUrls": [] } ] }
```

### `GET /v1/discovery/quota`

`SwipeQuotaDto`: `profileComplete`, `previewUsed`, `dailyUsed`,
`freeDailyLimit` (20 or null), `balancePaisa` (spendable points),
`pricePaisa` (10), `dayKey`, `resetsAt`.

### `POST /v1/discovery/swipes`

```json
{ "profileId": "...", "direction": "right", "confirmedPaid": false }
```

`direction` may be `left`, `right`, or `super`. Super likes count as likes for
matching and do not consume the free daily swipe quota.

`200` with `quota` (includes `actionPricePaisa`, normally 100), optional
`matchedProfile` and `conversationId` (match id) on a mutual like,
`chargedPaisa` (10 on a confirmed extra male swipe, 100 on a confirmed male
super like, else 0), optional `rejection`
(`profileIncomplete` / `insufficientFunds` / `paymentRequired`).
Undo refunds a paid extra swipe and, for unsubscribed males, charges the
rewind fee to admin when `confirmedPaid` is true.

### `POST /v1/discovery/message`

```json
{ "profileId": "...", "confirmedPaid": false }
```

Opens (or reuses) a match conversation with that profile. Unsubscribed males
pay 100 points to admin. `200` with `quota`, optional `conversationId`,
`chargedPaisa`, optional `rejection`.

### `POST /v1/discovery/undo`

Reverts the last swipe. `204` if there is nothing to undo. `200` with
`profile` and `quota` otherwise. A match created by that swipe is unmatched.

### `GET /v1/matches`

```json
{ "items": [ { "id": "...", "profile": { "...": "..." }, "matchedAt": "...", "isNew": true, "conversationId": "..." } ] }
```

`conversationId` is always the match id. Flutter uses it as the chat id.

## Likes, unmatch and block

Bearer required. Received likes are right-swipes toward you that you have not
answered. Sent likes are your unmatched right-swipes. A pair that has ever
matched (including unmatched) leaves both inboxes. Like-back and decline do
not use the daily swipe quota. Block hides the person both ways from
discovery, likes and matches.

Development seeds inbound likes from the first three demo profiles onto
completed non-demo accounts so the likes tab is not empty.

### `GET /v1/likes/received` / `GET /v1/likes/sent`

```json
{ "items": [ { "profile": { "...": "..." }, "likedAt": "..." } ] }
```

### `POST /v1/likes/{profileId}/back`

`200` `{ "match": { "...": "..." }, "created": true }`. `created` is false when
the match already existed. `404` if that inbound like is gone.

### `POST /v1/likes/{profileId}/decline`

`204`. Records a left swipe without using quota.

### `DELETE /v1/likes/sent/{profileId}`

`204`. Withdraws an unmatched sent like.

### `DELETE /v1/matches/{matchId}` / `POST /v1/matches/{matchId}/seen`

`204`. Unmatch keeps both people off each other's decks. Seen clears `isNew`
for the caller only.

### `GET /v1/blocks` / `POST /v1/blocks/{profileId}` / `DELETE /v1/blocks/{profileId}`

List, block (also unmatches), unblock. Blocked JSON is public profiles only.

## Chat

Bearer required. Conversation id is the match Guid. Empty threads are
omitted from the list (open them from a match). Unmatch or block returns
`404` with title/detail “This conversation has ended.” Empty text is
`empty` unless `imageId` is set. Image-only messages are valid. Men pay
10 paisa per eligible word from the point wallet after confirm; a photo
with no eligible words is free. Other genders send for free. Recipient
credits are not granted yet. Client `MessageQuote` is display-only.

Live updates use SignalR at `/v1/hubs/chat` (JWT as `access_token` query
or Bearer). The client `event` payload is `{ type, conversationId, message?, typing? }`
with `type` `message` | `typing` | `read` | `closed`. REST list/thread
stays the source of truth if the hub is down. `isTyping` on REST previews
is still false; typing is hub-only. Message JSON may include `imageUrl`.

### `GET /v1/chats`

```json
{ "items": [ { "id": "...", "profile": { "...": "..." }, "lastMessage": "Hello", "lastMessageAt": "...", "unreadCount": 1, "muted": false, "isTyping": false } ] }
```

`isTyping` on this REST payload stays false. Live typing uses the hub.

### `GET /v1/chats/{conversationId}/messages`

Oldest first.

```json
{ "items": [ { "id": "...", "text": "Hello", "isMine": true, "sentAt": "...", "delivery": "sent", "chargedPaisa": 0, "eligibleWordCount": 1, "imageUrl": null } ] }
```

`imageUrl` is a signed relative `/v1/media/{id}?e=&s=` path, or null.

Photo-only threads use lastMessage `"Photo"`.

### `POST /v1/chats/{conversationId}/photos`

Multipart field `file`. Same JPEG/PNG/WebP 5 MB rules as profile photos.
Does **not** count toward the six profile-album slots. Open chats only.
`200`:

```json
{ "id": "...", "url": "/v1/media/...?e=...&s=...", "sortOrder": 0 }
```

### `POST /v1/chats/{conversationId}/messages`

```json
{ "text": "Hello Asha", "confirmedPaid": false, "imageId": null }
```

`imageId` is a photo id returned by the chat upload. Empty `text` is
allowed when `imageId` is present. `imageId` must belong to the sender
and be a chat upload, not a profile album photo.

`confirmedPaid` is accepted for compatibility but is not required: eligible
word fees are charged on send when the wallet can cover them.

`200` `SendOutcome`: optional `message`, optional `rejection`
(`empty` / `tooLong` / `insufficientFunds`),
optional `quote`, `chargedPaisa`, `balancePaisa` after the send.

### `POST /v1/chats/{conversationId}/read` / `mute` / `hide`

`204`. Mute body: `{ "muted": true }`. Mute also marks the thread read.
Hide removes it from the list; the thread stays until unmatch/block.

### `GET /v1/hubs/chat` (SignalR)

Bearer or `access_token` query. Client method `Typing(conversationId, typing)`.
Server pushes `event` to the other person on send, typing, read, unmatch and
block.

## Notifications

Bearer required. In-app inbox only. Push is not in this slice. Items are
newest first, capped at 100. Bodies use display names only — never a phone
or birth date. A right swipe creates `like` for the other person. A mutual
match creates `match` for both. A recorded chat message creates `message`
for the recipient unless the thread is muted or an unread message
notification already exists for that conversation.

`type`: `match` | `like` | `message` | `system`.

### `GET /v1/notifications`

```json
{ "items": [ { "id": "...", "type": "match", "title": "New match", "body": "You and Asha liked each other.", "createdAt": "...", "isRead": false } ] }
```

### `POST /v1/notifications/{id}/read`

`204`. `404` if it is not yours.

### `POST /v1/notifications/read-all`

`204`.

## Wallet

Bearer required. 1 point = 1 paisa. Completed profiles receive 1,000
promotional welcome points once (not cash, not withdrawable, spendable
in-app). Extra male swipes and paid messages debit promotional points
first. Recipients of a paid message receive the same amount as earned
points (`messageReceived`).

Female, LGBTQ+ and other accounts may record a withdrawal of earned
points (minimum 500). Male accounts cannot. Promotional points never
count. Recording holds earned points on the ledger. Cancelling releases
the hold. Status is `recorded`, `cancelled` or `declined` — never paid.
`payoutsEnabled` is always `false` until a payout provider exists.
`isLive` is `true` for this contract. Nothing is sent to a bank.

### `GET /v1/wallet`

```json
{ "promotionalPoints": 1000, "earnedPoints": 0, "pendingWithdrawalPoints": 0 }
```

`pendingWithdrawalPoints` is the sum of open (`recorded`) holds.
`earnedPoints` is already net of those holds.

### `POST /v1/wallet/promo-codes/redeem`

```json
{ "code": "WELCOME100" }
```

`200` with `{ points, bucket, spendablePoints }`. One redemption per account
per code. Promotional bucket is not withdrawable.

### `GET /v1/wallet/transactions`

Newest first.

```json
{ "items": [ { "id": "...", "title": "Welcome bonus", "points": 1000, "occurredAt": "...", "bucket": "promotional", "kind": "welcomeBonus", "detail": "..." } ] }
```

`kind`: `welcomeBonus`, `swipeSpend`, `messageSpend`, `messageReceived`,
`withdrawalHold`, `withdrawalRelease`, `other`.
`bucket`: `promotional` or `earned`. `points` is signed.

### `GET /v1/wallet/transactions/{id}`

The same transaction object. `404` if it is gone.

### `GET /v1/wallet/withdrawals/eligibility`

```json
{
  "eligibleAccount": true,
  "earnedAvailable": 610,
  "minimumPoints": 500,
  "feePoints": 0,
  "canSubmit": true,
  "explanation": "...",
  "payoutsEnabled": false,
  "isLive": true
}
```

### `GET /v1/wallet/withdrawals`

Newest first.

```json
{ "items": [ { "id": "...", "points": 500, "feePoints": 0, "netPoints": 500, "status": "recorded", "createdAt": "...", "resolvedAt": null, "payoutsEnabled": false, "isLive": true } ] }
```

### `GET /v1/wallet/withdrawals/{id}`

The same withdrawal object. `404` if it is gone.

### `POST /v1/wallet/withdrawals`

```json
{ "points": 500, "confirmed": true }
```

`confirmed` must be `true` or the API returns `400`. Never marks the
request paid.

### `POST /v1/wallet/withdrawals/{id}/cancel`

Releases the earned hold. Returns the updated withdrawal. `400` if it is
no longer open.

## Referrals

Bearer required. Each completed profile gets a unique invite code. A friend
can send that code on `POST /v1/auth/verify` as `referralCode`, or claim it
later with `POST /v1/referrals/claim`. One invite per account. You cannot
use your own code.

Joining creates a **pending** NPR 10 (1000 paisa) commission. Approving or
paying it is not in this slice — there is no payment provider yet. The
client cannot mint an approved commission.

`inviteLink` is built from `Referral:InviteBaseUrl` when set. If that
setting is empty, the API returns `socialdating://invite/{code}` so the
app never compiles a website origin. JSON never includes a phone or
birth date. `payoutsEnabled` is always `false` until a payout provider
exists. `isLive` is `true` for this contract.

### `GET /v1/referrals`

```json
{
  "code": "K7M2NPQ4",
  "inviteLink": "socialdating://invite/K7M2NPQ4",
  "shareMessage": "Join me on Social Dating.\nsocialdating://invite/K7M2NPQ4\nUse code K7M2NPQ4 when you create an account.",
  "invitesSent": 1,
  "friendsJoined": 1,
  "qualifyingPurchases": 0,
  "pendingCommissionPaisa": 1000,
  "approvedCommissionPaisa": 0,
  "paidCommissionPaisa": 0,
  "reversedCommissionPaisa": 0,
  "creditsEarned": 0,
  "payoutsEnabled": false,
  "isLive": true,
  "allocation": {
    "purchasePaisa": 10000,
    "companyPaisa": 6000,
    "buyerRewardEquivalentPaisa": 3000,
    "referrerCommissionPaisa": 1000
  }
}
```

### `GET /v1/referrals/invites`

```json
{ "items": [ { "id": "...", "displayName": "Nabin", "status": "joined", "createdAt": "...", "detail": "..." } ] }
```

`status`: `joined` | `purchased` | `refunded`.

### `GET /v1/referrals/commissions` / `GET /v1/referrals/commissions/{id}`

```json
{ "items": [ { "id": "...", "inviteId": "...", "personName": "Nabin", "amountPaisa": 1000, "status": "pending", "createdAt": "...", "resolvedAt": null, "detail": "..." } ] }
```

`status`: `pending` | `approved` | `reversed` | `paid`.

### `POST /v1/referrals/claim`

```json
{ "code": "K7M2NPQ4" }
```

`204`. `400` if the code is missing, invalid, your own, or already used.

### `POST /v1/auth/verify` referral field

Optional `"referralCode"` on the existing verify body. Empty, omitted or
unknown codes are ignored so sign-in still succeeds. Use
`POST /v1/referrals/claim` when the person should see a validation error.

## Subscription

Bearer required. Female, LGBTQ+ and other accounts receive a complimentary
active membership (`complimentary: true`, plan id `included`). They do not
buy a subscription. Only male accounts can start checkout, and checkout is
still refused because no payment provider is connected. The API never
returns a succeeded purchase.

`paymentsEnabled` is always `false`. `isLive` is `true` for this contract.

### `GET /v1/subscription`

```json
{
  "needsPaidSubscription": false,
  "complimentary": true,
  "hasPremiumAccess": true,
  "paymentsEnabled": false,
  "isLive": true,
  "active": {
    "plan": {
      "id": "included",
      "name": "Included",
      "pricePaisa": 0,
      "periodLabel": "with your account",
      "features": ["See who likes you", "Unlimited likes", "Priority in discovery"],
      "isPopular": false,
      "savingsLabel": null,
      "isRecurring": false,
      "priceLabel": "Included"
    },
    "startedAt": "2026-10-29T06:00:00+00:00",
    "renewsAt": null,
    "cancelledAt": null,
    "referralLinked": false,
    "complimentary": true
  }
}
```

Male accounts have `needsPaidSubscription: true`, `complimentary: false`,
`hasPremiumAccess: false`, and `active: null` until a payment provider
exists.

### `GET /v1/subscription/plans`

Named Premium plan cards are removed. Male checkout is amount-only on the
client, so this list is empty until a payment provider defines SKUs.

```json
{ "items": [] }
```

### `GET /v1/subscription/history`

```json
{ "items": [] }
```

Purchases are not persisted. History stays empty until a payment provider
exists.

### `POST /v1/subscription/checkout`

```json
{ "planId": "npr-100", "referralLinked": false, "methodId": "card", "confirmed": true, "amountPaisa": 10000 }
```

Always `400`. Non-male accounts are told Premium is included. Male accounts
are told payments are not enabled. `confirmed` must be `true`. Never returns
`succeeded`.

## Photos

Bearer required except the signed media GET. JPEG, PNG or WebP, max 6
profile photos, 5 MB each. Chat uploads use the same types and size, the
same signed GET, and do not count toward the album. Files are stored on
the API host. `url` is a relative signed path
(`/v1/media/{id}?e={unix}&s={hmac}`) so `NetworkImage` does not need a Bearer
header. The HMAC uses the JWT signing key.

## Safety reports

Bearer required. Creates a row in the staff moderation queue.

### `POST /v1/safety/reports`

```json
{ "reportedAccountId": "...", "category": "Harassment", "details": "optional" }
```

`200` with `{ id, category, details, subjectName, reportedAccountId, createdAt }`.
Cannot report yourself or the system admin ledger account. `category` is
required (2–64 chars).

## Staff admin (`/v1/admin`)

Separate staff JWT (`typ=staff`). Not the phone OTP user flow. Development
bootstraps a superadmin when no staff exist (`Admin:BootstrapEmail` /
`BootstrapPassword` in appsettings).

### `POST /v1/admin/auth/login`

```json
{ "email": "admin@local.test", "password": "..." }
```

`200` with `{ accessToken, expiresAt, staff }`.

### Authenticated staff routes

All require `Authorization: Bearer` staff token.

**Soft RBAC** (claim `staff_role`):

| Role | Writes |
| --- | --- |
| `support` / `trust` | warn, reset swipe day, resolve reports (warn/dismiss/investigating; not ban/suspend) |
| `finance` | withdrawals, refunds, adjust points, clawbacks, complimentary Premium |
| `superadmin` | all writes + staff invite/reset/disable/role + ban/suspend/clear photos/unmatch |

Reads are available to every staff role.

| Method | Path | Notes |
| --- | --- | --- |
| GET | `/v1/admin/me` | Staff profile |
| GET | `/v1/admin/overview` | Live KPIs (24h activity, funnels, alerts, kill snapshot), admin wallet, Nepal day |
| GET | `/v1/admin/ops/overview` | Same as `/overview` |
| GET | `/v1/admin/marketplace/health` | Discoverable gender mix, deck-empty risk, 24h swipe/like/match funnel |
| GET | `/v1/admin/config` | Remote pricing + kill switches |
| PUT | `/v1/admin/config` | Superadmin — update pricing / kills (`AppRuntimeSettings`) |
| GET | `/v1/admin/moderation/photos?filter=` | Photo queue (`pending` / `approved` / `rejected` / `hidden` / `recent`) |
| POST | `/v1/admin/moderation/photos/{id}/visibility` | `{ hidden, note? }` support write — sets `Photo.HiddenAt` |
| POST | `/v1/admin/moderation/photos/{id}/review` | `{ status: pending\|approved\|rejected, reason?, note? }` — reject reasons: nudity/fake/underage/spam/other |
| GET | `/v1/admin/moderation/messages?q=` | Recent chat messages (optional body search) |
| POST | `/v1/admin/moderation/messages/{id}/visibility` | `{ hidden, note? }` support write — sets `Message.HiddenAt` |
| GET | `/v1/admin/queues/attention` | Work-queue home — counts + priority items (reports, payouts, refunds, photos, kills, fraud) |
| GET | `/v1/admin/payouts/run` | Recorded withdrawals batch with totals |
| POST | `/v1/admin/payouts/run/mark-paid` | Finance — `{ ids, expectedTotalPoints?, note? }` batch ops mark-paid with checksum |
| GET | `/v1/admin/revenue/today` | Nepal-day spend by wallet kind + adminReceive total |
| GET | `/v1/admin/fraud/signals` | Heuristic fraud desk (repeat reporters, swipe spam, referral rings, withdraw-then-restrict, multi-account device/IP) |
| GET | `/v1/admin/users/{id}/timeline` | Unified case timeline (audit, reports, withdrawals, refunds, notes, status) |
| POST | `/v1/admin/users/{id}/case-notes` | `{ body }` support write — staff case note |
| POST | `/v1/admin/users/{id}/shadow-ban` | `{ reason? }` soft ban — empty deck, muted chat send |
| POST | `/v1/admin/users/{id}/unshadow-ban` | Lift shadow ban |
| GET | `/v1/admin/users?q=&gender=&status=&city=&incomplete=` | Search + filters (`active`/`suspended`/`shadowBanned`/`banned`) |
| GET | `/v1/admin/config/history` | Pre-change config snapshots |
| POST | `/v1/admin/staff/{id}/revoke-sessions` | Superadmin — invalidate outstanding staff JWTs |
| GET | `/v1/admin/users/{id}` | User 360 (balances, photos, matches, swipe day, ledger) |
| POST | `/v1/admin/users/{id}/ban` | Soft-delete (`deletedAt`) |
| POST | `/v1/admin/users/{id}/unban` | Clear ban |
| POST | `/v1/admin/users/{id}/suspend` | Hide from discovery (`suspendedAt`) |
| POST | `/v1/admin/users/{id}/unsuspend` | Clear suspension |
| POST | `/v1/admin/users/{id}/warn` | Sets `lastWarnedAt` + audit |
| POST | `/v1/admin/users/{id}/clear-photos` | Deletes profile photos |
| POST | `/v1/admin/users/{id}/unmatch-all` | Ends active matches |
| POST | `/v1/admin/users/{id}/reset-swipe-day` | Zeros today Nepal-day counters |
| POST | `/v1/admin/users/{id}/refund-charge` | `{ sourceId, note? }` — below dual-control threshold refunds immediately; at/above queues for second staff |
| POST | `/v1/admin/users/{id}/adjust-points` | `{ points, bucket: promotional\|earned, title, detail? }` |
| POST | `/v1/admin/users/{id}/complimentary-premium` | `{ enabled }` staff override for male Premium |
| GET | `/v1/admin/ledger/admin` | Platform wallet ledger |
| GET | `/v1/admin/withdrawals?status=` | Includes eligibility snapshot + `statusLabel` |
| GET | `/v1/admin/withdrawals/export.csv?status=` | CSV export for payout desk |
| POST | `/v1/admin/withdrawals/{id}/resolve` | `{ decision: decline\|markPaid, note? }` |
| GET | `/v1/admin/refunds?status=` | Dual-control refund queue |
| POST | `/v1/admin/refunds/{id}/resolve` | `{ decision: approve\|reject, note? }` — must be a different staff than requester |
| GET | `/v1/admin/referrals/invites` | Referral invite list |
| GET | `/v1/admin/referrals/commissions?status=` | Commission list |
| POST | `/v1/admin/referrals/commissions/{id}/clawback` | `{ note? }` marks commission reversed |
| GET | `/v1/admin/grants/daily-free?dayKey=` | Nepal-day free points recipients |
| GET | `/v1/admin/subscriptions/overview` | Counts; payments still disabled |
| GET | `/v1/admin/reports?status=&sla=&claim=` | Moderation queue — `sla`=`overdue`/`due_soon`/`ok`/`closed`; `claim`=`unclaimed`/`mine`/`claimed`; items include claim + SLA fields |
| POST | `/v1/admin/reports/{id}/claim` | Support — claim open report (sets investigating) |
| POST | `/v1/admin/reports/{id}/unclaim` | Support — release claim (owner or superadmin) |
| POST | `/v1/admin/reports/{id}/resolve` | `{ status, note?, moderationAction? }` — status `investigating`/`actioned`/`dismissed`; action `warn`/`suspend`/`ban`/`none`; notifies reporter (and reported on warn/suspend/ban) |
| GET | `/v1/admin/users/export.csv` | Same filters as user list — CSV export |
| GET | `/v1/admin/moderation/keyword-hits?status=` | Chat keyword flag queue |
| POST | `/v1/admin/moderation/keyword-hits/{id}/resolve` | Support — `{ decision: dismiss\|actioned, note? }` |
| GET | `/v1/admin/watchlist` | Current staff watchlist |
| POST | `/v1/admin/users/{id}/watch` | Support — `{ note? }` |
| POST | `/v1/admin/users/{id}/unwatch` | Support — remove from watchlist |
| GET | `/v1/admin/users/{id}/case-packet` | Read-only trust dossier for an account |
| GET | `/v1/admin/users/{id}/linked-accounts` | Accounts sharing device/IP (90d refresh tokens) |
| GET | `/v1/admin/auth-blocks?active=` | Device/IP auth blocklist |
| POST | `/v1/admin/auth-blocks` | Support — `{ kind: device\|ip, value, reason? }` |
| POST | `/v1/admin/auth-blocks/{id}/clear` | Support — deactivate a block |
| GET | `/v1/admin/users/{id}/export.json` | Compliance package (profile, wallet, photos metadata, reports, recent ledger) |
| POST | `/v1/admin/users/{id}/erase` | Superadmin — `{ confirm: true, reason? }` bans + scrubs PII, hides photos, revokes sessions |
| GET | `/v1/admin/appeals?status=&sla=` | Restriction appeal queue (SLA clocks like reports) |
| POST | `/v1/admin/users/{id}/appeals` | Support — `{ body, kind? }` file appeal on behalf of user |
| POST | `/v1/admin/appeals/{id}/resolve` | Support — `{ decision: accept\|reject, note? }` (accepting a ban requires superadmin) |
| POST | `/v1/me/appeals` | User — `{ body, kind? }` when suspended / shadow-banned / banned |
| GET | `/v1/app/client-config` | Anonymous — maintenance, min build, optional banner |
| POST | `/v1/admin/users/{id}/force-logout` | Support — revoke all refresh tokens for the account |
| POST | `/v1/admin/moderation/photos/bulk-review` | Support — `{ ids, status: approved\|rejected, reason?, note? }` (max 100) |
| GET | `/v1/admin/staff/activity` | Nepal-day + 7d staff audit activity snapshot |
| GET | `/v1/admin/audit?q=&action=&staffEmail=` | Staff action log (filters) |
| GET | `/v1/admin/audit/export.csv` | Same filters — CSV export |
| GET | `/v1/admin/promos` | Promo code list |
| POST | `/v1/admin/promos` | Finance — create `{ code, points, bucket?, maxRedemptions?, expiresAt? }` |
| POST | `/v1/admin/promos/{id}/active` | Finance — `{ active }` |
| POST | `/v1/admin/broadcast` | Support — `{ title, body, gender?, city?, incompleteOnly }` system inbox segment (cap 5000) |
| GET | `/v1/admin/staff` | List staff (any role can read) |
| POST | `/v1/admin/staff` | Invite — `{ email, displayName, role, temporaryPassword }` (superadmin) |
| POST | `/v1/admin/staff/{id}/reset-password` | `{ temporaryPassword }` (superadmin) |
| POST | `/v1/admin/staff/{id}/disable` | Superadmin; cannot disable last superadmin or self |
| POST | `/v1/admin/staff/{id}/enable` | Superadmin |
| POST | `/v1/admin/staff/{id}/role` | `{ role }` (superadmin) |

Bootstrap (`Admin:Bootstrap*`) only seeds the first staff user when the table
is empty. Ongoing accounts are managed via `/v1/admin/staff`.

Withdrawal `markPaid` is an ops marker only — the API never sends money to a
bank. Points UI should stay labeled as points / stated NPR.

`Admin:RefundDualControlThresholdPoints` (default `500`) controls when refunds
need a second staff approval.

**Runtime config / kills** (`AppRuntimeSettings`, single row): prices for premium
actions, extra swipes, male daily free points / free swipe quota, min withdrawal;
boolean kills for discovery, chat messaging, premium `ChargeToAdmin`, withdrawals,
and referrals. Consumers read live values — flips take effect on the next request
without a deploy. Hidden photos/messages are omitted from user album and
conversation fetches.

**Trust / fraud (Phase 4):** `Account.ShadowBannedAt` empties the discovery
deck and blocks chat send while keeping login. Profile photos use
`ReviewStatus` (`pending`/`approved`/`rejected`); discovery albums only show
`approved`. New profile uploads start `pending`; existing rows migrate to
`approved`.

**Sessions / multi-account:** `/v1/auth/verify` and `/refresh` store
`RefreshToken.IpAddress`, optional `DeviceId` (`X-Device-Id` header), and
`UserAgent`. Fraud desk flags shared device (≥3 accounts / 7d) and shared IP
(≥5 accounts / 7d).

**Payout run:** batch mark-paid is an ops marker only — the API never sends
money to a bank. `expectedTotalPoints` rejects the batch on checksum mismatch.

**Growth:** Flutter clients send `X-Device-Id` (stable install id). Marketplace
health includes per-city discoverable mix. Promo codes and staff broadcast land
in the in-app notification inbox (`type=system`).

**Staff sessions:** `StaffUser.TokensValidAfter` is bumped on password reset,
disable, role change, and explicit revoke. JWT bearer validation rejects staff
tokens issued at or before that instant (requires `iat` / `nbf` on the token).
Config saves append `AppConfigRevision` snapshots (history is the state
*before* each change).

**Trust SLA / compliance (Phase 8):** Open and investigating reports are due
after `Admin:ReportSlaHours` (default 24) with a `due_soon` warn at
`Admin:ReportSlaWarnHours` (default 18). Attention queue surfaces overdue
counts. User `export.json` is a staff download of account data; `erase` is a
destructive scrub (ops marker — not a legal guarantee of byte deletion from
object storage backups).

**Appeals / client ops (Phase 9):** `ModerationAppeal` covers ban / suspend /
shadowBan with `Admin:AppealSlaHours` (default 48). Accept lifts the matching
restriction. `AppRuntimeSettings` also stores `maintenanceMode`,
`minClientBuild`, and an optional in-app banner exposed at
`/v1/app/client-config`.

**Desk ops (Phase 10):** Force-logout revokes refresh tokens only (access JWTs
expire on TTL). Bulk photo review audits each id. Staff activity aggregates
`AdminAuditEvent` for the Nepal day. `/v1/me` includes optional
`restrictionStatus` (`suspended` / `shadowBanned` / `banned`).

**Case ownership / notify (Phase 11):** Reports can be claimed by support staff.
Resolve/dismiss and appeal accept/reject send in-app `system` inbox messages.
Staff `lastLoginAt` updates on login (audit `staff.login`). Users CSV export
mirrors list filters.

**Keywords / watch / case packet (Phase 12):** `AppRuntimeSettings.chatKeywordList`
(comma-separated) flags matching chat sends into `ChatKeywordHit` for review.
Staff can watch accounts (`/v1/admin/watchlist`). `GET .../case-packet` returns
a read-only trust dossier (reports, appeals, keyword hits, notes, counters).

**Linked accounts / auth blocks (Phase 13):** `GET .../linked-accounts` clusters
accounts that shared a device id or IP on refresh tokens (90 days). Active
`AuthBlockEntry` rows (`device` / `ip`) deny OTP verify and refresh with `403`.

### `GET /v1/me/photos`

```json
{ "items": [ { "id": "...", "url": "/v1/media/...?e=...&s=...", "sortOrder": 0 } ] }
```

### `POST /v1/me/photos`

Multipart field `file`. `200` with the new photo object.

### `PATCH /v1/me/photos/order`

```json
{ "ids": ["...", "..."] }
```

`204`. Send every photo id exactly once.

### `DELETE /v1/me/photos/{id}`

`204`.

### `GET /v1/media/{id}?e={unix}&s={hmac}`

Anonymous. Returns image bytes, or `404` if the signature is wrong, expired,
or the photo is gone. Flutter prefixes the relative path with `API_BASE_URL`.

Public profiles on discovery, likes, matches and chat include `photoUrls` and
`photoCount` for that person’s photos.

## Account

### `DELETE /v1/me`

Soft-deletes the account and revokes refresh tokens.

### `GET /health`

`{ "status": "ok" }` — no auth.
