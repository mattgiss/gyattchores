#!/usr/bin/env bash
# Card Notify — diff the shared Supabase chore log against the last run's
# snapshot and post Discord updates: submissions (new logs), awards
# (pending → approved, with a CLEARED banner when nothing is left waiting),
# and chores sent back (pending → rejected).
#
# The simple_logs table has no updated_at column, so approvals are detected
# by comparing each run's id→status snapshot with the previous one (kept in
# the Actions cache by the workflow). First run with no snapshot baselines
# silently. Run from the repo root.
#
# Env:
#   SUPABASE_URL, SUPABASE_ANON_KEY  — the public anon key from index.html
#   DISCORD_WEBHOOK                  — where to post
#   ID_BEKINDHEARTED, ID_MEGADINOLAVA— optional numeric Discord user IDs;
#                                      when set, messages truly @mention
#   ID_DAD          — optional Discord user ID pinged when a kid submits
#                     their chores for the day (time to review)
#   STATE_DIR   — snapshot directory (default: state)
#   FIXTURE_CURRENT — test hook: read rows from this file instead of Supabase
#   DISCORD_DRYRUN  — test hook: print the payload instead of posting
set -euo pipefail

STATE_DIR="${STATE_DIR:-state}"
mkdir -p "$STATE_DIR"

# ── fetch the last 60 days of logs ───────────────────────────────────────────
if [ -n "${FIXTURE_CURRENT:-}" ]; then
  cp "$FIXTURE_CURRENT" current.json
else
  SINCE=$(date -u -d '60 days ago' +%Y-%m-%dT00:00:00Z)
  curl -sf --retry 2 \
    "${SUPABASE_URL}/rest/v1/simple_logs?select=id,player_id,player_name,chore_name,points,status,created_at&created_at=gte.${SINCE}&order=created_at.asc" \
    -H "apikey: ${SUPABASE_ANON_KEY}" -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -o current.json
fi
jq -e 'type=="array"' current.json >/dev/null   # sanity: got a row array

jq 'map({key:(.id|tostring), value:.status}) | from_entries' current.json > snapshot.new

# ── first run: baseline silently ─────────────────────────────────────────────
if [ ! -f "$STATE_DIR/snapshot.json" ]; then
  mv snapshot.new "$STATE_DIR/snapshot.json"
  echo "baseline: snapshot saved ($(jq length current.json) rows), no notifications"
  exit 0
fi

# ── diff against the previous snapshot ───────────────────────────────────────
jq --slurpfile prev "$STATE_DIR/snapshot.json" \
  'map(. + {prev: ($prev[0][(.id|tostring)] // null)})' current.json > annotated.json

NEW_N=$(jq '[.[] | select(.prev==null)] | length' annotated.json)
APR_N=$(jq '[.[] | select(.prev=="pending" and .status=="approved")] | length' annotated.json)
REJ_N=$(jq '[.[] | select(.prev=="pending" and .status=="rejected")] | length' annotated.json)
echo "diff: $NEW_N new, $APR_N approved, $REJ_N rejected"

mv snapshot.new "$STATE_DIR/snapshot.json"

if [ "$NEW_N" = 0 ] && [ "$APR_N" = 0 ] && [ "$REJ_N" = 0 ]; then
  echo "nothing to report"
  exit 0
fi

# ── who to ping ──────────────────────────────────────────────────────────────
# player_id 1 = bekindhearted, 2 = megadinolava (formerly "titan").
mention() {
  case "$1" in
    1) if [ -n "${ID_BEKINDHEARTED:-}" ]; then echo "<@${ID_BEKINDHEARTED}>"; else echo "**bekindhearted** (@bekindhearted12_29866)"; fi ;;
    2) if [ -n "${ID_MEGADINOLAVA:-}" ];  then echo "<@${ID_MEGADINOLAVA}>";  else echo "**megadinolava** (@dreadeddragon_)"; fi ;;
    *) echo "**$2**" ;;
  esac
}

# ── streak / motivational stats ──────────────────────────────────────────────
# Mirrors the app: a streak day is a Denver-local day with ≥1 approved chore,
# counted back from today (getStreak in index.html). The UTC→Denver offset is
# applied uniformly, so a DST boundary can shift a day's edge by an hour —
# fine for a motivational line. Sets STREAK, YSTREAK (chain ending yesterday,
# for "streak on the line" when today isn't approved yet), PTS_TODAY, PTS_WEEK.
TZ_NAME="America/Denver"
OFF=$(TZ=$TZ_NAME date +%z)
OFF_S=$(( (${OFF:0:1}1) * (10#${OFF:1:2}*3600 + 10#${OFF:3:2}*60) ))
TODAY_LOCAL=$(TZ=$TZ_NAME date +%Y-%m-%d)
WEEK_AGO=$(TZ=$TZ_NAME date -d '-6 day' +%Y-%m-%d)

player_stats() {  # $1 player_id
  local DAYS
  DAYS=$(jq -r --arg p "$1" --argjson off "$OFF_S" '
    [ .[] | select(.player_id==$p and .status=="approved")
      | (.created_at | sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z") | (try fromdateiso8601 catch 0))
      | . + $off | strftime("%Y-%m-%d") ] | unique | .[]' current.json)
  STREAK=0; local i=0 D
  while D=$(TZ=$TZ_NAME date -d "-$i day" +%Y-%m-%d) && grep -qx "$D" <<<"$DAYS"; do
    STREAK=$((STREAK+1)); i=$((i+1))
  done
  YSTREAK=0; i=1
  while D=$(TZ=$TZ_NAME date -d "-$i day" +%Y-%m-%d) && grep -qx "$D" <<<"$DAYS"; do
    YSTREAK=$((YSTREAK+1)); i=$((i+1))
  done
  PTS_TODAY=$(jq -r --arg p "$1" --argjson off "$OFF_S" --arg d "$TODAY_LOCAL" '
    [ .[] | select(.player_id==$p and .status=="approved")
      | select(((.created_at | sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z") | (try fromdateiso8601 catch 0)) + $off | strftime("%Y-%m-%d")) == $d)
      | .points ] | add // 0' current.json)
  PTS_WEEK=$(jq -r --arg p "$1" --argjson off "$OFF_S" --arg d "$WEEK_AGO" '
    [ .[] | select(.player_id==$p and .status=="approved")
      | select(((.created_at | sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z") | (try fromdateiso8601 catch 0)) + $off | strftime("%Y-%m-%d")) >= $d)
      | .points ] | add // 0' current.json)
}

stat_line() {  # uses STREAK/YSTREAK/PTS_TODAY/PTS_WEEK set by player_stats
  local SL MULT
  if [ "$STREAK" -gt 0 ]; then
    MULT=$(( STREAK<10 ? STREAK : 10 ))   # app: momentum = 1 + min(streak,10)*0.1
    SL="🔥 ${STREAK}-day streak · $(awk -v m="$MULT" 'BEGIN{printf "%.1f", 1+m*0.1}')x momentum"
  elif [ "$YSTREAK" -gt 0 ]; then
    SL="🔥 ${YSTREAK}-day streak on the line — today still counts!"
  else
    SL="💪 fresh start — day 1 begins now"
  fi
  echo "${SL} · ${PTS_TODAY} pts today · ${PTS_WEEK} pts this week"
}

# ── build one message per player with activity ───────────────────────────────
CONTENT=""
EMBEDS="[]"
for PID in $(jq -r '[.[] | select(.prev==null or (.prev=="pending" and (.status=="approved" or .status=="rejected"))) | .player_id] | unique | .[]' annotated.json); do
  PNAME=$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p)] | last | .player_name' annotated.json)
  WHO=$(mention "$PID" "$PNAME")
  player_stats "$PID"
  STATS=$(stat_line)

  N_NEW=$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p and .prev==null)] | length' annotated.json)
  N_APR=$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p and .prev=="pending" and .status=="approved")] | length' annotated.json)
  N_REJ=$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p and .prev=="pending" and .status=="rejected")] | length' annotated.json)
  P_NEW=$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p and .prev==null) | .points] | add // 0' annotated.json)
  P_APR=$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p and .prev=="pending" and .status=="approved") | .points] | add // 0' annotated.json)
  PENDING_LEFT=$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p and .status=="pending")] | length' annotated.json)

  LINES=""
  if [ "$N_NEW" -gt 0 ]; then
    if [ -n "${ID_DAD:-}" ]; then
      CONTENT="${CONTENT}🃏 ${WHO} submitted ${N_NEW} chore(s) — <@${ID_DAD}> time to review!\n"
    else
      CONTENT="${CONTENT}🃏 ${WHO} submitted ${N_NEW} chore(s) — waiting for approval\n"
    fi
    LINES="${LINES}**submitted** ($((N_NEW)) · ${P_NEW} pts):\n$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p and .prev==null) | "· " + .chore_name] | join("\n")' annotated.json)\n"
  fi
  if [ "$N_APR" -gt 0 ]; then
    CONTENT="${CONTENT}🏆 ${WHO} +${P_APR} pts — ${N_APR} chore(s) approved!\n"
    LINES="${LINES}**approved** ($((N_APR)) · +${P_APR} pts):\n$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p and .prev=="pending" and .status=="approved") | "· " + .chore_name] | join("\n")' annotated.json)\n"
    if [ "$PENDING_LEFT" = 0 ]; then
      CONTENT="${CONTENT}✅ ${WHO} — CLEARED! nothing left waiting for approval 🎉\n"
    fi
  fi
  if [ "$N_REJ" -gt 0 ]; then
    LINES="${LINES}**sent back** (${N_REJ}) — check the app:\n$(jq -r --arg p "$PID" '[.[] | select(.player_id==$p and .prev=="pending" and .status=="rejected") | "· " + .chore_name] | join("\n")' annotated.json)\n"
  fi

  [ -n "$LINES" ] || continue
  LINES="${LINES}\n${STATS}"
  EMBEDS=$(jq -c --arg name "$PNAME" --arg desc "$(printf '%b' "$LINES" | head -c 3500)" \
    '. + [{title: $name, description: $desc, color: 15874145, footer: {text:"gyattchores · card notify"}}]' <<<"$EMBEDS")
done

PAYLOAD=$(jq -n --arg content "$(printf '%b' "$CONTENT" | head -c 1900)" --argjson embeds "$EMBEDS" \
  '{content: $content, embeds: $embeds, allowed_mentions: {parse: ["users"]}}')

if [ -n "${DISCORD_DRYRUN:-}" ]; then
  echo "--- payload ---"; jq . <<<"$PAYLOAD"
  exit 0
fi

HTTP=$(curl -s -o /tmp/resp.txt -w "%{http_code}" -X POST "$DISCORD_WEBHOOK" \
  -H "Content-Type: application/json" -d "$PAYLOAD")
echo "Discord HTTP: $HTTP"; cat /tmp/resp.txt 2>/dev/null || true
[ "$HTTP" = "204" ] || { echo "::error::card notify failed (HTTP $HTTP)"; exit 1; }
