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

`200` with `quota`, optional `matchedProfile` on a mutual like, `chargedPaisa`
(10 on a confirmed extra male swipe, else 0), optional `rejection`
(`profileIncomplete` / `insufficientFunds` / `paymentRequired`).
Undo refunds a paid extra swipe.

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

`200` `SendOutcome`: optional `message`, optional `rejection`
(`empty` / `tooLong` / `paymentRequired` / `insufficientFunds`),
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

```json
{ "items": [ { "id": "npr-100", "name": "Premium", "pricePaisa": 10000, "periodLabel": "one-time", "features": ["See who likes you"], "isPopular": true, "savingsLabel": null, "isRecurring": false, "priceLabel": "NPR 100.00" } ] }
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
header. The HMAC uses the JWT signing key. There is no moderation queue yet.

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
