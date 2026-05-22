# GyattChores

A premium gamified family chore tracking app with points, competitions, achievements, and weekly payouts. Built for families who want to make chores fun while teaching kids about earning and responsibility.

## Overview

GyattChores transforms household chores into an engaging competition. Kids earn points for completing tasks, compete for the weekly GOAT (Greatest Of All Time) title, unlock achievements, and earn real money through a tiered payout system.

**Live Site:** [gyattchores.com](https://gyattchores.com)

## Features

### Core System
- **Points Economy**: Kids earn points for completing chores (250 pts = $1 USD)
- **Approval Workflow**: Parents approve completed chores before points are awarded - prevents gaming the system
- **Cooldown System**: Chores have configurable cooldown periods (default 24hrs) to encourage variety
- **Single-Claim Chores**: Pet feeding tasks can only be claimed by one player per cooldown

### Weekly Competition
| Feature | Description |
|---------|-------------|
| Weekly GOAT | Highest scorer gets the GOAT badge (supports ties as "Co-GOATs") |
| Current Leader | Purple glow and LEADING badge shows who's ahead this week |
| Beat GOAT Bonus | +500 points for exceeding last week's winner |
| Beat Personal Best | +750 points for surpassing your own record |
| Weekly Reset | Automatic reset every Monday at midnight |

### Achievements System

**Chore Milestones**
- First Steps (1 chore)
- Getting Started (10 chores)
- Chore Champion (50 chores)
- Hundred Club (100 chores)
- Chore Master (250 chores)
- Chore Legend (500 chores)

**Point Milestones**
- Point Starter (1,000 pts)
- Point Collector (5,000 pts)
- Point Master (10,000 pts)
- Point Legend (25,000 pts)

**Streak Achievements**
- Daily Dedication (3-day streak)
- Weekly Warrior (7-day streak)
- Unstoppable (14-day streak)
- Legendary (30-day streak)

**Money Milestones**
- Money Maker ($500 lifetime)
- Thousandaire ($1,000 lifetime)

### Tiered Payout System

Payouts occur on the last Friday of each month with progressive rates:

| Points Earned | Rate per Point | Example Payout |
|---------------|----------------|----------------|
| 0 - 4,999 | $0.004 | 4,000 pts = $16 |
| 5,000 - 9,999 | $0.005 | 7,500 pts = $37.50 |
| 10,000 - 14,999 | $0.006 | 12,000 pts = $72 |
| 15,000+ | $0.007 | 20,000 pts = $140 |

### Available Chores

| Chore | Points | Value | Cooldown | Notes |
|-------|--------|-------|----------|-------|
| Pick up Poop | 500 | $2.00 | 24hr | |
| Vacuum Living Room | 500 | $2.00 | 24hr | |
| Get Mail | 250 | $1.00 | 24hr | |
| Take Out Trash | 375 | $1.50 | 24hr | |
| Take Trash to Curb | 375 | $1.50 | 24hr | Sunday availability |
| Wash Dishes | 500 | $2.00 | 24hr | |
| Load Dishwasher | 625 | $2.50 | 24hr | |
| Unload Dishwasher | 500 | $2.00 | 24hr | |
| Clean Room | 750 | $3.00 | 24hr | |
| Clean Bathroom | 750 | $3.00 | 24hr | Full checklist |
| Water Plants | 250 | $1.00 | 24hr | |
| Feed Alfred | 250 | $1.00 | 8hr | Single-claim |
| Feed Chevy | 250 | $1.00 | 8hr | Single-claim |
| Sweep Floor | 375 | $1.50 | 24hr | |
| Wipe Counters | 375 | $1.50 | 24hr | |
| Take Out Recycling | 250 | $1.00 | 24hr | |
| Fold Laundry | 500 | $2.00 | 24hr | |
| Set Table | 250 | $1.00 | 24hr | |
| Clear Table | 250 | $1.00 | 24hr | |

### Dashboard Features
- **Weather Widget**: Local weather with clothing suggestions
- **Daily Quotes**: Motivational quotes from kid-friendly characters
- **Dark/Light Mode**: Manual toggle or auto-detect based on time
- **Definition of Done**: Clear descriptions of what "done" means for each chore
- **Pull-to-Refresh**: Native mobile gesture support

### Admin Features
- Approve/reject pending chore completions
- Backfill entries for missed chores
- Edit approved chores (reassign, change date)
- Reset all cooldowns
- View activity and error logs
- Manage custom task bids

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | React 18 (CDN), Babel Standalone |
| Backend | Supabase (PostgreSQL) |
| Hosting | GitHub Pages |
| PWA | iOS home screen support |
| Design | Material Design 3 inspired |

## Setup

### Prerequisites
- Supabase account (free tier works)
- Static file host (GitHub Pages, Netlify, Vercel, etc.)

### 1. Database Setup

Run these SQL files in your Supabase SQL Editor in order:

```bash
1. schema.sql                          # Core tables and functions
2. add-chore-bidding-system.sql        # Custom task bidding
3. add-admin-activity-logs.sql         # Admin logging
4. add-error-logging-and-option-b-levels.sql  # Error logs
5. enable-rls-policies.sql             # Row Level Security (REQUIRED)
6. add-money-achievements.sql          # Lifetime earnings achievements
```

### 2. Configure Credentials

Update Supabase credentials in `index.html` (line ~618):

```javascript
const supabase = window.supabase.createClient(
    'YOUR_SUPABASE_URL',
    'YOUR_SUPABASE_ANON_KEY'
);
```

### 3. Set Passwords

Update passwords in `index.html` (line ~623):

```javascript
const LOGIN_PASSWORD = "your_login_password";
const APPROVAL_CODE = "your_admin_code";
```

### 4. Deploy

**Option A: Local**
```bash
open index.html
```

**Option B: GitHub Pages**
```bash
git add .
git commit -m "Deploy GyattChores"
git push origin main
# Enable GitHub Pages in repo settings
```

## Project Structure

```
gyattchores/
├── index.html                 # Main SPA (7,000+ lines)
├── schema.sql                 # Core database schema
├── enable-rls-policies.sql    # Security policies
├── *.sql                      # Migration files
├── SECURITY.md                # Security documentation
├── SUPABASE_SETUP.md          # Database setup guide
├── CNAME                      # Custom domain config
├── apple-touch-icon.png       # iOS home screen icon
├── gyattchores-logo*.svg      # Logo variants
└── GyattChoresApp/            # Native iOS app (SwiftUI)
    └── GyattChoresApp/
        ├── Models/            # Data models
        ├── Views/             # SwiftUI views
        └── Services/          # API & auth services
```

## Security

See [SECURITY.md](SECURITY.md) for important security information:
- Row Level Security (RLS) configuration
- Credential management
- Known limitations and future improvements

## Native iOS App

A native SwiftUI iOS app is included in `GyattChoresApp/`. To build:

1. Install Xcode from the Mac App Store
2. Open `GyattChoresApp.xcodeproj`
3. Configure your development team
4. Build and run

The iOS app provides a native experience with:
- Native SwiftUI interface
- Tab-based navigation
- Haptic feedback
- Pull-to-refresh
- Dark/light mode

## Contributing

This is a family project, but suggestions are welcome! Open an issue to discuss changes.

## License

MIT License - feel free to fork and adapt for your family.

---

**Created with love for BeKindHearted and MegoDinoLava**

*Built by Matthew Gissentanna*
