# GyattChores

A family chore tracking app with gamified points system and weekly GOAT competition.

## Features

### Core System
- **Points System**: Kids earn points for completing chores (250 pts = $1)
- **Weekly GOAT Competition**: Highest scorer gets the GOAT badge (supports ties/Co-GOATs)
- **Approval Workflow**: Parents approve completed chores
- **Weekly Reset**: Automatic reset every Monday at page load
- **Personal Bests**: Track your best weekly score
- **Payout**: Last Friday of each month

### Profile & Stats
- **Player Profiles**: Detailed stats including total completions, weekly average, and success rate
- **7-Day History**: Visual chart showing daily point earnings
- **30-Day Activity Log**: Complete history of chore completions

### Bonus System
- **Beat Last Week's GOAT**: 500 point bonus for exceeding last week's winner
- **Beat Personal Best**: 750 point bonus for beating your own record

### Dashboard Enhancements
- **Weather Widget**: Brighton, CO weather with clothing suggestions
- **Daily Quotes**: Motivational quotes from kid-friendly characters
- **Login Screen**: Password-protected access with auto dark/light mode
- **Dark/Light Mode**: Toggle between themes, auto-detects time of day on login

### Business Rules
- One chore completion per player per day per chore
- High-value chores (>500 pts) can only be done once every 3 days

## Setup

### Initial Setup

1. **Database**: Run `schema.sql` in your Supabase SQL Editor
   - Creates all tables: `players`, `chores`, `chore_completions`, `weekly_resets`, `bonuses`
   - Populates default players (Iris, Mateo) and 16 default chores
   - Sets up database functions for GOAT calculation and weekly totals

2. **Configure**: Update Supabase credentials in index.html (lines 206-209)
   ```javascript
   const supabase = window.supabase.createClient(
       'YOUR_SUPABASE_URL',
       'YOUR_SUPABASE_ANON_KEY'
   );
   ```

3. **Deploy**:
   - Open index.html locally in browser, OR
   - Deploy to GitHub Pages, Netlify, Vercel, or any static host
   - Custom domain supported (CNAME file included for gyattchores.com)

### Database Migration (If Updating from Phase 1)

If you already have the app running from Phase 1, run this SQL to add Phase 2 features:

```sql
-- Add bonuses table for tracking weekly bonuses
CREATE TABLE IF NOT EXISTS bonuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,
    bonus_type TEXT NOT NULL CHECK (bonus_type IN ('beat_goat', 'beat_personal_best')),
    bonus_amount INTEGER NOT NULL,
    awarded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(player_id, week_start_date, bonus_type)
);

CREATE INDEX IF NOT EXISTS idx_bonuses_player_week ON bonuses(player_id, week_start_date);

COMMENT ON TABLE bonuses IS 'Weekly bonus awards (beat GOAT, beat personal best)';
```

## Configuration

### Login Password
Default: `1234` (set in `APPROVAL_CODE` constant, line 211)

### Weather Widget
- Default location: Brighton, CO (coordinates: 39.9851, -104.8206)
- Uses mock data by default
- To use real weather, add OpenWeatherMap API key at line 658
- Cache duration: 30 minutes (localStorage)

### Admin Functions
- Approve/reject chores: Same password as login (`1234`)
- Force weekly reset: Available in admin section
- Add custom chores: Available in admin section

## Tech Stack

- React (via CDN)
- Supabase (PostgreSQL)
- Material Design UI

---

Created by Matthew Gissentanna
