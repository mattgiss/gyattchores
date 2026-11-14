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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.engine.DisplayName
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
private fun TopBar(title: String, onBack: (() -> Unit)?, onName: (() -> Unit)? = null) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        if (onBack != null) TextButton(onClick = onBack) { Text("← back") }
        Text(title, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f).padding(horizontal = 8.dp, vertical = 12.dp))
        if (onName != null) TextButton(onClick = onName) { Text("✎ name") }
    }
}

/** A player's own nickname: no admin needed, and their username (what points are kept under) never changes. */
@Composable
private fun DisplayNameDialog(player: Player, onDismiss: () -> Unit, onSave: (String) -> Unit) {
    var draft by remember { mutableStateOf(player.displayName ?: "") }
    AlertDialog(
        onDismissRequest = onDismiss, title = { Text("Display name") },
        text = {
            Column {
                OutlinedTextField(draft, { draft = it }, singleLine = true, label = { Text("anything you like") })
                Text("Shown in place of your username, ${player.name}. Your chores and points stay exactly as they are. Up to ${DisplayName.MAX_LENGTH} characters.",
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
            }
        },
        confirmButton = { TextButton(onClick = { onSave(draft) }) { Text("save") } },
        dismissButton = { TextButton(onClick = { onSave("") }) { Text("use my username") } },
    )
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
    val family by vm.store.family.collectAsState()
    val pool = remember(logs, player.id, now, family) { vm.pickable(player.id, logs) }
    var bonusPicking by rememberSaveable(player.id) { mutableStateOf(false) }
    var naming by remember { mutableStateOf(false) }
    if (naming) DisplayNameDialog(player, onDismiss = { naming = false }) { vm.setDisplayName(player.id, it); naming = false }
    val fb = LocalFeedback.current

    val todays = vm.todaysLogs(player.id, logs)
    val statusToday = Engine.statusToday(todays)
    // One chore, one person, per day: what the other players have in today.
    val others = vm.takenByOthers(player.id, logs)
    // Used up for today: awaiting a parent, approved, or on the card and not yet submitted.
    // A rejected chore isn't — it can be done again.
    val taken = Engine.standingToday(statusToday) + card?.choreIds.orEmpty().filter { it !in statusToday } + others.keys

    Column(Modifier.fillMaxSize()) {
        when {
            card == null -> {
                TopBar(player.shownName, onBack) { naming = true }
                val notes = listOfNotNull(
                    "today's earlier chores were rejected — build a new card".takeIf { vm.rejectedToday(player.id, logs) },
                    "${others.size} chore${if (others.size == 1) "" else "s"} already taken by someone else today".takeIf { others.isNotEmpty() },
                )
                Picker(player.id, pool.filter { it.id !in others }, bonus = false, hinge = hinge, notes = notes) { vm.lockIn(player, it); fb.lockIn() }
            }
            bonusPicking -> {
                TopBar("${player.shownName} · bonus round", onBack = { bonusPicking = false })
                Picker(player.id, pool.filter { it.id !in taken }, bonus = true, hinge = hinge) {
                    vm.logBonus(player, it); fb.submit(); bonusPicking = false
                }
            }
            else -> {
                TopBar(player.shownName, onBack) { naming = true }
                CardRun(vm, player, card, logs, todays, others, hinge, bonusLeft = vm.store.pool.count { it.id !in taken },
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
    /** Shown above the list when there's something the player should know before picking. */
    notes: List<String> = emptyList(),
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
                items(notes) { note ->
                    Text(note, color = Warn, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(bottom = 8.dp))
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
    /** Chores another player has in today: chore id → their name. */
    others: Map<String, String>,
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
    // Approved wins; otherwise the latest log for a chore decides, so one redone after a rejection is awaiting again.
    val statusByChore = Engine.statusToday(todays)
    // Chores logged today that aren't on the card: bonus-round ones still standing, and ones a
    // parent rejected (from the bonus round, or from an earlier card that was rejected outright).
    val extras = todays.filter { it.choreId !in card.choreIds }.distinctBy { it.choreId }
    val bonusLogs = extras.filter { statusByChore[it.choreId] != Status.REJECTED }
    val rejectedExtras = extras.filter { statusByChore[it.choreId] == Status.REJECTED }
    // On a card that isn't submitted yet, a chore someone else got in first stays visible, marked
    // taken, and is left out when the card is submitted.
    val lost = if (card.submitted) emptyList() else card.choreIds.filter { it in others }
    val keep = card.choreIds.indices.filter { card.choreIds[it] !in lost }
    val allChecked = keep.isNotEmpty() && keep.all { card.checked[it] }
    val total = card.minutes.sum()

    TwoZone(
        hinge,
        top = {
            LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
                item { StatsHeader(rank, streak) }
                item { SectionLabel("today's card · ${total}m") }
                itemsIndexed(card.choreIds) { i, id ->
                    ChoreRow(
                        name = vm.choreName(id), minutes = card.minutes[i],
                        escalLevel = card.escal.getOrElse(i) { 0 },
                        checked = card.checked[i],
                        status = if (card.submitted) statusByChore[id] ?: Status.PENDING else if (id in lost) TAKEN else null,
                        onToggle = { fb.tick(!card.checked[i]); vm.toggle(player, card, i) },
                    )
                }
                if (bonusLogs.isNotEmpty()) {
                    item { SectionLabel("bonus round") }
                    items(bonusLogs, key = { it.id }) { l ->
                        ChoreRow(l.choreName, Engine.choreMinutes(l, vm.store.poolById), 0, checked = true, status = statusByChore[l.choreId])
                    }
                }
                // Kept off a card that's still being checked off, where it would only be in the way.
                if (card.submitted && rejectedExtras.isNotEmpty()) {
                    item { SectionLabel("rejected today") }
                    items(rejectedExtras, key = { it.id }) { l ->
                        ChoreRow(l.choreName, Engine.choreMinutes(l, vm.store.poolById), 0, checked = true, status = Status.REJECTED)
                    }
                }
            }
        },
        bottom = {
            Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                if (!card.submitted) {
                    if (lost.isNotEmpty()) Text("taken = someone else got it first today — it won't be submitted",
                        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = 8.dp))
                    TermButton(
                        when {
                            allChecked -> "SUBMIT FOR APPROVAL"
                            keep.isEmpty() -> "ALL TAKEN TODAY — CHANGE PICKS"
                            else -> "CHECK OFF EVERYTHING FIRST"
                        },
                        enabled = allChecked,
                    ) { vm.submit(player, card); fb.submit() }
                    Text("🔒 the puzzle unlocks when this card is submitted", style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
                    Text("change my picks", color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.align(Alignment.CenterHorizontally).clickable { fb.tap(); vm.clearCard(player) }.padding(14.dp))
                } else {
                    // Say what's actually left: every chore logged today is pending, approved or rejected.
                    val verdicts = (card.choreIds + extras.map { it.choreId }).map { statusByChore[it] ?: Status.PENDING }
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
                    if (rejected > 0) Text("rejected chores can be done again from the bonus round",
                        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = 8.dp))
                    TermButton("PLAY · CLEAR THE GRID · LVL ${vm.puzzleLevel(player.id)}", modifier = Modifier.padding(bottom = 8.dp)) {
                        fb.unlock(); onPuzzle()
                    }
                    if (bonusLeft > 0) OutlinedButton(onClick = { fb.tap(); onBonus() }, modifier = Modifier.fillMaxWidth()) { Text("+ bonus round") }
                }
            }
        },
    )
}
