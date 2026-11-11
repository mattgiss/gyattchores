package com.gyattchores.app.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Dare
import com.gyattchores.app.model.Player
import com.gyattchores.app.sync.LocalEntry
import java.time.LocalDate

/**
 * Home: players, this week's leaderboard, dares, and the 30-day log.
 * Tapping the title 5x opens the parent gate.
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
    var taps by remember { mutableIntStateOf(0) }
    var lastTap by remember { mutableLongStateOf(0L) }
    val fb = LocalFeedback.current
    var soundOn by remember { mutableStateOf(fb.soundOn) }
    val now = vm.now()
    val zone = vm.zone
    val today = vm.today()
    val dares = vm.dares(shared)
    val names = players.associate { it.id to it.name }

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp)) {
        Text(
            "GYATTCHORES", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold,
            letterSpacing = 4.sp, color = Accent,
            modifier = Modifier.clickable(onClickLabel = "title") {
                fb.tap()
                val t = System.currentTimeMillis()
                taps = if (t - lastTap < 2000) taps + 1 else 1
                lastTap = t
                if (taps >= 5) { taps = 0; onAdmin() }
            }.padding(vertical = 8.dp),
        )
        Text("${Engine.DAILY_MINUTES} minutes a day. that's it.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            (if (soundOn) "♪ sound: on" else "♪ sound: off") + "   ⇅ $syncStatus", style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.clickable(onClickLabel = "toggle sound") { soundOn = !soundOn; fb.soundOn = soundOn; fb.tick(soundOn) }.padding(vertical = 10.dp),
        )

        // Whose phone is this? Asked once; changing it later needs the parent unlock.
        if (me == null || me !in names) {
            SectionLabel("whose phone is this?", Accent)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (p in players) OutlinedButton(onClick = { fb.tap(); vm.setMe(p) }) { Text(p.name) }
            }
        } else {
            val mineToday = dares.filter { it.from == me && it.day == today.toString() }
            TermButton("DARES · ${Engine.MAX_DARES_PER_DAY - mineToday.size} LEFT TODAY", modifier = Modifier.padding(top = 4.dp)) { fb.tap(); onDares() }
            Text("this phone: ${names[me]}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp))
        }

        // Yesterday's dares, revealed after midnight.
        val yesterday = today.minusDays(1).toString()
        val revealed = dares.filter { it.day == yesterday }
        if (revealed.isNotEmpty()) {
            SectionLabel("yesterday's dares · revealed")
            val myPoints = me?.let { id -> revealed.sumOf { Engine.darePoints(id, it, logs, zone) } } ?: 0
            if (myPoints > 0) {
                LaunchedEffect(yesterday) { if (vm.firstReveal(yesterday)) fb.dareLanded() }
                Text("★ you earned +$myPoints from dares", color = Accent, fontWeight = FontWeight.Bold, modifier = Modifier.padding(bottom = 6.dp))
            }
            for (d in revealed) DareLine(d, names, vm.store.poolById[d.choreId]?.name ?: d.choreId, Engine.dareLanded(d, logs, zone))
        }

        SectionLabel("this week")
        val board = players.map { it to Engine.weekPoints(it.id, logs, dares, today, zone) }.sortedByDescending { it.second }
        board.forEachIndexed { i, (p, pts) ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                Text("${i + 1}. ", color = if (i == 0 && pts > 0) Accent else MaterialTheme.colorScheme.onSurfaceVariant)
                Text(p.name, modifier = Modifier.weight(1f), fontWeight = if (i == 0 && pts > 0) FontWeight.Bold else FontWeight.Normal)
                Text("$pts pts", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        SectionLabel("who's playing")
        for (p in players) {
            val rank = Engine.rank(vm.totalXp(p.id, logs, shared))
            val streak = Engine.streak(p.id, logs, now, zone)
            val selected = p.id == selectedId
            Row(
                Modifier.fillMaxWidth().heightIn(min = 64.dp)
                    .then(if (selected) Modifier.background(MaterialTheme.colorScheme.secondaryContainer) else Modifier)
                    .clickable(onClickLabel = "open ${p.name}") { fb.tap(); onPick(p) }.padding(horizontal = 8.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("> ", color = Accent)
                Text(p.name, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                Text("${rank.version} · 🔥$streak", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            HorizontalDivider()
        }

        SectionLabel("daily log · last ${Engine.LOG_DAYS} days")
        val days = Engine.recentDays(now, zone)
        for (p in players) DailyLogRow(p, Engine.minutesByDay(p.id, logs, vm.store.poolById, zone), days, today)
    }
}

/** "megadinolava dared bekindhearted: scrub toilet  ✓ +10" */
@Composable
fun DareLine(d: Dare, names: Map<String, String>, choreName: String, landed: Boolean) {
    Row(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
        Text("${names[d.from] ?: d.from} → ${names[d.target] ?: d.target}: $choreName", modifier = Modifier.weight(1f),
            style = MaterialTheme.typography.bodyMedium)
        Text(if (landed) "✓ +${Engine.DARE_GUESSER_POINTS}" else "✗", color = if (landed) Good else MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun DailyLogRow(player: Player, byDay: Map<LocalDate, Int>, days: List<LocalDate>, today: LocalDate) {
    val hits = days.count { (byDay[it] ?: 0) >= Engine.DAILY_MINUTES }
    val pct = Math.round(hits * 100.0 / days.size)
    Column(Modifier.padding(bottom = 14.dp)) {
        Row {
            Text(player.name, style = MaterialTheme.typography.labelLarge, modifier = Modifier.weight(1f))
            Text("$hits/${days.size} · $pct%", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            for (d in days) {
                val mins = byDay[d] ?: 0
                val a = Engine.cellAlpha(mins)
                val fill = if (a == 0f) MaterialTheme.colorScheme.surfaceVariant else Accent.copy(alpha = a)
                val outline = if (mins >= Engine.DAILY_MINUTES) Accent else MaterialTheme.colorScheme.outline
                Box(
                    Modifier.weight(1f).aspectRatio(0.6f).background(fill)
                        .then(if (d == today) Modifier.border(BorderStroke(1.dp, outline)) else Modifier)
                        .semantics { contentDescription = "$d, $mins minutes" },
                )
            }
        }
    }
}
