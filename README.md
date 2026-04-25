# Tenthproject monorepo（本倉庫）

此 Git 倉庫遠端名為 `tenthproject`，包含：

| 子專案 | 說明 |
|--------|------|
| **DeskerHK** | iOS 應用（SwiftUI + Supabase） |
| **Tenthproject** | tenthproject.com 官網（Next.js 14 + Supabase + Stripe）— 與 iOS **共用同一 Supabase 資料庫** |

官網說明與建置請見 [`Tenthproject/README.md`](Tenthproject/README.md)。

---

# DeskerHK 🇭🇰

> Hong Kong & Greater Bay Area startup matching — iOS app (SwiftUI + Supabase)

[![Swift Version](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue)](https://developer.apple.com/ios/)

---

## Final feature list (v1.0.0)

### Authentication

- Email sign-in and registration (Supabase Auth)
- Forgot password (reset email)
- Sign in with Apple (configured in Supabase + Apple Developer)
- Phone OTP login (where enabled in Supabase)
- Session persistence via Supabase session refresh
- Sign-out clears local profile/session state (see `AuthRepository`)

### Onboarding

- Role selection → basic info → skills & needs
- Completion celebration and first-time app tutorial (UX preferences)

### Explore

- Desk and founder discovery; cards and filters
- Search: project name, pitch, industries, **founder display name**
- Pull-to-refresh; offline fallback to cached desk list
- Connection invite flow from Explore

### Desk

- Multi-step creation wizard; detail view; apply flow
- Members view; founder actions; share (public links)

### Messages

- Conversations, DMs, notifications, desk invites, connections (tab segments)
- Push notification hooks (configure device + Supabase)

### Profile

- View/edit profile, completeness, premium upgrade sheet
- IG card export; share profile
- Verification badges where applicable

### System

- Deep links (`desker.hk` / custom URL scheme — see `DeepLinkHandler`)
- Connectivity banner; offline DM queue; critical data cache
- Haptics (`HapticFeedback`); design system animations

---

## Setup

### Requirements

- Xcode 15+ (iOS 17 SDK)
- Swift 5.9+
- A [Supabase](https://supabase.com) project

### 1. Create a Supabase project

1. Create a project at [supabase.com](https://supabase.com).
2. In **Settings → API**, copy **Project URL** and the **anon (public) key**.

### 2. Run database schema

In the Supabase **SQL Editor**, run (in order):

| File | Purpose |
|------|---------|
| `SUPABASE_SCHEMA.sql` | Core tables, RLS, indexes, storage, realtime |
| `SUPPLEMENTAL_SCHEMA.sql` | Additional migrations (if present in repo) |

Optional reset (destructive): `FRESH_START.sql` — **dev only**.

### 3. Configure authentication providers

In **Authentication → Providers**:

- Enable **Email** (required for email login/register).
- Enable **Phone** if you use SMS OTP.
- Configure **Apple** (Services ID, key, bundle ID) for Sign in with Apple.
- Optional: Google OAuth.

### 4. Environment variables

Configure the app **without** hardcoding secrets in source for production:

**Option A — Xcode scheme (recommended for local runs)**

1. **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**
2. Add:

| Name | Value |
|------|--------|
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | Project anon public key |

(`SUPABASE_KEY` is accepted as an alias for `SUPABASE_ANON_KEY`.)

**Option B — shell / CI**

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-public-key"
```

`SupabaseManager` reads these at launch. If both URL and key are missing, a **development fallback** URL/key embedded in `Repositories/SupabaseManager.swift` is used so the package can build; **replace with env vars or your own project for production/stores.**

### 5. Open the app

**Swift Package (library + previews):**

```bash
cd /path/to/DeskerHK
swift build
```

**Full iOS app:** open the Xcode project if your repo includes `DeskerHK.xcodeproj` / workspace:

```bash
open DeskerHK.xcodeproj
```

Or **File → Open** the `DeskerHK` folder in Xcode.

---

## Build instructions

```bash
cd ~/Documents/trae_projects/tenthproject/DeskerHK
swift build
```

Expect **zero errors**. For a clean resolve:

```bash
rm -rf .build
swift package resolve
swift build
```

---

## Deployment guide (TestFlight / App Store)

1. **Secrets:** Use Xcode scheme or CI env for `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Do not ship unintended placeholder keys; rotate keys if they were ever committed.
2. **Capabilities:** Sign in with Apple, Push Notifications, Associated Domains (for universal links), Background Modes if you use background refresh.
3. **Supabase:** Production project with RLS enabled; email templates and redirect URLs set for auth.
4. **App Store Connect:** Create app record, upload builds via Xcode Organizer or CI, complete privacy labels, export compliance, and review notes (test accounts).
5. **TestFlight:** Internal testing first, then external beta; verify auth, deep links, and push on real devices.

---

## Project layout

```
DeskerHK/
├── App/                    # SwiftUI @main (Xcode app target)
├── Models/
├── Repositories/           # Supabase (see SupabaseManager.swift)
├── ViewModels/
├── Views/
├── Resources/              # Design system, assets
├── Services/               # Analytics, push, deep links, cache, IG export
├── SUPABASE_SCHEMA.sql
├── SUPPLEMENTAL_SCHEMA.sql (optional)
├── FRESH_START.sql         # Dev reset
└── Package.swift           # Swift Package for DeskerHK library
```

---

## Database tables (overview)

| Table | Role |
|-------|------|
| `users` | Profile rows (extends auth) |
| `desks`, `desk_roles`, `desk_applications`, `desk_members` | Desk lifecycle |
| `desk_messages` | Group chat |
| `connections`, `connection_invites` | Networking |
| `conversations`, `direct_messages` | DM |
| `notifications` | In-app + push payloads |
| `reports`, `blocked_users` | Safety |
| `referrals` | Referral tracking |

---

## Design system

See `Resources/DesignSystem.swift` for colors, spacing, shadows, and motion tokens.

---

## Troubleshooting

| Issue | What to check |
|--------|----------------|
| Build fails | `rm -rf .build`, `swift package resolve`, Xcode clean folder |
| Supabase errors | `SUPABASE_URL` / key, RLS policies, table names vs schema |
| Auth redirect | Supabase URL configuration and app scheme / universal links |

---

## License

Private — DeskerHK Project
