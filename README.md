# GyattChores

A gamified family chore tracking app with points, competitions, achievements, and weekly payouts.

## Features

### Core System
- **Points System**: Kids earn points for completing chores (250 pts = $1)
- **Approval Workflow**: Parents approve completed chores before points are awarded
- **Cooldown System**: Chores have configurable cooldown periods (default 24hrs)
- **Single-Claim Chores**: Some chores (like pet feeding) can only be done by one player per cooldown

### Weekly Competition
- **Weekly GOAT**: Highest scorer gets the 🐐 GOAT badge (supports ties/Co-GOATs)
- **Current Leader**: Purple glow and 👑 LEADING badge shows who's ahead this week
- **Beat Last Week's GOAT Bonus**: 500 points for exceeding last week's winner
- **Beat Personal Best Bonus**: 750 points for beating your own record
- **Weekly Reset**: Automatic reset every Monday

### Stale Chore Detection
- **Red Glow Warning**: Chores not done in 3x their cooldown period glow red
- **"Needs Attention" Badge**: Visual indicator for overdue chores
- **Priority Sorting**: Stale chores appear at the top of the Available Chores list

### Achievements System
- **Chore Milestones**: First Steps, Getting Started, Chore Champion, etc.
- **Point Milestones**: Point Starter, Point Collector, Point Master, etc.
- **Streaks**: Daily Dedication, Weekly Warrior, Unstoppable, Legendary
- **Special**: Early Bird, Night Owl, Speed Demon, Overachiever

### Tiered Payout System
- **Monthly Payouts**: Last Friday of each month
- **Tiered Rates**: Higher points = better payout rates
  - 0-4,999 pts: $0.004/pt
  - 5,000-9,999 pts: $0.005/pt
  - 10,000-14,999 pts: $0.006/pt
  - 15,000+ pts: $0.007/pt

### Custom Tasks & Bidding
- **Player Bids**: Kids can propose custom tasks with point values
- **Admin Review**: Parents accept, counter-offer, or reject bids
- **Custom Tasks**: Green glow on custom/bid tasks for visibility

### Profile & Stats
- **Player Profiles**: Detailed stats including total completions, weekly average, success rate
- **7-Day History**: Visual chart showing daily point earnings
- **30-Day Activity Log**: Complete history of chore completions
- **Achievement Showcase**: Display earned achievements

### Dashboard
- **Weather Widget**: Local weather with clothing suggestions and tomorrow's forecast
- **Daily Quotes**: Motivational quotes from kid-friendly characters
- **Dark/Light Mode**: Toggle themes, auto-detects time of day on login
- **Definition of Done**: Chore descriptions show what "done" means

### Admin Features
- **Approve/Reject Chores**: Review pending completions
- **Backfill Entries**: Add missed chores for past dates
- **Edit Approved Chores**: Modify or reassign completed chores
- **Reset Cooldowns**: Clear all cooldowns to make chores available
- **Activity Logs**: Track admin actions and changes

## Chores

| Chore | Points | Cooldown | Notes |
|-------|--------|----------|-------|
| Pick up Poop | 500 | 24hr | |
| Vacuum Living Room | 500 | 24hr | |
| Get Mail | 250 | 24hr | |
| Take Out Trash | 375 | 24hr | |
| Take Trash to Curb | 375 | 24hr | Sunday special availability |
| Wash Dishes | 500 | 24hr | |
| Load Dishwasher | 625 | 24hr | |
| Unload Dishwasher | 500 | 24hr | |
| Clean Room | 750 | 24hr | |
| Clean Bathroom | 750 | 24hr | Full checklist included |
| Water Plants | 250 | 24hr | |
| Feed Alfred | 250 | 8hr | Single-claim (dog) |
| Feed Chevy | 250 | 8hr | Single-claim (cat) |
| Sweep Floor | 375 | 24hr | |
| Wipe Counters | 375 | 24hr | |
| Take Out Recycling | 250 | 24hr | |
| Fold Laundry | 500 | 24hr | |
| Set Table | 250 | 24hr | |
| Clear Table | 250 | 24hr | |

## Setup

### 1. Database Setup
Run these SQL files in your Supabase SQL Editor (in order):
1. `schema.sql` - Core tables and functions
2. `add-chore-bidding-system.sql` - Custom task bidding
3. `add-admin-activity-logs.sql` - Admin logging
4. `add-error-logging-and-option-b-levels.sql` - Error logs and leveling
5. `enable-rls-policies.sql` - Row Level Security (required for security)

### 2. Configure Credentials
Update Supabase credentials in `index.html` (around line 603):
```javascript
const supabase = window.supabase.createClient(
    'YOUR_SUPABASE_URL',
    'YOUR_SUPABASE_ANON_KEY'
);
```

### 3. Set Passwords
Update passwords in `index.html` (around line 608-609):
```javascript
const LOGIN_PASSWORD = "your_login_password";
const APPROVAL_CODE = "your_admin_code";
```

### 4. Deploy
- Open `index.html` locally in browser, OR
- Deploy to GitHub Pages, Netlify, Vercel, or any static host

## Security

See `SECURITY.md` for important security information including:
- How to rotate your Supabase credentials
- Enabling Row Level Security
- Future authentication improvements

## Tech Stack

- **Frontend**: React 18 (via CDN), Material Design
- **Backend**: Supabase (PostgreSQL)
- **Hosting**: Static (GitHub Pages compatible)

## File Structure

```
├── index.html              # Main app (single-page application)
├── schema.sql              # Core database schema
├── enable-rls-policies.sql # Row Level Security policies
├── SECURITY.md             # Security guide
├── README.md               # This file
└── *.sql                   # Various migration files
```

---

Created by Matthew Gissentanna
