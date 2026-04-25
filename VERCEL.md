# Deploying to Vercel

The Next.js site lives in **`Tenthproject/`** (this repo also contains the iOS app at the root).

## Fix for `404: NOT_FOUND` (edge `NOT_FOUND`)

Vercel’s Next.js output must include a **`.next` folder at the project root** Vercel uses for that deployment. If the repo root is the Vercel project root but `next build` only writes **`Tenthproject/.next`**, the deployment can succeed in logs yet serve **platform `NOT_FOUND`** for every URL.

This repo fixes that in two compatible ways:

### Option A (default): Root workspace + post-build staging

At the **repository root**, `npm run build`:

1. Runs `next build` in the **`tenthproject`** workspace (`Tenthproject/.next`).
2. Runs **`npm run stage:vercel`**, which copies **`Tenthproject/.next` → `./.next`** and **`Tenthproject/next.config.mjs` → `./next.config.mjs`** (and `public/` if present) so Vercel sees a normal Next layout at the project root.

**Vercel settings:** leave **Root Directory** empty (repo root). **Install Command** default (`npm install`). **Build Command** default (`npm run build`). **Output Directory** default (empty).

After changing this, trigger a **new Production deployment** (Redeploy).

### Option B: Vercel “Root Directory” = `Tenthproject`

**Settings → General → Root Directory** → **`Tenthproject`**. Then Vercel builds from `Tenthproject/package.json` and `.next` is already in the correct place; you do **not** need the root staging step for that project (default `next build` there is enough).

Use **either** root build with staging **or** Root Directory `Tenthproject` — do not point Root Directory at `Tenthproject` while also forcing a root-only build that never runs `next build` inside `Tenthproject`.

## Environment variables

Match **`Tenthproject/.env.example`** in **Vercel → Project → Settings → Environment Variables** (at least `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`, plus `NEXT_PUBLIC_SITE_URL` for your production URL).

## Custom domain

Point DNS at the Vercel project. No `basePath` is set in Next.js unless you add one.
