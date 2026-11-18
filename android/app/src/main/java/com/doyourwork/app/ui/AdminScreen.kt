package com.doyourwork.app.ui

import com.doyourwork.app.engine.Phrase
import com.doyourwork.app.engine.Engine
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.background
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.doyourwork.app.AppViewModel
import com.doyourwork.app.engine.ChoreIntake
import com.doyourwork.app.model.Chore
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Player
import com.doyourwork.app.model.Status
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

private fun biometricAvailable(activity: FragmentActivity) =
    BiometricManager.from(activity).canAuthenticate(BIOMETRIC_WEAK) == BiometricManager.BIOMETRIC_SUCCESS

private fun promptBiometric(activity: FragmentActivity, onOk: () -> Unit) {
    val prompt = BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), object : BiometricPrompt.AuthenticationCallback() {
        override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onOk()
    })
    prompt.authenticate(
        BiometricPrompt.PromptInfo.Builder()
            .setTitle("Admin access").setSubtitle("Open the admin area")
            .setNegativeButtonText("Use code").setAllowedAuthenticators(BIOMETRIC_WEAK).build()
    )
}

/** Admin area: any admin's code; fingerprint/face too, but only once an admin has turned it on for this phone. */
@Composable
fun AdminScreen(vm: AppViewModel, logs: List<ChoreLog>, onBack: (() -> Unit)?) {
    // Not saved: leaving the screen or killing the app locks it again.
    var authed by remember { mutableStateOf(false) }
    val activity = LocalContext.current as FragmentActivity
    val fb = LocalFeedback.current
    val bioOn by vm.biometricUnlock.collectAsState()
    val linked by vm.relayLinked.collectAsState()
    LaunchedEffect(authed) { if (authed) fb.unlock() }

    // The admin area is in Clear's ocean theme, so it's plain at a glance which mode you're in.
    CompositionLocalProvider(LocalPalette provides Palette.OCEAN) {
    Column(Modifier.fillMaxSize().background(Bg)) {
        Row(Modifier.fillMaxWidth().background(Palette.OCEAN.stops[0]).statusBarsPadding().padding(start = 4.dp, end = 12.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) TextButton(onClick = onBack) { Text("Back", color = Palette.OCEAN.ink, fontWeight = FontWeight.Bold) }
            Text("Admin", color = Palette.OCEAN.ink, fontSize = 24.sp, fontWeight = FontWeight.Black, modifier = Modifier.padding(horizontal = 12.dp))
        }
        if (!authed) {
            val canBio = remember(bioOn) { bioOn && biometricAvailable(activity) }
            LaunchedEffect(canBio) { if (canBio) promptBiometric(activity) { authed = true } }
            var code by remember { mutableStateOf("") }
            var wrong by remember { mutableStateOf(false) }
            // The keyboard comes up straight away, unless a fingerprint prompt is about to.
            val focus = remember { FocusRequester() }
            LaunchedEffect(Unit) { if (!canBio) runCatching { focus.requestFocus() } }
            val verify = { if (vm.checkAdminCode(code)) authed = true else { wrong = true; code = ""; fb.error() } }
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = code, onValueChange = { code = it; wrong = false }, label = { Text("Admin code") },
                    singleLine = true, isError = wrong, visualTransformation = PasswordVisualTransformation(),
                    supportingText = { if (wrong) Text("That code didn't match.") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { verify() }), modifier = Modifier.fillMaxWidth().focusRequester(focus),
                )
                TermButton("Unlock", enabled = code.isNotEmpty(), modifier = Modifier.bleed(20.dp)) { verify() }
                if (canBio) QuietButton("Use my fingerprint or face", Modifier.bleed(20.dp)) { promptBiometric(activity) { authed = true } }
                Text(if (linked) "Forgot your code? Another admin can set a new one for you."
                    else "Forgot your code? It's only kept on this phone, so it can't be looked up. Clearing the app's data starts a new scoreboard.",
                    style = MaterialTheme.typography.bodyMedium, color = Done)
            }
        } else {
            AdminContent(vm, logs)
        }
    }
    }
}

@Composable
private fun AdminContent(vm: AppViewModel, logs: List<ChoreLog>) {
    var filter by rememberSaveable { mutableStateOf(Status.PENDING) }
    val fb = LocalFeedback.current
    val family by vm.store.family.collectAsState()
    val bioOn by vm.biometricUnlock.collectAsState()
    val names = family.members.associate { it.id to it.shownName }
    val shown = logs.filter { filter == "all" || it.status == filter }.sortedByDescending { it.timestamp }
    val fmt = remember { DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT).withZone(vm.zone) }
    var editing by remember { mutableStateOf<Player?>(null) }
    var adding by remember { mutableStateOf(false) }
    var editingChore by remember { mutableStateOf<Chore?>(null) }
    var addingChores by remember { mutableStateOf(false) }
    var confirmingErase by remember { mutableStateOf(false) }
    val me by vm.store.me.collectAsState()
    val linked by vm.relayLinked.collectAsState()
    val activity = LocalContext.current as FragmentActivity
    val canBio = remember { biometricAvailable(activity) }
    val pool = family.chores ?: vm.store.starterChores
    val (saveBackup, restoreBackup) = rememberBackup(vm)

    if (addingChores) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Add chores", color = Accent, style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
                TextButton(onClick = { addingChores = false }) { Text("Cancel") }
            }
            ChoreIntakePanel(pool) { vm.addChores(it); fb.submit(); addingChores = false }
        }
        return
    }

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        item {
            Row(Modifier.padding(vertical = 12.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (f in listOf(Status.PENDING, Status.APPROVED, Status.REJECTED, "all")) {
                    FilterChip(selected = filter == f, onClick = { filter = f }, label = {
                        Text(when (f) { Status.PENDING -> "Waiting"; Status.APPROVED -> "Approved"; Status.REJECTED -> "Turned down"; else -> "Everything" })
                    })
                }
            }
        }
        if (filter == Status.PENDING) {
            val byPlayer = shown.groupBy { it.playerId }.filterValues { it.size > 1 }
            items(byPlayer.keys.toList(), key = { "all$it" }) { id ->
                val mine = byPlayer.getValue(id)
                TermButton("Approve all ${mine.size} of ${names[id] ?: mine.first().playerName}'s chores", modifier = Modifier.bleed(20.dp).padding(top = 6.dp)) {
                    if (vm.approveAll(mine)) fb.levelUp() else fb.approve()
                }
            }
        }
        if (shown.isEmpty()) item {
            Text(when (filter) {
                Status.PENDING -> "Nothing's waiting for you. All caught up!"
                Status.APPROVED -> "Nothing's been approved yet."
                Status.REJECTED -> "Nothing's been turned down."
                else -> "Nobody's logged a chore yet."
            }, color = Done, modifier = Modifier.padding(vertical = 24.dp))
        }
        // Each chore as a sentence, the way you'd hear about it: "Sam emptied the kids bathroom trash
        // today. Approve it?" Waiting ones are bands down the ocean gradient; judged ones drop to black.
        itemsIndexed(shown, key = { _, l -> l.id }) { i, l ->
            val waiting = l.status == Status.PENDING
            val who = names[l.playerId] ?: l.playerName
            val said = Phrase.sentence(who, l.choreName, Engine.dayOf(l.timestamp, vm.zone), vm.today())
            Band(i, shown.size, Modifier.bleed(20.dp), done = !waiting, minHeight = 60.dp) {
                Column(Modifier.weight(1f)) {
                    Text(said, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, color = if (waiting) Palette.OCEAN.ink else Ink.copy(alpha = 0.75f))
                    Text(when (l.status) {
                        Status.PENDING -> "Worth ${l.points} points. Approve it?"
                        Status.APPROVED -> "Approved · ${l.points} points"
                        else -> "Turned down"
                    }, style = MaterialTheme.typography.bodyMedium, color = if (waiting) Palette.OCEAN.ink.copy(alpha = 0.85f) else if (l.status == Status.APPROVED) Good else Bad)
                }
                if (waiting) {
                    Text("Yes", fontWeight = FontWeight.Black, color = Palette.OCEAN.stops[0],
                        modifier = Modifier.clip(CircleShape).background(Palette.OCEAN.ink).clickable(onClickLabel = "Approve this chore") { if (vm.approve(l)) fb.levelUp() else fb.approve() }
                            .padding(horizontal = 16.dp, vertical = 12.dp))
                    Text("No", fontWeight = FontWeight.Black, color = Palette.OCEAN.ink,
                        modifier = Modifier.clip(CircleShape).border(2.dp, Palette.OCEAN.ink.copy(alpha = 0.8f), CircleShape)
                            .clickable(onClickLabel = "Turn down this chore") { vm.setStatus(l, Status.REJECTED); fb.reject() }.padding(horizontal = 16.dp, vertical = 12.dp))
                }
            }
        }
        if (linked && family.players.isNotEmpty()) {
            item { SectionLabel("this phone belongs to", padded = false) }
            item {
                Text("Dares are made as this person. Only an admin can change it.",
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (p in family.players) FilterChip(selected = p.id == me, onClick = { vm.setMe(p) }, label = { Text(p.shownName) })
                }
            }
        }
        item { SectionLabel("people", padded = false) }
        item { Text("Admins approve chores and can change everything here. Each admin has their own code.",
            style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(family.members, key = { "p" + it.id }) { p ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(p.adminLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    val roles = listOfNotNull("Admin".takeIf { p.isAdmin }, (if (p.isAdmin) "does chores" else "Does chores").takeIf { p.plays })
                    Text(roles.joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                TextButton(onClick = { fb.tap(); editing = p }) { Text("Edit") }
            }
        }
        item { OutlinedButton(onClick = { fb.tap(); adding = true }, modifier = Modifier.padding(vertical = 12.dp)) { Text("Add a player") } }

        item { SectionLabel("chores", padded = false) }
        item { Text("${pool.size} chores. Left undone, a chore takes longer the next time it's picked.",
            style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        item { OutlinedButton(onClick = { fb.tap(); addingChores = true }, modifier = Modifier.padding(vertical = 12.dp)) { Text("Add chores") } }
        items(pool, key = { "c" + it.id }) { c ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(c.name, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("${c.tiers.firstOrNull() ?: 0}m", color = MaterialTheme.colorScheme.onSurfaceVariant)
                TextButton(onClick = { fb.tap(); editingChore = c }) { Text("Edit") }
            }
        }

        item { SectionLabel("this phone", padded = false) }
        if (canBio) item {
            SwitchRow("Fingerprint or face opens Admin", bioOn) { vm.setBiometricUnlock(it) }
            Text("Only turn this on if this is your own phone, not a player's.",
                style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        item {
            Text(if (linked) "The family's players, chores and points are shared with your family's phones, encrypted on this phone before they're sent, so only those phones can read them. Resetting this phone clears what it keeps and fetches the family again. Nothing is deleted for anyone else."
                else "Everything this app knows, from names to chores and points, is kept on this phone and nowhere else. There's no account and nothing is sent to anyone, including us. Uninstalling the app deletes it all.",
                style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                OutlinedButton(onClick = { fb.tap(); saveBackup() }) { Text("Save a backup…") }
                OutlinedButton(onClick = { fb.tap(); restoreBackup() }) { Text("Restore…") }
            }
            Text(if (linked) "A backup holds the family's players, chores, history and admin codes (scrambled). Restoring adds a backup to the family. It never removes anyone."
                else "A backup holds everything here, admin codes included (scrambled). Restoring one replaces what's on this phone.",
                style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
            TextButton(onClick = { confirmingErase = true }, modifier = Modifier.padding(vertical = 8.dp)) {
                Text(if (linked) "Reset this phone…" else "Erase everything…", color = Bad)
            }
        }
        item { PhonesSection(vm) }
    }

    editing?.let { m -> MemberDialog(vm, m, onDismiss = { editing = null }) }
    if (adding) MemberDialog(vm, null, onDismiss = { adding = false })
    editingChore?.let { c -> ChoreDialog(vm, c, pool, onDismiss = { editingChore = null }) }
    if (confirmingErase) AlertDialog(
        onDismissRequest = { confirmingErase = false },
        title = { Text(if (linked) "Reset this phone?" else "Erase everything?") },
        text = { Text(if (linked) "This phone forgets what it keeps and fetches the family again. Nobody else is affected."
            else "Players, chores and points are deleted from this phone and the app starts over. This can't be undone.") },
        confirmButton = { TextButton(onClick = { fb.reject(); confirmingErase = false; vm.eraseEverything() }) {
            Text(if (linked) "Reset" else "Erase players, chores and points", color = Bad) } },
        dismissButton = { TextButton(onClick = { confirmingErase = false }) { Text("Cancel") } },
    )
}

/** Add someone ([member] null) or change them: names, chores or admin or both, and an admin's code. */
@Composable
private fun MemberDialog(vm: AppViewModel, member: Player?, onDismiss: () -> Unit) {
    var d by remember { mutableStateOf(member?.let(vm::draft) ?: AppViewModel.MemberDraft()) }
    var confirmingRemove by remember { mutableStateOf(false) }
    val problem = vm.problem(d, member?.id)
    val fb = LocalFeedback.current
    AlertDialog(
        onDismissRequest = onDismiss, title = { Text(if (member == null) "Add player" else "Edit ${member.name}") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState())) {
                OutlinedTextField(d.name, { d = d.copy(name = it) }, singleLine = true, label = { Text("Username") })
                OutlinedTextField(d.displayName, { d = d.copy(displayName = it) }, singleLine = true, label = { Text("Display name (optional)") })
                Text("The display name is only what's shown. The username is what chores and points are kept under.",
                    style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                SwitchRow("Does chores", d.plays) { d = d.copy(plays = it) }
                SwitchRow("Admin", d.isAdmin) { d = d.copy(isAdmin = it) }
                if (d.isAdmin) CodeField(d.newCode, if (member?.isAdmin == true) "New code (leave empty to keep it)" else "Their admin code") { d = d.copy(newCode = it) }
                if (problem != null) Text(problem, color = Bad, style = MaterialTheme.typography.labelMedium)
                if (member != null && vm.canRemove(member)) TextButton(onClick = { confirmingRemove = true }) { Text("Remove ${member.name}…", color = Bad) }
            }
        },
        confirmButton = { TextButton(onClick = { if (vm.saveMember(d, member?.id)) { fb.approve(); onDismiss() } }, enabled = problem == null) { Text("Save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
    if (confirmingRemove && member != null) AlertDialog(
        onDismissRequest = { confirmingRemove = false }, title = { Text("Remove ${member.name}?") },
        text = { Text("Their chores and points are deleted${if (vm.relayLinked.value) " from the family's phones" else " from this phone"}. This can't be undone.") },
        confirmButton = { TextButton(onClick = { vm.removeMember(member); fb.reject(); confirmingRemove = false; onDismiss() }) {
            Text("Remove and delete their history", color = Bad) } },
        dismissButton = { TextButton(onClick = { confirmingRemove = false }) { Text("Cancel") } },
    )
}

@Composable
private fun ChoreDialog(vm: AppViewModel, chore: Chore, pool: List<Chore>, onDismiss: () -> Unit) {
    var name by remember { mutableStateOf(chore.name) }
    var minutes by remember { mutableStateOf(chore.tiers.firstOrNull() ?: 5) }
    val fb = LocalFeedback.current
    val clean = ChoreIntake.tidyName(name)
    val clash = clean != null && pool.any { it.id != chore.id && it.name.equals(clean, ignoreCase = true) }
    AlertDialog(
        onDismissRequest = onDismiss, title = { Text("Edit chore") },
        text = {
            Column {
                OutlinedTextField(name, { name = it }, singleLine = true, label = { Text("Chore") })
                MinuteStepper(minutes) { minutes = it }
                Text("Worth ${ChoreIntake.make("x", minutes).pts} points.", style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (clash) Text("There's already a chore with that name.", color = Bad, style = MaterialTheme.typography.labelMedium)
                if (pool.size > 1) TextButton(onClick = { vm.removeChore(chore); fb.reject(); onDismiss() }) { Text("Remove this chore", color = Bad) }
                Text("Points already earned for it are kept.", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        confirmButton = { TextButton(onClick = { vm.updateChore(chore, name, minutes); fb.approve(); onDismiss() }, enabled = clean != null && !clash) { Text("Save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
