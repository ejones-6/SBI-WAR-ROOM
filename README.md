# StoneBridge War Room — Next.js

Real estate acquisitions tracking platform. Next.js 14 + Supabase + Vercel.

---

## 🚀 Deploy in 5 steps

### Step 1 — Run the Supabase migration

1. Go to **https://supabase.com/dashboard/project/basvpojiaycrrbalivrz**
2. Click **SQL Editor** in the left sidebar
3. Click **New Query**
4. Open the file `supabase_migration.sql` from this repo (it's large — ~950KB with all 2,009 deals)
5. Paste it all into the SQL editor
6. Click **Run** — wait ~30 seconds
7. Go to **Table Editor** and verify you see `deals`, `boe_data`, `cap_rates`, `user_profiles` tables with data

### Step 2 — Push code to GitHub

```bash
cd sbi-war-room
git init
git add .
git commit -m "Initial SBI War Room"
git remote add origin https://github.com/ejones-6/SBI-WAR-ROOM.git
git push -u origin main
```

### Step 3 — Connect Vercel

1. Go to **https://vercel.com/new**
2. Click **Import Git Repository**
3. Select `ejones-6/SBI-WAR-ROOM`
4. Framework: **Next.js** (auto-detected)
5. Add these **Environment Variables**:
   ```
   NEXT_PUBLIC_SUPABASE_URL = https://basvpojiaycrrbalivrz.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY = sb_publishable_cYyun0vpOqDGdZqAqJgGMw_Px6VHf-x
   ```
6. Click **Deploy** — takes ~2 minutes

### Step 4 — Create user accounts

1. In Supabase dashboard → **Authentication** → **Users** → **Add User**
2. Create accounts for each team member (email + password)
3. They log in at your Vercel URL (e.g. `https://sbi-war-room.vercel.app/login`)

### Step 5 — Enable Realtime (optional but recommended)

1. Supabase dashboard → **Database** → **Replication**
2. Enable replication for: `deals`, `boe_data`, `cap_rates`
3. Now when any team member updates a deal, everyone sees it live instantly

---

## Local Development

```bash
npm install
npm run dev
# open http://localhost:3000
```

---

## Architecture

```
app/
  login/         — Supabase auth login page
  dashboard/     — Protected route; server-fetches all data
  api/
    deals/       — PATCH/POST deals
    boe/         — GET/POST BOE data per deal
    cap-rates/   — GET/POST/DELETE cap rates

components/
  WarRoom.tsx          — Main shell: sidebar, routing, real-time subscriptions
  deals/DealsPage.tsx  — Full table with filters, sort, pagination
  deals/DealModal.tsx  — Deal detail modal with tabs
  boe/BoePanel.tsx     — Full BOE underwriting panel
  dashboard/           — Stats + active pipeline
  pipeline/            — Kanban columns
  caprates/            — Cap rate tracker

lib/
  supabase/client.ts   — Browser Supabase client
  supabase/server.ts   — Server Supabase client
  types.ts             — TypeScript types
  utils.ts             — Formatting + helpers
```

## Database Schema

| Table | Purpose |
|-------|---------|
| `deals` | All 2,009 deals + buyer/seller/soldPrice |
| `boe_data` | BOE T12 + ADJ inputs per deal (JSONB) |
| `cap_rates` | Cap rate tracker data per deal |
| `user_profiles` | Team member profiles + roles |

All tables have Row Level Security — authenticated users can read/write everything.

## Adding Deals from the old HTML file

All 2,009 deals are pre-seeded via `supabase_migration.sql`. Any edits made in the old HTML's localStorage are NOT automatically migrated — those were per-device. Going forward all edits go directly to Supabase and are shared across the team in real time.
