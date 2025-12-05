# Leveling Progression Examples

Here are different XP progression curves for the leveling system. Choose the one that feels right for your family's pace.

## Assumptions:
- Average chore: 400 points
- Active week: ~20 chores = 8,000 points
- XP = Points earned (1:1 ratio, can be adjusted)

---

## Option A: Fast Progression (Easy Levels)
*Kids level up frequently, constant sense of achievement*

| Level | XP Required | Total XP | Weeks to Reach | Unlocks (Future) |
|-------|-------------|----------|----------------|------------------|
| 1 | 0 | 0 | Start | - |
| 2 | 5,000 | 5,000 | ~1 week | "Chore Starter" badge |
| 3 | 8,000 | 13,000 | ~2 weeks | First achievement unlocked |
| 4 | 12,000 | 25,000 | ~3 weeks | - |
| 5 | 15,000 | 40,000 | ~5 weeks | "Apprentice" title |
| 10 | 30,000 | 175,000 | ~22 weeks | "Dedicated Helper" |
| 15 | 50,000 | 475,000 | ~60 weeks | "Expert" title |
| 20 | 75,000 | 975,000 | ~122 weeks | "Master" rank |

**Pros:** Frequent rewards, kids stay motivated
**Cons:** May level too fast, less prestigious

---

## Option B: Medium Progression (Balanced)
*Steady progression, levels feel earned*

| Level | XP Required | Total XP | Weeks to Reach | Unlocks (Future) |
|-------|-------------|----------|----------------|------------------|
| 1 | 0 | 0 | Start | - |
| 2 | 10,000 | 10,000 | ~1-2 weeks | "Getting Started" |
| 3 | 15,000 | 25,000 | ~3 weeks | - |
| 4 | 20,000 | 45,000 | ~6 weeks | - |
| 5 | 30,000 | 75,000 | ~9 weeks | "Hard Worker" title |
| 10 | 60,000 | 375,000 | ~47 weeks | "Committed" badge |
| 15 | 100,000 | 1,125,000 | ~141 weeks | "Veteran" rank |
| 20 | 150,000 | 2,625,000 | ~328 weeks | "Legend" status, Payout Tier C unlock |

**Pros:** Good balance of challenge and reward
**Cons:** Takes commitment to reach high levels

---

## Option C: Slow Progression (Prestigious)
*Levels are rare and meaningful achievements*

| Level | XP Required | Total XP | Weeks to Reach | Unlocks (Future) |
|-------|-------------|----------|----------------|------------------|
| 1 | 0 | 0 | Start | - |
| 2 | 20,000 | 20,000 | ~2-3 weeks | - |
| 3 | 35,000 | 55,000 | ~7 weeks | - |
| 4 | 50,000 | 105,000 | ~13 weeks | "Dedicated" title |
| 5 | 75,000 | 180,000 | ~23 weeks | - |
| 10 | 150,000 | 1,005,000 | ~126 weeks | "Elite Helper" |
| 15 | 250,000 | 2,880,000 | ~360 weeks | "Master" rank |
| 20 | 400,000 | 6,630,000 | ~829 weeks | "Legendary", Payout Tier C |

**Pros:** Levels feel very special and prestigious
**Cons:** Slower progression, may demotivate some kids

---

## Option D: Exponential (RPG-Style)
*Early levels are fast, later levels take serious dedication*

Formula: `XP = 1000 × (level^2)`

| Level | XP Required | Total XP | Weeks to Reach | Unlocks (Future) |
|-------|-------------|----------|----------------|------------------|
| 1 | 0 | 0 | Start | - |
| 2 | 4,000 | 4,000 | ~0.5 weeks | Quick win! |
| 3 | 9,000 | 13,000 | ~2 weeks | - |
| 4 | 16,000 | 29,000 | ~4 weeks | - |
| 5 | 25,000 | 54,000 | ~7 weeks | "Apprentice" |
| 10 | 100,000 | 385,000 | ~48 weeks | "Skilled" |
| 15 | 225,000 | 1,260,000 | ~158 weeks | "Expert" |
| 20 | 400,000 | 2,870,000 | ~359 weeks | "Master", Tier C unlock |
| 25 | 625,000 | 5,720,000 | ~715 weeks | "Legend" |
| 30 | 900,000 | 9,620,000 | ~1203 weeks | "Mythic" |

**Pros:** Feels like a video game, early satisfaction + long-term goals
**Cons:** High levels become very difficult

---

## Recommended: Option B (Medium) or Option D (RPG-Style)

**Option B** if you want predictable progression that's neither too fast nor too slow.

**Option D** if you want that video game dopamine hit early on, with aspirational long-term goals.

---

## Future Unlock Ideas (for the JSON unlocks field):

```json
{
  "level": 5,
  "unlocks": {
    "title": "Hard Worker",
    "badge_icon": "⭐",
    "perks": ["custom_avatar_border", "priority_chore_claim"],
    "features": ["can_create_custom_tasks"]
  }
}
```

```json
{
  "level": 20,
  "unlocks": {
    "title": "Chore Master",
    "badge_icon": "👑",
    "payout_tier": "C",
    "perks": ["exclusive_achievements", "leaderboard_highlight"],
    "bonus_multiplier": 1.1
  }
}
```

---

## XP Award Strategy:

**Current thinking:** XP = Points earned (1:1)
- Do 500 point chore = gain 500 XP

**Alternative options:**
- Bonus XP for streaks: +10% XP for 3-day streak, +25% for 7-day streak
- Bonus XP for GOAT of the week: +500 XP
- Bonus XP for perfect week (all chores completed): +1000 XP
- Achievement XP: Award bonus XP when unlocking achievements

Which progression curve feels right for your family?
