package com.gyattchores.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.Card
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.EnrichedChore
import com.gyattchores.app.model.Player
import com.gyattchores.app.model.Status
import kotlin.math.roundToInt

/** Top and bottom of a horizontal hinge, in window pixels, when the phone is half-open on a table. */
data class Hinge(val top: Int, val bottom: Int)

/**
 * A scrolling area plus controls. Normally the controls sit under the list. In tabletop posture the
 * list stays above the hinge and the controls go below it, so nothing lands on the fold.
 */
@Composable
fun TwoZone(hinge: Hinge?, top: @Composable () -> Unit, bottom: @Composable () -> Unit) {
    var rootY by remember { mutableIntStateOf(0) }
    val density = LocalDensity.current
    Column(Modifier.fillMaxSize().onGloballyPositioned { rootY = it.positionInWindow().y.roundToInt() }) {
        if (hinge != null && hinge.top - rootY > 0) {
            Box(Modifier.fillMaxWidth().height(with(density) { (hinge.top - rootY).toDp() })) { top() }
            Spacer(Modifier.height(with(density) { (hinge.bottom - hinge.top).toDp() }))
            Box(Modifier.fillMaxWidth().weight(1f)) { bottom() }
        } else {
            Box(Modifier.fillMaxWidth().weight(1f)) { top() }
            bottom()
        }
    }
}

@Composable
private fun TopBar(title: String, onBack: (() -> Unit)?) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        if (onBack != null) TextButton(onClick = onBack) { Text("← back") }
        Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(horizontal = 8.dp, vertical = 12.dp))
    }
}

/** One player's day: pick a card, check it off, submit, then (optionally) a bonus round. */
@Composable
fun PlayerScreen(
    vm: AppViewModel,
    player: Player,
    logs: List<ChoreLog>,
    cards: Map<String, Card>,
    hinge: Hinge?,
    onBack: (() -> Unit)?,
    /** Opens the puzzle; offered once today's card is submitted. */
    onPuzzle: () -> Unit = {},
) {
    val now = remember(logs, cards) { vm.now() }
    val card = vm.cardFor(player.id, cards, logs)
    val pool = remember(logs, player.id, now) { vm.pickable(player.id, logs) }
    var bonusPicking by rememberSaveable(player.id) { mutableStateOf(false) }
    val fb = LocalFeedback.current

    val todays = logs.filter { it.playerId == player.id && Engine.dayOf(it.timestamp, vm.zone) == vm.today() }
    val loggedToday = (card?.choreIds.orEmpty() + todays.map { it.choreId }).toSet()

    Column(Modifier.fillMaxSize()) {
        when {
            card == null -> {
                TopBar(player.name, onBack)
                Picker(player.id, pool, bonus = false, hinge = hinge) { vm.lockIn(player, it); fb.lockIn() }
            }
            bonusPicking -> {
                TopBar("${player.name} · bonus round", onBack = { bonusPicking = false })
                Picker(player.id, pool.filter { it.id !in loggedToday }, bonus = true, hinge = hinge) {
                    vm.logBonus(player, it); fb.submit(); bonusPicking = false
                }
            }
            else -> {
                TopBar(player.name, onBack)
                CardRun(vm, player, card, logs, todays, hinge, bonusLeft = vm.store.pool.count { it.id !in loggedToday },
                    onPuzzle = onPuzzle) { bonusPicking = true }
            }
        }
    }
}

@Composable
private fun Picker(
    playerId: String,
    pool: List<EnrichedChore>,
    bonus: Boolean,
    hinge: Hinge?,
    onConfirm: (List<EnrichedChore>) -> Unit,
) {
    // Saved across fold/unfold and process death, so unfolding mid-pick keeps the selection.
    var picked by rememberSaveable(playerId, bonus) { mutableStateOf(listOf<String>()) }
    var suggested by rememberSaveable(playerId, bonus) { mutableStateOf(listOf<String>()) }
    val chosen = pool.filter { it.id in picked }
    val total = chosen.sumOf { it.currentMinutes }
    val remaining = if (bonus) Int.MAX_VALUE else Engine.DAILY_MINUTES - total
    val ready = Engine.cardReady(chosen, pool, bonus)
    val fb = LocalFeedback.current
    // Chime once when the card first becomes a full day (not on every recomposition or unfold).
    var wasReady by rememberSaveable(playerId, bonus) { mutableStateOf(false) }
    LaunchedEffect(ready) { if (ready && !wasReady && !bonus) fb.ready(); wasReady = ready }

    TwoZone(
        hinge,
        top = {
            LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
                item {
                    Text(
                        if (bonus) "log extra chores — no cap, all normal points"
                        else "pick what you want — then fill to ${Engine.DAILY_MINUTES} min",
                        color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 8.dp),
                    )
                }
                items(pool, key = { it.id }) { c ->
                    val isPicked = c.id in picked
                    val fits = isPicked || c.currentMinutes <= remaining
                    Box(Modifier.then(if (fits) Modifier else Modifier.padding(start = 0.dp))) {
                        ChoreRow(
                            name = c.name + if (c.id in suggested) " ✨" else "",
                            minutes = c.currentMinutes, escalLevel = c.escalLevel, checked = isPicked,
                            onToggle = {
                                if (isPicked) { fb.tick(false); picked = picked - c.id; suggested = suggested - c.id }
                                else if (fits) { fb.tick(true); picked = picked + c.id; suggested = suggested - c.id }
                                else fb.error()
                            },
                        )
                    }
                }
            }
        },
        bottom = {
            Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                Text(if (bonus) "${total}m" else "$total / ${Engine.DAILY_MINUTES}m", fontWeight = FontWeight.Bold)
                if (!bonus) {
                    Spacer(Modifier.height(6.dp))
                    MinutesBar(total, Engine.DAILY_MINUTES)
                    Spacer(Modifier.height(10.dp))
                    OutlinedButton(
                        onClick = {
                            fb.fill()
                            val next = Engine.suggestFill(picked, pool)
                            suggested = (suggested.filter { it in next } + next.filter { it !in picked }).distinct()
                            picked = next
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text(if (chosen.isEmpty()) "✨ suggest a ${Engine.DAILY_MINUTES}-min card" else "✨ fill to ${Engine.DAILY_MINUTES}m") }
                }
                Spacer(Modifier.height(8.dp))
                TermButton(
                    label = when {
                        ready && bonus -> "LOG ${chosen.size} CHORES"
                        ready -> "LOCK IN CARD"
                        chosen.isNotEmpty() -> "ADD MORE TO REACH ${Engine.DAILY_MINUTES}M"
                        bonus -> "PICK CHORES TO LOG"
                        else -> "PICK OR SUGGEST CHORES"
                    },
                    enabled = ready,
                ) { onConfirm(chosen) }
            }
        },
    )
}

@Composable
private fun CardRun(
    vm: AppViewModel,
    player: Player,
    card: Card,
    logs: List<ChoreLog>,
    todays: List<ChoreLog>,
    hinge: Hinge?,
    bonusLeft: Int,
    onPuzzle: () -> Unit,
    onBonus: () -> Unit,
) {
    val fb = LocalFeedback.current
    val now = remember(logs) { vm.now() }
    val shared by vm.store.state.collectAsState()
    val rank = Engine.rank(vm.totalXp(player.id, logs, shared))
    val streak = Engine.streak(player.id, logs, now, vm.zone)
    // Celebrate the first time this screen shows a new version (approval may have happened elsewhere).
    LaunchedEffect(player.id, rank.level) { if (vm.isNewLevel(player.id, rank.level)) fb.levelUp() }
    // A parent's verdict wins over "pending" if a chore has more than one row today.
    val statusByChore = HashMap<String, String>()
    for (l in todays) if (statusByChore[l.choreId].let { it == null || it == Status.PENDING }) statusByChore[l.choreId] = l.status
    val bonusLogs = todays.filter { it.choreId !in card.choreIds }.distinctBy { it.choreId }
    val allChecked = card.checked.all { it }
    val total = card.minutes.sum()

    TwoZone(
        hinge,
        top = {
            LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
                item { StatsHeader(rank, streak) }
                item { SectionLabel("today's card · ${total}m") }
                itemsIndexed(card.choreIds) { i, id ->
                    val c = vm.store.poolById[id]
                    ChoreRow(
                        name = c?.name ?: id, minutes = card.minutes[i],
                        escalLevel = card.escal.getOrElse(i) { 0 },
                        checked = card.checked[i],
                        status = if (card.submitted) statusByChore[id] ?: Status.PENDING else null,
                        onToggle = { fb.tick(!card.checked[i]); vm.toggle(player, card, i) },
                    )
                }
                if (bonusLogs.isNotEmpty()) {
                    item { SectionLabel("bonus round") }
                    items(bonusLogs, key = { it.id }) { l ->
                        ChoreRow(l.choreName, Engine.choreMinutes(l, vm.store.poolById), 0, checked = true, status = statusByChore[l.choreId])
                    }
                }
            }
        },
        bottom = {
            Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                if (!card.submitted) {
                    TermButton(if (allChecked) "SUBMIT FOR APPROVAL" else "CHECK OFF EVERYTHING FIRST", enabled = allChecked) {
                        vm.submit(player, card); fb.submit()
                    }
                    Text("🔒 the puzzle unlocks when this card is submitted", style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
                    Text("change my picks", color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.align(Alignment.CenterHorizontally).clickable { fb.tap(); vm.clearCard(player) }.padding(14.dp))
                } else {
                    // Say what's actually left: every chore logged today is pending, approved or rejected.
                    val verdicts = (card.choreIds + bonusLogs.map { it.choreId }).map { statusByChore[it] ?: Status.PENDING }
                    val waiting = verdicts.count { it == Status.PENDING }
                    val rejected = verdicts.count { it == Status.REJECTED }
                    val (line, lineColor) = when {
                        waiting == verdicts.size -> "card submitted — waiting on a parent" to MaterialTheme.colorScheme.onSurfaceVariant
                        waiting > 0 -> "$waiting of ${verdicts.size} still waiting on a parent" to MaterialTheme.colorScheme.onSurfaceVariant
                        rejected == 0 -> "✓ all approved — nice work" to Good
                        rejected == verdicts.size -> "✗ none approved today" to Bad
                        else -> "done — ${verdicts.size - rejected} approved, $rejected rejected" to MaterialTheme.colorScheme.onSurfaceVariant
                    }
                    Text(line, color = lineColor, modifier = Modifier.padding(bottom = 8.dp))
                    TermButton("PLAY · CLEAR THE GRID · LVL ${vm.puzzleLevel(player.id)}", modifier = Modifier.padding(bottom = 8.dp)) {
                        fb.unlock(); onPuzzle()
                    }
                    if (bonusLeft > 0) OutlinedButton(onClick = { fb.tap(); onBonus() }, modifier = Modifier.fillMaxWidth()) { Text("+ bonus round") }
                }
            }
        },
    )
}
