package com.gyattchores.app.ui

import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.background
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
import com.gyattchores.app.engine.Phrase
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

/**
 * The screen's first band: who this is (and, on their day, their version and streak) in white on
 * red, running up under the status bar.
 */
@Composable
private fun TopBar(title: String, onBack: (() -> Unit)?, onName: (() -> Unit)? = null, stats: (@Composable () -> Unit)? = null) {
    val ink = Palette.HEAT.ink
    Column(Modifier.fillMaxWidth().background(Palette.HEAT.stops[0]).statusBarsPadding().padding(start = 4.dp, end = 4.dp, bottom = 12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) TextButton(onClick = onBack) { Text("Back", color = ink, fontWeight = FontWeight.Bold) }
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black, color = ink, maxLines = 1, overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).padding(horizontal = 12.dp, vertical = 8.dp))
            if (onName != null) TextButton(onClick = onName) { Text("Rename", color = ink, fontWeight = FontWeight.Bold) }
        }
        if (stats != null) Box(Modifier.padding(horizontal = 12.dp)) { stats() }
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
                OutlinedTextField(draft, { draft = it }, singleLine = true, label = { Text("Anything you like") })
                Text("Shown in place of your username, ${player.name}. Your chores and points stay exactly as they are. Up to ${DisplayName.MAX_LENGTH} characters.",
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
            }
        },
        confirmButton = { TextButton(onClick = { onSave(draft) }) { Text("Save") } },
        dismissButton = { TextButton(onClick = { onSave("") }) { Text("Use my username") } },
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

    val shared by vm.store.state.collectAsState()
    val rank = Engine.rank(vm.totalXp(player.id, logs, shared))
    val streak = Engine.streak(player.id, logs, now, vm.zone)
    val stats = @Composable { StatsHeader(rank, streak) }
    Column(Modifier.fillMaxSize().background(Bg)) {
        when {
            card == null -> {
                TopBar(player.shownName, onBack, { naming = true }, stats)
                val notes = listOfNotNull(
                    "Today's earlier chores were turned down, so let's build a new card.".takeIf { vm.rejectedToday(player.id, logs) },
                    "Someone else already has ${if (others.size == 1) "one" else "${others.size}"} of today's chores.".takeIf { others.isNotEmpty() },
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
                TopBar(player.shownName, onBack, { naming = true }, stats)
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
            LazyColumn(Modifier.fillMaxSize()) {
                item {
                    Text(
                        if (bonus) "Did a bit extra today? Pick what you did. Every chore still earns its points."
                        else "Pick what you'd like to do today, then fill it up to ${Engine.DAILY_MINUTES} minutes.",
                        color = Done, modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
                    )
                }
                items(notes) { note ->
                    Text(note, color = Warn, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(horizontal = 20.dp).padding(bottom = 10.dp))
                }
                itemsIndexed(pool, key = { _, c -> c.id }) { i, c ->
                    val isPicked = c.id in picked
                    val fits = isPicked || c.currentMinutes <= remaining
                    Box(Modifier.then(if (fits) Modifier else Modifier.padding(start = 0.dp))) {
                        ChoreRow(
                            name = c.name,
                            minutes = c.currentMinutes, escalLevel = c.escalLevel, checked = isPicked,
                            index = i, count = pool.size, picking = true,
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
            Column(Modifier.fillMaxWidth()) {
                Text(if (bonus) Phrase.count(total, "minute") else "$total of ${Engine.DAILY_MINUTES} minutes", fontWeight = FontWeight.Black,
                    style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp))
                if (!bonus) {
                    MinutesBar(total, Engine.DAILY_MINUTES)
                    QuietButton(
                        if (chosen.isEmpty()) "Suggest a ${Engine.DAILY_MINUTES}-minute card" else "Fill it up to ${Engine.DAILY_MINUTES} minutes",
                        onClick = {
                            fb.fill()
                            val next = Engine.suggestFill(picked, pool)
                            suggested = (suggested.filter { it in next } + next.filter { it !in picked }).distinct()
                            picked = next
                        },
                    )
                }
                TermButton(
                    label = when {
                        ready && bonus -> "Log ${if (chosen.size == 1) "this chore" else "these ${chosen.size} chores"}"
                        ready -> "Lock in my card"
                        chosen.isNotEmpty() -> "Add a few more to reach ${Engine.DAILY_MINUTES} minutes"
                        bonus -> "Pick the chores you did"
                        else -> "Pick some chores, or let me suggest some"
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
    val shared by vm.store.state.collectAsState()
    val rank = Engine.rank(vm.totalXp(player.id, logs, shared))
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
            // One gradient down the whole day: the card, then the bonus round, then anything turned down.
            val rows = card.choreIds.size + bonusLogs.size + if (card.submitted) rejectedExtras.size else 0
            LazyColumn(Modifier.fillMaxSize()) {
                item { SectionLabel("Today's card · ${Phrase.count(total, "minute")}") }
                itemsIndexed(card.choreIds) { i, id ->
                    ChoreRow(
                        name = vm.choreName(id), minutes = card.minutes[i],
                        escalLevel = card.escal.getOrElse(i) { 0 },
                        checked = card.checked[i],
                        status = if (card.submitted) statusByChore[id] ?: Status.PENDING else if (id in lost) TAKEN else null,
                        index = i, count = rows,
                        onToggle = { fb.tick(!card.checked[i]); vm.toggle(player, card, i) },
                    )
                }
                if (bonusLogs.isNotEmpty()) {
                    item { SectionLabel("Bonus round") }
                    itemsIndexed(bonusLogs, key = { _, l -> l.id }) { i, l ->
                        ChoreRow(l.choreName, Engine.choreMinutes(l, vm.store.poolById), 0, checked = true, status = statusByChore[l.choreId],
                            index = card.choreIds.size + i, count = rows)
                    }
                }
                // Kept off a card that's still being checked off, where it would only be in the way.
                if (card.submitted && rejectedExtras.isNotEmpty()) {
                    item { SectionLabel("Turned down today") }
                    items(rejectedExtras, key = { it.id }) { l ->
                        ChoreRow(l.choreName, Engine.choreMinutes(l, vm.store.poolById), 0, checked = true, status = Status.REJECTED)
                    }
                }
            }
        },
        bottom = {
            Column(Modifier.fillMaxWidth()) {
                if (!card.submitted) {
                    if (lost.isNotEmpty()) Text("Someone else got to the ones marked taken first, so they won't be sent.",
                        style = MaterialTheme.typography.bodyMedium, color = Done, modifier = Modifier.padding(horizontal = 20.dp).padding(bottom = 8.dp))
                    Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("The puzzle opens once you send your card.", style = MaterialTheme.typography.bodyMedium, color = Done, modifier = Modifier.weight(1f))
                        Text("Change my picks", color = Ink, fontWeight = FontWeight.Bold,
                            modifier = Modifier.clickable { fb.tap(); vm.clearCard(player) }.padding(vertical = 14.dp, horizontal = 4.dp))
                    }
                    TermButton(
                        when {
                            allChecked -> "Send it off for approval"
                            keep.isEmpty() -> "Everything's been taken today. Change your picks"
                            else -> "Check everything off first"
                        },
                        enabled = allChecked,
                    ) { vm.submit(player, card); fb.submit() }
                } else {
                    // Say what's actually left: every chore logged today is pending, approved or rejected.
                    val verdicts = (card.choreIds + extras.map { it.choreId }).map { statusByChore[it] ?: Status.PENDING }
                    val waiting = verdicts.count { it == Status.PENDING }
                    val rejected = verdicts.count { it == Status.REJECTED }
                    val (line, lineColor) = when {
                        waiting == verdicts.size -> "Sent! Now it's waiting for an admin to look at it." to Done
                        waiting > 0 -> "$waiting of ${verdicts.size} are still waiting for an admin." to Done
                        rejected == 0 -> "Everything's approved. Nice work!" to Good
                        rejected == verdicts.size -> "None of today's chores were approved." to Bad
                        else -> "${verdicts.size - rejected} approved and $rejected turned down." to Done
                    }
                    Text(line, color = lineColor, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp))
                    if (rejected > 0) Text("You can redo the turned-down ones in a bonus round.",
                        style = MaterialTheme.typography.bodyMedium, color = Done, modifier = Modifier.padding(horizontal = 20.dp).padding(bottom = 10.dp))
                    val minutesLeft = com.gyattchores.app.engine.PuzzleTime.minutesLeft(vm.puzzleUsedMs(player.id))
                    if (minutesLeft > 0) {
                        val level = vm.puzzleLevel(player.id)
                        // On a narrow phone the minutes left matter more than the puzzle's name.
                        TermButton("Play level $level · ${Phrase.count(minutesLeft, "minute")} left today",
                            shortLabel = "Play level $level · $minutesLeft min left") {
                            fb.unlock(); onPuzzle()
                        }
                    } else {
                        Text("That's your hour of puzzles for today. See you tomorrow!", color = Done,
                            modifier = Modifier.padding(horizontal = 20.dp, vertical = 18.dp))
                    }
                    if (bonusLeft > 0) QuietButton("Do a bonus round") { fb.tap(); onBonus() }
                }
            }
        },
    )
}
