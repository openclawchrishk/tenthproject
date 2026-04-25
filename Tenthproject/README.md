# Tenthproject.com（Web）

Next.js 14 App Router + Tailwind + Supabase + Stripe。與上層目錄 **DeskerHK** iOS 應用**共用同一 Supabase 專案**（`desks`、`desk_roles`、`desk_applications`、`desk_members`、`users` 等）。

## 快速開始

```bash
cd Tenthproject
cp .env.example .env.local
# 填入 Supabase 與（可選）Stripe 變數
npm install
npm run dev
```

## 資料庫

1. 既有 DeskerHK schema 無需改動即可列出／建立 `desks`、申請 `desk_applications`。
2. Web 專用表與欄位請執行：`supabase/migrations/001_tenthproject_web.sql`（Supabase SQL Editor）。

## 指令

- `npm run dev` — 開發
- `npm run build` — 正式建置（CI／Vercel）
- `npm run start` — 正式伺服器
- `npm run lint` — ESLint

## 部署

建議 Vercel；設定與 `.env.example` 相同之環境變數，並於 Stripe Dashboard 設定 Webhook 指向 `/api/stripe/webhook`。
