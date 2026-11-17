package com.gyattchores.app.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.engine.Characters
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.engine.PlayerCharacter
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Dare
import com.gyattchores.app.model.Player
import com.gyattchores.app.sync.LocalEntry
import java.time.LocalDate

/**
 * Home: players, dares (family edition), this week's leaderboard, and the 30-day log.
 * The admin button opens the admin area, behind an admin's code.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HomeScreen(
    vm: AppViewModel,
    players: List<Player>,
    logs: List<ChoreLog>,
    shared: Map<String, LocalEntry>,
    me: String?,
    selectedId: String?,
    syncStatus: String,
    onPick: (Player) -> Unit,
    onAdmin: () -> Unit,
    onDares: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val fb = LocalFeedback.current
    val ctx = LocalContext.current
    var soundOn by remember { mutableStateOf(fb.soundOn) }
    val now = vm.now()
    val zone = vm.zone
    val today = vm.today()
    val dares = vm.dares(shared)
    val names = players.associate { it.id to it.shownName }

    // The title on the first band, then the players as small tiles, each a step down the heat
    // gradient in this week's order, with the character they picked.
    val characters = vm.characters(players)
    val board = players.map { it to Engine.weekPoints(it.id, logs, dares, today, zone) }.sortedByDescending { it.second }
    val bands = board.size + 1
    BoxWithConstraints(modifier.fillMaxSize().background(Bg)) {
        // Three tiles across on a phone; more where there's room, so a tablet's tiles stay small too.
        val perRow = (maxWidth / 124.dp).toInt().coerceIn(3, 6)
        val ink = Palette.HEAT.ink
        var picking by remember { mutableStateOf(false) }
        if (picking) ThemePicker { picking = false }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 24.dp)) {
            Column(Modifier.fillMaxWidth().background(Palette.HEAT.band(0, bands)).statusBarsPadding().padding(start = 16.dp, end = 4.dp, bottom = 10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    FitText("DOYOURWORK", style = MaterialTheme.typography.headlineLarge.copy(fontSize = 28.sp), fontWeight = FontWeight.Black,
                        color = ink, modifier = Modifier.weight(1f))
                    // A look of your own, for this phone.
                    TextButton(onClick = { fb.tap(); picking = true }) { Text("Theme", color = ink, fontWeight = FontWeight.Bold) }
                    // Approving chores and changing players or chores: behind an admin's code.
                    TextButton(onClick = { fb.tap(); onAdmin() }) { Text("Admin", color = ink, fontWeight = FontWeight.Bold) }
                }
                Text("${Engine.DAILY_MINUTES} minutes a day. That's it.", color = ink.copy(alpha = 0.85f), fontWeight = FontWeight.SemiBold)
                Text(
                    (if (soundOn) "Sound on" else "Sound off") + if (vm.familySync) " · ${syncStatus.replaceFirstChar { it.uppercase() }}" else "", style = MaterialTheme.typography.labelMedium,
                    color = ink.copy(alpha = 0.7f), fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable(onClickLabel = "Turn sound on or off") { soundOn = !soundOn; fb.soundOn = soundOn; fb.tick(soundOn) }.padding(vertical = 4.dp),
                )
            }

            if (players.isEmpty()) Text("Nobody's playing yet. An admin can add players in Admin.",
                color = Done, modifier = Modifier.padding(20.dp))
            var place = 0
            for (size in Characters.tileRows(board.size, perRow)) Row(Modifier.fillMaxWidth()) {
                repeat(size) {
                    val i = place++
                    val (p, pts) = board[i]
                    PlayerTile(
                        place = i + 1, name = p.shownName, character = characters[p.id], points = pts,
                        version = Engine.rank(vm.totalXp(p.id, logs, shared)).version, streak = Engine.streak(p.id, logs, now, zone),
                        color = Palette.HEAT.band(i + 1, bands), ink = ink, selected = p.id == selectedId,
                        modifier = Modifier.weight(1f).clickable(onClickLabel = "open ${p.shownName}") { fb.tap(); onPick(p) },
                    )
                }
            }

            // Whose phone is this? Asked once; changing it later needs the admin unlock. Only the
            // family edition has dares, since a secret guess needs each person on their own phone.
            if (vm.familySync && players.isNotEmpty()) if (me == null || me !in names) {
                SectionLabel("Whose phone is this?")
                FlowRow(Modifier.padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (p in players) Text(p.shownName, fontWeight = FontWeight.Bold, color = Ink,
                        modifier = Modifier.clip(CircleShape).background(SurfaceDark).clickable { fb.tap(); vm.setMe(p) }.padding(horizontal = 18.dp, vertical = 12.dp))
                }
            } else {
                val mineToday = dares.filter { it.from == me && it.day == today.toString() }
                CompositionLocalProvider(LocalPalette provides Palette.PLUM) {
                    TermButton("Make a dare · ${Engine.MAX_DARES_PER_DAY - mineToday.size} left today") { fb.tap(); onDares() }
                }
                Text("This is ${names[me]}'s phone.", style = MaterialTheme.typography.labelSmall, color = Done,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
            }

            // Yesterday's dares, revealed after midnight.
            val yesterday = today.minusDays(1).toString()
            val revealed = dares.filter { it.day == yesterday }
            if (revealed.isNotEmpty()) {
                SectionLabel("Yesterday's dares")
                val myPoints = me?.let { id -> revealed.sumOf { Engine.darePoints(id, it, logs, zone) } } ?: 0
                if (myPoints > 0) {
                    LaunchedEffect(yesterday) { if (vm.firstReveal(yesterday)) fb.dareLanded() }
                    Text("You earned $myPoints points from dares.", color = Palette.PLUM.ink, fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 20.dp).padding(bottom = 6.dp))
                }
                Column(Modifier.padding(horizontal = 20.dp)) {
                    for (d in revealed) DareLine(d, names, vm.choreName(d.choreId), Engine.dareLanded(d, logs, zone))
                }
            }

            SectionLabel("The last ${Engine.LOG_DAYS} days")
            val days = Engine.recentDays(now, zone)
            Column(Modifier.padding(horizontal = 20.dp)) {
                for (p in players) DailyLogRow(p, Engine.minutesByDay(p.id, logs, vm.store.poolById, zone), days, today)
            }

            // Lets you confirm which build a phone is running (useful after an Obtainium update).
            val version = remember { runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName }.getOrNull() ?: "?" }
            Text("Version $version", style = MaterialTheme.typography.labelSmall, color = Done,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp))
        }
    }
}

/**
 * One player on the scoreboard: their place, their character, their name, this week's points, and
 * their version with their streak beside it. Small on purpose, so a whole household fits above the fold.
 */
@Composable
private fun PlayerTile(place: Int, name: String, character: PlayerCharacter?, points: Int, version: String, streak: Int,
                       color: Color, ink: Color, selected: Boolean, modifier: Modifier = Modifier) {
    Box(modifier.background(color).then(if (selected) Modifier.border(3.dp, ink) else Modifier)) {
        Text("$place", fontWeight = FontWeight.Black, color = ink.copy(alpha = 0.6f), style = MaterialTheme.typography.labelLarge,
            modifier = Modifier.padding(start = 8.dp, top = 6.dp))
        Column(Modifier.fillMaxWidth().padding(start = 6.dp, end = 6.dp, top = 12.dp, bottom = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            if (character != null) CharacterIcon(character, 46.dp)
            // A fixed height, so a long name that had to shrink doesn't leave its tile shorter than the others.
            Box(Modifier.height(26.dp).fillMaxWidth(), contentAlignment = Alignment.Center) {
                FitText(name, style = MaterialTheme.typography.titleSmall.copy(fontSize = 15.sp), fontWeight = FontWeight.Bold, color = ink,
                    modifier = Modifier.wrapContentWidth())
            }
            Text("$points pts", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Black, color = ink, maxLines = 1)
            Row(Modifier.semantics(mergeDescendants = true) { contentDescription = if (streak == 0) version else "$version, $streak-day streak" },
                verticalAlignment = Alignment.CenterVertically) {
                val quiet = ink.copy(alpha = 0.85f)
                Text(if (streak == 0) version else "$version · $streak", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold,
                    color = quiet, maxLines = 1)
                if (streak > 0) StreakFlame(12.dp, quiet, Modifier.padding(start = 1.dp))
            }
        }
    }
}

/**
 * One revealed dare: who dared whom on a small line, the chore beneath it, the result on the right.
 * Two short lines on purpose: as one sentence it wrapped wherever it happened to run out of room.
 */
@Composable
fun DareLine(d: Dare, names: Map<String, String>, choreName: String, landed: Boolean) {
    Row(Modifier.fillMaxWidth().padding(vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("${names[d.from] ?: d.from} dared ${names[d.target] ?: d.target} to $choreName.", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        Text(if (landed) "Done, +${Engine.DARE_GUESSER_POINTS}" else "Didn't happen", color = if (landed) Good else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 12.dp))
    }
}

@Composable
private fun DailyLogRow(player: Player, byDay: Map<LocalDate, Int>, days: List<LocalDate>, today: LocalDate) {
    val hits = days.count { (byDay[it] ?: 0) >= Engine.DAILY_MINUTES }
    val pct = Math.round(hits * 100.0 / days.size)
    Column(Modifier.padding(bottom = 14.dp)) {
        Row {
            Text(player.shownName, style = MaterialTheme.typography.labelLarge, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text("$hits/${days.size} · $pct%", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = Done)
        }
        Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            for (d in days) {
                val mins = byDay[d] ?: 0
                val a = Engine.cellAlpha(mins)
                // A full day is Clear red; part of one runs back up the gradient towards yellow.
                val fill = if (a == 0f) SurfaceDark else Palette.HEAT.band(Math.round((1 - a) * 5), 6)
                val outline = Ink.copy(alpha = if (mins >= Engine.DAILY_MINUTES) 0.9f else 0.35f)
                Box(
                    Modifier.weight(1f).aspectRatio(0.6f).background(fill)
                        .then(if (d == today) Modifier.border(BorderStroke(1.dp, outline)) else Modifier)
                        .semantics { contentDescription = "$d, $mins minutes" },
                )
            }
        }
    }
}
