# Social Dating — staff admin

Next.js console for `/v1/admin` on the ASP.NET API. Local ops only; not end-user facing.

## Prerequisites

1. API running in Development on `http://localhost:5088`
2. Database migrated (includes staff / audit / reports tables):

```powershell
cd "..\backend\src\SocialDating.Api"
dotnet ef database update
dotnet run --launch-profile http
```

On first API start with no staff users, Development bootstraps:

- Email: `admin@local.test`
- Password: `ChangeMeNow1`

Change these in `appsettings.Development.json` (`Admin` section) before anything non-local.

## Run

```powershell
cd admin
copy .env.example .env.local
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) → sign in → Overview / Users / Admin ledger / Withdrawals / Reports / Audit.

`NEXT_PUBLIC_API_BASE_URL` must match the API origin. Localhost CORS is allowed by the API when `Cors:AllowLocalhost` is true (default).

## Phase 1 + 2 coverage

| Screen | API |
| --- | --- |
| Login | `POST /v1/admin/auth/login` |
| Overview | `GET /v1/admin/overview` |
| Users + 360 | moderation force actions, refund (dual-control), complimentary Premium |
| Admin ledger | `GET /v1/admin/ledger/admin` |
| Withdrawals | eligibility snapshot, CSV export, ops-paid labeling |
| Refunds | second-staff approve/reject queue |
| Referrals | invites, commissions, clawback |
| Daily grants | Nepal-day free points inspector |
| Subscriptions | overview stub (payments off) + per-user complimentary grant |
| Reports / Audit | Phase 1 |

Staff JWT uses claim `typ=staff` plus `staff_role` soft RBAC (`support` /
`finance` / `superadmin`). Superadmins manage staff under **Staff** (invite,
reset password, disable/role). Bootstrap only seeds the first account.

See `backend/CONTRACT.md` (Safety reports + Staff admin).
