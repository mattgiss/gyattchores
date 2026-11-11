package com.gyattchores.app.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Player
import java.time.LocalDate
import java.time.ZoneId

/** Player select + the 30-day "25 minutes a day" log. Tapping the title 5x opens the parent gate. */
@Composable
fun HomeScreen(
    players: List<Player>,
    logs: List<ChoreLog>,
    pool: Map<String, Chore>,
    now: Long,
    zone: ZoneId,
    selectedId: String?,
    onPick: (Player) -> Unit,
    onAdmin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var taps by remember { mutableIntStateOf(0) }
    var lastTap by remember { mutableLongStateOf(0L) }
    val fb = LocalFeedback.current
    var soundOn by remember { mutableStateOf(fb.soundOn) }
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
            if (soundOn) "♪ sound: on" else "♪ sound: off", style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.clickable(onClickLabel = "toggle sound") { soundOn = !soundOn; fb.soundOn = soundOn; fb.tick(soundOn) }.padding(vertical = 10.dp),
        )

        SectionLabel("who's playing")
        for (p in players) {
            val rank = Engine.rank(Engine.xp(p.id, logs, zone))
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
        for (p in players) DailyLogRow(p, Engine.minutesByDay(p.id, logs, pool, zone), days, Engine.dayOf(now, zone))
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
