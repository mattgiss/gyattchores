package com.doyourwork.app.ui

import androidx.compose.ui.unit.sp
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.graphics.Color
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
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
import com.doyourwork.app.AppViewModel
import com.doyourwork.app.engine.Engine
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Player
import com.doyourwork.app.sync.LocalEntry

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
    val names = players.associate { it.id to it.shownName }

    // Dares are in Clear's plum theme: a secret, after-dark corner of the app.
    CompositionLocalProvider(LocalPalette provides Palette.PLUM) {
    Column(Modifier.fillMaxSize().background(Bg)) {
        Row(Modifier.fillMaxWidth().background(Palette.PLUM.stops[0]).statusBarsPadding().padding(start = 8.dp, end = 12.dp, top = 4.dp, bottom = 14.dp),
            verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) TextButton(onClick = onBack) { Text("Back", color = Palette.PLUM.ink, fontWeight = FontWeight.Bold) }
            Text("Dares", color = Palette.PLUM.ink, fontSize = 24.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(horizontal = 12.dp))
        }
        LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
            item {
                Text("Guess what someone will do today. If they do it and it's approved, you get ${Engine.DARE_GUESSER_POINTS} points " +
                    "and they get ${Engine.DARE_DOER_POINTS}. Nobody sees the dares until tomorrow.",
                    color = Done, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 14.dp))
                Text(when (mine.size) { 0 -> "You haven't made any dares today."; Engine.MAX_DARES_PER_DAY -> "You've made all ${mine.size} of today's dares."
                    else -> "You've made ${mine.size} of your ${Engine.MAX_DARES_PER_DAY} dares today." }, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 10.dp))
                for (d in mine) Text("You dared ${names[d.target] ?: d.target} to ${vm.choreName(d.choreId)}.",
                    style = MaterialTheme.typography.bodyMedium, color = Palette.PLUM.ink, modifier = Modifier.padding(top = 2.dp))
                // A locked target already has its own standing line below; don't say it twice.
                val locked = target != null && vm.submittedToday(target.id, logs)
                note?.takeIf { !locked }?.let { Text(it, color = Bad, style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(top = 6.dp)) }
            }
            if (target == null) {
                item { Text("Once there's someone else playing, you can dare them.", color = Done, modifier = Modifier.padding(vertical = 24.dp)) }
            } else {
                item {
                    SectionLabel("Who are you daring?", padded = false)
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        for (p in others) FilterChip(selected = p.id == target.id, onClick = { fb.tap(); targetId = p.id; note = null }, label = { Text(p.shownName) })
                    }
                    if (vm.submittedToday(target.id, logs)) Text("${target.shownName} already sent today's card, so it's too late to dare them.",
                        color = Warn, style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(top = 8.dp))
                }
                // The same list the target sees, most overdue first: the likeliest chores are on top.
                val pool = vm.pickable(target.id, logs)
                itemsIndexed(pool, key = { _, c -> c.id }) { i, c ->
                    val on = mine.any { it.target == target.id && it.choreId == c.id }
                    Box(Modifier.bleed(20.dp)) { ChoreRow(c.name, c.currentMinutes, c.escalLevel, checked = on, index = i, count = pool.size, picking = true, onToggle = {
                        val why = vm.toggleDare(target, c.id)
                        note = why
                        if (why != null) fb.error() else if (on) fb.tick(false) else fb.dare()
                    }) }
                }
            }
        }
    }
    }
}
