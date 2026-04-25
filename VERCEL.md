# Deploying to Vercel

This repo is a **monorepo**: the Next.js site lives in **`Tenthproject/`**, while the iOS app lives at the repo root.

## Fix for `404: NOT_FOUND`

Vercel must build the Next app from the workspace root.

### Option A (recommended): Root `package.json` + workspaces

The repository root now includes `package.json` with:

```json
"workspaces": ["Tenthproject"]
```

Vercel’s default **`npm install`** and **`npm run build`** at the **repository root** will install dependencies and run `next build` inside the workspace. **Redeploy** after pulling the latest `master`.

### Option B: Vercel “Root Directory”

In the Vercel project: **Settings → General → Root Directory** → set to **`Tenthproject`**, then redeploy. (You do not need both A and B; A alone is enough.)

## Environment variables

Set the same variables as `Tenthproject/.env.example` in **Vercel → Project → Settings → Environment Variables** (at least `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`).

## Custom domain

Point your domain to the Vercel project; no extra `basePath` is configured in Next.js.
