package com.gyattchores.app.ui

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Player
import com.gyattchores.app.sync.LocalEntry

/**
 * Make today's secret dares: guess which chores someone else will do. Optional, up to three a day.
 * Only your own dares show here; everyone's are revealed on the home screen after midnight.
 */
@Composable
fun DaresScreen(
    vm: AppViewModel,
    players: List<Player>,
    logs: List<ChoreLog>,
    shared: Map<String, LocalEntry>,
    me: String,
    onBack: (() -> Unit)?,
) {
    val fb = LocalFeedback.current
    val today = vm.today().toString()
    val others = players.filter { it.id != me }
    val mine = vm.dares(shared).filter { it.from == me && it.day == today }
    var targetId by rememberSaveable { mutableStateOf(others.firstOrNull()?.id) }
    val target = others.firstOrNull { it.id == targetId } ?: others.firstOrNull()
    var note by rememberSaveable { mutableStateOf<String?>(null) }
    val names = players.associate { it.id to it.name }

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) TextButton(onClick = onBack) { Text("← back") }
            Text("DARES", color = Accent, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(12.dp))
        }
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
            item {
                Text("guess what someone will do today. if they do it and it's approved, you get +${Engine.DARE_GUESSER_POINTS} " +
                    "and they get +${Engine.DARE_DOER_POINTS}. nobody sees dares until tomorrow.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
                Text("${mine.size} of ${Engine.MAX_DARES_PER_DAY} used today", fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 10.dp))
                for (d in mine) Text("· ${names[d.target] ?: d.target}: ${vm.store.poolById[d.choreId]?.name ?: d.choreId}",
                    style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 2.dp))
                note?.let { Text(it, color = Bad, style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(top = 6.dp)) }
            }
            if (target == null) {
                item { Text("add another player to dare them.", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 24.dp)) }
            } else {
                item {
                    SectionLabel("who are you daring?")
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        for (p in others) FilterChip(selected = p.id == target.id, onClick = { fb.tap(); targetId = p.id; note = null }, label = { Text(p.name) })
                    }
                    if (vm.submittedToday(target.id, logs)) Text("locked — ${target.name} already submitted today",
                        color = Warn, style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(top = 8.dp))
                }
                // The same list the target sees, most overdue first: the likeliest chores are on top.
                items(vm.pickable(target.id, logs), key = { it.id }) { c ->
                    val on = mine.any { it.target == target.id && it.choreId == c.id }
                    ChoreRow(c.name, c.currentMinutes, c.escalLevel, checked = on, onToggle = {
                        val why = vm.toggleDare(target, c.id)
                        note = why
                        if (why != null) fb.error() else if (on) fb.tick(false) else fb.dare()
                    })
                }
            }
        }
    }
}
