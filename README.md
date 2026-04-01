# DeskerHK 🇭🇰

> 香港 & 大灣區創業撮合 iOS 應用程式

[![Swift Version](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue)](https://developer.apple.com/ios/)

---

## 🚀 快速開始

### 1. 創建 Supabase 專案

1. 前往 [supabase.com](https://supabase.com) 創建新專案
2. 複製 **Project URL** 和 **anon/public key**（Settings → API）

### 2. 運行數據庫 Schema

在 Supabase SQL Editor 運行以下檔案：

```
SUPABASE_SCHEMA.sql
```

這會創建：
- 14 個數據表（users, desks, connections, notifications 等）
- Row Level Security (RLS) 策略
- 索引優化
- Storage buckets（avatars, verification_docs）
- Realtime 訂閱
- 視圖和觸發器

### 3. 設置環境變量

```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key
```

或在 Xcode 中新增 `SupabaseManager.swift` 中的 FATAL 注釋位置填入你的 credentials。

### 4. 在 Xcode 中打開項目

```bash
open DeskerHK.xcodeproj
```

或使用 Xcode：「File → Open」選擇 `DeskerHK/` 文件夾

> **注意**：需要 Xcode 15+ 和 iOS 17+ SDK

### 5. 運行 App

1. 選擇 iPhone 模擬器或真機
2. 按 ⌘+R 編譯並運行

---

## Supabase 正式環境設定（上線前）

### 必做設定

1. 在 [supabase.com](https://supabase.com) 建立專案（或使用既有專案）。
2. 在 **SQL Editor** 執行根目錄的 `SUPABASE_SCHEMA.sql`，建立表、RLS、索引與 Storage。
3. 在 **Authentication → Providers** 啟用 **Email**（登入／註冊所需）。
4. 在 **Settings → API** 取得 **Project URL** 與 **anon public key**，並寫入 App（見下方環境變量）。
5. （可選）在 Authentication 設定 **Google** OAuth。
6. （可選）在 Authentication 與 Apple Developer 後台設定 **Sign in with Apple**。

### 環境變量

本機或 CI 可透過環境變量注入；Xcode Scheme 亦可設定同名變量：

```
SUPABASE_URL=your-project-url
SUPABASE_ANON_KEY=your-anon-key
```

### 資料庫遷移

- 首次：**執行 `SUPABASE_SCHEMA.sql`**。
- 之後：若有補充 migration 檔，依序在 SQL Editor 執行（勿略過順序）。

---

## 📱 功能一覽

### Phase 1 MVP ✅

- [x] **用戶系統** — 登入/註冊（Apple Sign-In + 手機）
- [x] **Profile** — 完整資料、行業標籤、技能、需求
- [x] **用戶等級** — Level 1-4，Premium 會員
- [x] **Explore** — 探索用戶和 Desk，發送邀請
- [x] **Desk 系統** — 創建/申請/審核，完整流程
- [x] **Connection** — 雙向連接，成為人脈
- [x] **DM** — 即時私訊
- [x] **Desk 群聊** — 項目群組聊天
- [x] **通知系統** — 各類事件通知
- [x] **官方認證** — 投資者/專家徽章
- [x] **舉報/Block** — 安全機制
- [x] **分享連結** — desker.hk/desk/{id}, desker.hk/u/{username}
- [x] **IG 卡片匯出** — 1080×1350 宣傳圖
- [x] **邀請好友** — Referral 系統

---

## 🏗️ 項目結構

```
DeskerHK/
├── App/                    # App entry point
├── Models/                 # 數據模型（User, Desk, Connection 等）
├── Repositories/           # 數據層（Supabase 交互）
├── ViewModels/             # SwiftUI ViewModels
├── Views/                  # SwiftUI 視圖
│   ├── Components/          # 可复用 UI 組件
│   ├── Desk/               # Desk 相關頁面
│   ├── Explore/            # Explore 頁面
│   ├── Messages/           # 訊息、私訊、通知
│   ├── Onboarding/         # 引導流程
│   └── Profile/            # 個人資料
├── Resources/              # 資源（DesignSystem, 圖片）
├── Services/               # 服務（IG Card Export 等）
├── Coordinators/           # 導航協調
├── SUPABASE_SCHEMA.sql     # 完整數據庫 Schema
└── FRESH_START.sql         # 刪除所有數據（Reset DB）
```

---

## 🗄️ 數據表

| Table | 說明 |
|-------|------|
| `users` | 用戶資料（擴展 auth.users） |
| `desks` | Desk 項目 |
| `desk_roles` | Desk 招募角色 |
| `desk_applications` | 申請記錄 |
| `desk_members` | 已加入成員 |
| `desk_messages` | 群組聊天訊息 |
| `connections` | 已建立的人脈 |
| `connection_invites` | 邀請待處理 |
| `conversations` | DM 對話 |
| `direct_messages` | DM 訊息 |
| `notifications` | 通知 |
| `reports` | 舉報 |
| `blocked_users` | 黑名單 |
| `referrals` | 邀請記錄 |

---

## ⚙️ 開發

### 編譯檢查

```bash
swift build
```

### 更新依賴

```bash
swift package update
```

### Reset 數據庫

在 Supabase SQL Editor 運行 `FRESH_START.sql` 刪除所有數據。

---

## 🎨 設計系統

顏色（見 `Resources/DesignSystem.swift`）：

| 顏色 | Hex | 用途 |
|------|-----|------|
| Primary | `#007AFF` | 主要 CTA、按鈕 |
| Secondary | `#5856D6` | 次要強調 |
| Background | `#F2F2F7` | 頁面背景 |
| Card | `#FFFFFF` | 卡片背景 |
| Text Primary | `#000000` | 主要文字 |
| Text Secondary | `#8E8E93` | 次要文字 |
| Success | `#34C759` | 成功狀態 |
| Error | `#FF3B30` | 錯誤狀態 |

---

## 🔧 常見問題

### Q: Build 失敗？
```bash
rm -rf .build
swift build
```

### Q: Supabase 連接失敗？
檢查 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 是否正確

### Q: 找不到 .xcodeproj？
這是 Swift Package，需在 Xcode 中 Open Folder 或使用 Xcode Cloud

---

## 📄 License

Private — DeskerHK Project
