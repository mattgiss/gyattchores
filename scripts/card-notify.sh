#!/usr/bin/env bash
# Card Notify — diff the shared Supabase chore log against the last run's
# snapshot and post Discord updates: submissions (new logs), awards
# (pending → approved, with a CLEARED banner when nothing is left waiting),
# and chores sent back (pending → rejected). Also:
#
#   • Approve-by-reaction: each submission message is remembered; when the
#     approver reacts ✅ the pending chores in it are approved (❌ rejects)
#     straight in Supabase, and the kid's app picks it up on its normal
#     sync. Reading reactions requires DISCORD_BOT_TOKEN — a bot invited to
#     the channel with View Channel / Read Message History / Add Reactions.
#     Without the token everything else still works; the app stays the way
#     to approve.
#   • Stale-approval reminder: chores pending longer than 12 hours ping the
#     approver, repeating at most every 12 hours until they're handled.
#
# The simple_logs table has no updated_at column, so approvals are detected
# by comparing each run's id→status snapshot with the previous one (kept in
# the Actions cache by the workflow). First run with no snapshot baselines
# silently. Run from the repo root.
#
# Env:
#   SUPABASE_URL, SUPABASE_ANON_KEY  — the public anon key from index.html
#   DISCORD_WEBHOOK                  — where to post
#   DISCORD_BOT_TOKEN — optional; enables approve-by-reaction (see above)
#   ID_BEKINDHEARTED, ID_MEGADINOLAVA— optional numeric Discord user IDs;
#                                      when set, messages truly @mention
#   ID_DAD          — Discord user ID pinged on submissions and stale
#                     approvals; also the only user whose ✅/❌ count
#   STATE_DIR       — snapshot directory (default: state)
#   FIXTURE_CURRENT   — test hook: read rows from this file, don't fetch
#   FIXTURE_REACTIONS — test hook: JSON {message_id: "approve"|"reject"}
#   FIXTURE_PATCH_LOG — test hook: record PATCHes here instead of sending
#   DISCORD_DRYRUN    — test hook: print payloads instead of posting
set -euo pipefail

STATE_DIR="${STATE_DIR:-state}"
mkdir -p "$STATE_DIR"
NOW=$(date +%s)

api() { curl -sf -H "apikey: ${SUPABASE_ANON_KEY}" -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" "$@"; }

# ── set chore-log rows to a new status (approve-by-reaction) ─────────────────
set_status() {  # $1 comma-separated ids, $2 new status
  if [ -n "${FIXTURE_PATCH_LOG:-}" ]; then
    echo "PATCH $2: $1" >> "$FIXTURE_PATCH_LOG"
    return 0
  fi
  api -X PATCH "${SUPABASE_URL}/rest/v1/simple_logs?id=in.($1)&status=eq.pending" \
    -H "Content-Type: application/json" -H "Prefer: return=representation" \
    -d "{\"status\":\"$2\"}" | jq -r 'length as $n | "updated \($n) row(s)"'
}

# ── reaction verdict for one tracked message ─────────────────────────────────
reaction_verdict() {  # $1 message_id → prints approve|reject|(nothing)
  if [ -n "${FIXTURE_REACTIONS:-}" ]; then
    jq -r --arg m "$1" '.[$m] // empty' "$FIXTURE_REACTIONS"
    return 0
  fi
  [ -n "${DISCORD_BOT_TOKEN:-}" ] && [ -n "${CHANNEL_ID:-}" ] || return 0
  local EMOJI VERDICT
  for EMOJI in "%E2%9C%85 approve" "%E2%9D%8C reject"; do
    VERDICT=${EMOJI#* }
    if curl -sf -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages/$1/reactions/${EMOJI%% *}?limit=100" \
      | jq -e --arg u "${ID_DAD:-}" 'map(.id) | index($u)' >/dev/null 2>&1; then
      echo "$VERDICT"; return 0
    fi
  done
}

# Channel id for reaction reads/seeds — the webhook knows its own channel.
CHANNEL_ID=""
if [ -n "${DISCORD_BOT_TOKEN:-}" ] && [ -z "${FIXTURE_REACTIONS:-}" ] && [ -z "${DISCORD_DRYRUN:-}" ]; then
  CHANNEL_ID=$(curl -sf "$DISCORD_WEBHOOK" | jq -r '.channel_id // empty' || true)
fi

# ── process outstanding approval messages before fetching, so a reaction
#    turns into an award message in this same run ─────────────────────────────
APPROVALS="$STATE_DIR/approvals.json"
[ -f "$APPROVALS" ] || echo "[]" > "$APPROVALS"
REMAINING="[]"
while IFS=$'\t' read -r MID IDS TS; do
  [ -n "$MID" ] || continue
  if [ $(( NOW - TS )) -gt $(( 7*86400 )) ]; then continue; fi   # too old, stop tracking
  VERDICT=$(reaction_verdict "$MID")
  case "$VERDICT" in
    approve) echo "reaction ✅ on $MID → approving"; set_status "$IDS" approved ;;
    reject)  echo "reaction ❌ on $MID → rejecting"; set_status "$IDS" rejected ;;
    *) REMAINING=$(jq -c --arg m "$MID" --arg i "$IDS" --argjson t "$TS" \
         '. + [{message_id:$m, log_ids:$i, ts:$t}]' <<<"$REMAINING") ;;
  esac
done < <(jq -r '.[] | [.message_id, .log_ids, .ts] | @tsv' "$APPROVALS")
echo "$REMAINING" > "$APPROVALS"

# ── fetch the last 60 days of logs ───────────────────────────────────────────
if [ -n "${FIXTURE_CURRENT:-}" ]; then
  cp "$FIXTURE_CURRENT" current.json
else
  SINCE=$(date -u -d '60 days ago' +%Y-%m-%dT00:00:00Z)
  api --retry 2 -o current.json \
    "${SUPABASE_URL}/rest/v1/simple_logs?select=id,player_id,player_name,chore_name,points,status,created_at&created_at=gte.${SINCE}&order=created_at.asc"
fi
jq -e 'type=="array"' current.json >/dev/null   # sanity: got a row array

jq 'map({key:(.id|tostring), value:.status}) | from_entries' current.json > snapshot.new

# ── who to ping ──────────────────────────────────────────────────────────────
# player_id 1 = bekindhearted, 2 = megadinolava (formerly "titan").
mention() {
  case "$1" in
    1) if [ -n "${ID_BEKINDHEARTED:-}" ]; then echo "<@${ID_BEKINDHEARTED}>"; else echo "**bekindhearted** (@bekindhearted12_29866)"; fi ;;
    2) if [ -n "${ID_MEGADINOLAVA:-}" ];  then echo "<@${ID_MEGADINOLAVA}>";  else echo "**megadinolava** (@dreadeddragon_)"; fi ;;
    *) echo "**$2**" ;;
  esac
}

post_payload() {  # $1 payload json → prints created message id (or nothing)
  if [ -n "${DISCORD_DRYRUN:-}" ]; then
    echo "--- payload ---" >&2; jq . <<<"$1" >&2
    echo "dryrun-mid"
    return 0
  fi
  local RESP HTTP
  RESP=$(curl -s -w '\n%{http_code}' -X POST "${DISCORD_WEBHOOK}?wait=true" \
    -H "Content-Type: application/json" -d "$1")
  HTTP=${RESP##*$'\n'}
  echo "Discord HTTP: $HTTP" >&2
  case "$HTTP" in
    200) jq -r '.id // empty' <<<"${RESP%$'\n'*}" ;;
    204) ;;  # no body (shouldn't happen with wait=true)
    *) echo "::error::discord post failed (HTTP $HTTP)" >&2; return 1 ;;
  esac
}

# ── stale-approval reminder: pending > 12h pings the approver ────────────────
STALE_TS_FILE="$STATE_DIR/stale_ts"
CUTOFF=$(date -u -d '12 hours ago' +%Y-%m-%dT%H:%M:%SZ)
STALE=$(jq --arg c "$CUTOFF" '[.[] | select(.status=="pending" and .created_at < $c)]' current.json)
STALE_N=$(jq 'length' <<<"$STALE")
LAST_STALE=$(cat "$STALE_TS_FILE" 2>/dev/null || echo 0)
if [ "$STALE_N" -gt 0 ] && [ $(( NOW - LAST_STALE )) -ge $(( 12*3600 )) ]; then
  WHO_DAD=$([ -n "${ID_DAD:-}" ] && echo "<@${ID_DAD}>" || echo "hey dad")
  SUMMARY=$(jq -r 'group_by(.player_name) | map("\(.[0].player_name): \(length)") | join(" · ")' <<<"$STALE")
  DETAIL=$(jq -r 'group_by(.player_name) | map("**\(.[0].player_name)**\n" + (map("· \(.chore_name)") | join("\n"))) | join("\n\n")' <<<"$STALE")
  PAYLOAD=$(jq -n --arg content "⏰ ${WHO_DAD} — ${STALE_N} chore(s) waiting more than 12h (${SUMMARY}). the kids are waiting! → <https://gyattchores.com/#admin>" \
    --arg desc "$(head -c 3500 <<<"$DETAIL")" \
    '{content:$content, embeds:[{title:"waiting for approval", description:$desc, color:16098851, footer:{text:"gyattchores · card notify"}}], allowed_mentions:{parse:["users"]}}')
  post_payload "$PAYLOAD" >/dev/null
  echo "$NOW" > "$STALE_TS_FILE"
  echo "stale reminder sent ($STALE_N pending > 12h)"
fi

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
      CONTENT="${CONTENT}🃏 ${WHO} submitted ${N_NEW} chore(s) — <@${ID_DAD}> time to review → <https://gyattchores.com/#admin>\n"
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

NEW_PENDING_IDS=$(jq -r '[.[] | select(.prev==null and .status=="pending") | .id | tostring] | join(",")' annotated.json)
CAN_REACT=$([ -n "${DISCORD_BOT_TOKEN:-}${FIXTURE_REACTIONS:-}" ] && echo yes || echo "")
FOOT=""
if [ -n "$NEW_PENDING_IDS" ] && [ -n "$CAN_REACT" ]; then
  FOOT="\nreact ✅ to approve all · ❌ to send back"
fi

PAYLOAD=$(jq -n --arg content "$(printf '%b' "${CONTENT}${FOOT}" | head -c 1900)" --argjson embeds "$EMBEDS" \
  '{content: $content, embeds: $embeds, allowed_mentions: {parse: ["users"]}}')

MID=$(post_payload "$PAYLOAD")

# ── remember submission messages so a ✅/❌ reaction can settle them ──────────
if [ -n "$MID" ] && [ -n "$NEW_PENDING_IDS" ] && [ -n "$CAN_REACT" ]; then
  jq -c --arg m "$MID" --arg i "$NEW_PENDING_IDS" --argjson t "$NOW" \
    '. + [{message_id:$m, log_ids:$i, ts:$t}]' "$APPROVALS" > "$APPROVALS.tmp" && mv "$APPROVALS.tmp" "$APPROVALS"
  echo "tracking $MID for approval reactions (${NEW_PENDING_IDS})"
  # Seed the two reactions so approving is one tap.
  if [ -n "${DISCORD_BOT_TOKEN:-}" ] && [ -n "${CHANNEL_ID:-}" ]; then
    for E in %E2%9C%85 %E2%9D%8C; do
      curl -sf -X PUT -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages/${MID}/reactions/${E}/@me" \
        -o /dev/null || echo "::warning::could not seed reaction ${E} (check bot permissions)"
    done
  fi
fi
