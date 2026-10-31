# Social Dating API

ASP.NET Core 9 + PostgreSQL (Neon). Auth, profile completion, public
profiles, discovery, likes, matches, unmatch, block, text chat, live
chat (SignalR), chat photos, an in-app notification inbox, a point wallet,
profile photos and direct referrals.

Debug `flutter run` keeps using mocks until dart-defines point at this host.

## Run

```bash
cd backend/src/SocialDating.Api
dotnet user-secrets set "ConnectionStrings:Database" "<neon connection string>"
dotnet user-secrets set "Jwt:SigningKey" "<at least 32 random characters>"
dotnet ef database update
dotnet run
```

Health: `GET http://localhost:5088/health`

Request a code, then read the OTP from the Development log (`DEV OTP for ...`).

See [CONTRACT.md](CONTRACT.md) for JSON.

## Rules this API already enforces

- Phone is E.164 and never appears on account JSON.
- Birth date is stored privately and never returned. Only `isAgeEligible` is on account JSON.
- Bio (optional, 300 chars), 3–8 listed interests, city and gender are stored on profile completion.
- Discovery filters on the server. Extra male swipes charge 10 paisa from promotional points after confirm.
- Like-back and decline do not use the daily swipe quota. Block hides both ways.
- Chat conversation id is the match id. Men are charged 10 paisa per eligible word from the same wallet.
- SignalR `/v1/hubs/chat` pushes new messages, typing, read and closed chats. REST polling still works if the hub is down.
- Completed profiles receive 1,000 promotional welcome points once. Not cash.
- Recipients of a paid message receive earned points. Female, LGBTQ+ and other accounts may record a withdrawal of at least 500 earned points. Holds are never paid.
- Profile photos (JPEG/PNG/WebP, max 6, 5 MB) are stored on disk and served from signed `/v1/media` URLs. Chat photos use the same store and are not counted in the album.
- In-app notifications for likes, matches, messages and referral joins. Push is not sent.
- Unique invite codes, one attribution per account, pending NPR 10 commissions. Payouts are not sent.
- OTP is hashed at rest (HMAC-SHA256 with a per-challenge salt).
- Refresh tokens are hashed. Access tokens last 15 minutes.
- Production must keep `Auth:LogOtps` false and plug in a real SMS sender.

## Not in this slice

SMS provider, geo, card top-up, push, CDN, moderation, subscription
payments, referral payouts, withdrawal payouts. Production must keep
`Auth:LogOtps` false. User-secrets are Development-only; Production reads
`ConnectionStrings__Database` and `Jwt__SigningKey` from the environment.

```bash
# Local production-shaped API (copies user-secrets into process env vars)
pwsh scripts/run_api_production.ps1
```
