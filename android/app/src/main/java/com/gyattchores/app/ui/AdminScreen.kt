package com.gyattchores.app.ui

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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.engine.ChoreIntake
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Player
import com.gyattchores.app.model.Status
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
    LaunchedEffect(authed) { if (authed) fb.unlock() }

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) TextButton(onClick = onBack) { Text("← back") }
            Text("ADMIN", color = Accent, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(12.dp))
        }
        if (!authed) {
            val canBio = remember(bioOn) { bioOn && biometricAvailable(activity) }
            LaunchedEffect(canBio) { if (canBio) promptBiometric(activity) { authed = true } }
            var code by remember { mutableStateOf("") }
            var wrong by remember { mutableStateOf(false) }
            val verify = { if (vm.checkAdminCode(code)) authed = true else { wrong = true; code = ""; fb.error() } }
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = code, onValueChange = { code = it; wrong = false }, label = { Text("admin code") },
                    singleLine = true, isError = wrong, visualTransformation = PasswordVisualTransformation(),
                    supportingText = { if (wrong) Text("that code didn't match") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { verify() }), modifier = Modifier.fillMaxWidth(),
                )
                TermButton("UNLOCK", enabled = code.isNotEmpty()) { verify() }
                if (canBio) OutlinedButton(onClick = { promptBiometric(activity) { authed = true } }, modifier = Modifier.fillMaxWidth()) {
                    Text("use fingerprint / face")
                }
                Text(if (vm.familySync) "forgot the code? another admin can set a new one for you."
                    else "forgot the code? it's kept only on this phone, so it can't be looked up. erasing the app's data starts a new scoreboard.",
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            AdminContent(vm, logs)
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
    val activity = LocalContext.current as FragmentActivity
    val canBio = remember { biometricAvailable(activity) }
    val pool = family.chores ?: vm.store.starterChores
    val (saveBackup, restoreBackup) = rememberBackup(vm)

    if (addingChores) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("ADD CHORES", color = Accent, style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
                TextButton(onClick = { addingChores = false }) { Text("cancel") }
            }
            ChoreIntakePanel(pool) { vm.addChores(it); fb.submit(); addingChores = false }
        }
        return
    }

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        item {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (f in listOf(Status.PENDING, Status.APPROVED, Status.REJECTED, "all")) {
                    FilterChip(selected = filter == f, onClick = { filter = f }, label = { Text(f) })
                }
            }
        }
        if (shown.isEmpty()) item { Text("nothing ${if (filter == "all") "logged yet" else filter}", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 24.dp)) }
        items(shown, key = { it.id }) { l ->
            Column(Modifier.padding(vertical = 10.dp)) {
                Text("${names[l.playerId] ?: l.playerName} · ${l.choreName}", style = MaterialTheme.typography.bodyLarge)
                Text("${l.points} xp · ${l.minutes?.let { "${it}m · " } ?: ""}${fmt.format(Instant.ofEpochMilli(l.timestamp))} · ${l.status}",
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (l.status == Status.PENDING) Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 6.dp)) {
                    OutlinedButton(onClick = { if (vm.approve(l)) fb.levelUp() else fb.approve() }) { Text("✓ approve", color = Good) }
                    OutlinedButton(onClick = { vm.setStatus(l, Status.REJECTED); fb.reject() }) { Text("✗ reject", color = Bad) }
                }
            }
            HorizontalDivider()
        }
        if (vm.familySync && family.players.isNotEmpty()) {
            item { SectionLabel("this phone belongs to") }
            item {
                Text("dares are made as this person. only an admin can change it.",
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (p in family.players) FilterChip(selected = p.id == me, onClick = { vm.setMe(p) }, label = { Text(p.shownName) })
                }
            }
        }
        item { SectionLabel("people") }
        item { Text("admins approve chores and can change everything here. each admin has their own code.",
            style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(family.members, key = { "p" + it.id }) { p ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(p.adminLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    val roles = listOfNotNull("admin".takeIf { p.isAdmin }, "does chores".takeIf { p.plays })
                    Text(roles.joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                TextButton(onClick = { fb.tap(); editing = p }) { Text("edit") }
            }
        }
        item { OutlinedButton(onClick = { fb.tap(); adding = true }, modifier = Modifier.padding(vertical = 12.dp)) { Text("+ add player") } }

        item { SectionLabel("chores") }
        item { Text("${pool.size} chores. left undone, a chore takes longer the next time it's picked.",
            style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        item { OutlinedButton(onClick = { fb.tap(); addingChores = true }, modifier = Modifier.padding(vertical = 12.dp)) { Text("+ add chores") } }
        items(pool, key = { "c" + it.id }) { c ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(c.name, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("${c.tiers.firstOrNull() ?: 0}m", color = MaterialTheme.colorScheme.onSurfaceVariant)
                TextButton(onClick = { fb.tap(); editingChore = c }) { Text("edit") }
            }
        }

        item { SectionLabel("this phone") }
        if (canBio) item {
            SwitchRow("fingerprint / face opens the admin area", bioOn) { vm.setBiometricUnlock(it) }
            Text("only turn this on if this is your own phone, not a player's.",
                style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        item {
            Text(if (vm.familySync) "this edition keeps the family's players, chores and points in step across your family's phones. resetting this phone clears what it keeps and fetches the family again; nothing is deleted for anyone else."
                else "everything this app knows — names, chores and points — is kept on this phone and nowhere else. there's no account and nothing is sent to anyone, including us. uninstalling the app deletes it all.",
                style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                OutlinedButton(onClick = { fb.tap(); saveBackup() }) { Text("save a backup…") }
                OutlinedButton(onClick = { fb.tap(); restoreBackup() }) { Text("restore…") }
            }
            Text(if (vm.familySync) "a backup holds the family's players, chores, history and admin codes (scrambled). restoring adds a backup to the family; it never removes anyone."
                else "a backup holds everything here, admin codes included (scrambled). restoring one replaces what's on this phone.",
                style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
            TextButton(onClick = { confirmingErase = true }, modifier = Modifier.padding(vertical = 8.dp)) {
                Text(if (vm.familySync) "reset this phone…" else "erase everything…", color = Bad)
            }
        }
    }

    editing?.let { m -> MemberDialog(vm, m, onDismiss = { editing = null }) }
    if (adding) MemberDialog(vm, null, onDismiss = { adding = false })
    editingChore?.let { c -> ChoreDialog(vm, c, pool, onDismiss = { editingChore = null }) }
    if (confirmingErase) AlertDialog(
        onDismissRequest = { confirmingErase = false },
        title = { Text(if (vm.familySync) "Reset this phone?" else "Erase everything?") },
        text = { Text(if (vm.familySync) "This phone forgets what it keeps and fetches the family again. Nobody else is affected."
            else "Players, chores and points are deleted from this phone and the app starts over. This can't be undone.") },
        confirmButton = { TextButton(onClick = { fb.reject(); confirmingErase = false; vm.eraseEverything() }) {
            Text(if (vm.familySync) "reset" else "erase players, chores and points", color = Bad) } },
        dismissButton = { TextButton(onClick = { confirmingErase = false }) { Text("cancel") } },
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
                OutlinedTextField(d.name, { d = d.copy(name = it) }, singleLine = true, label = { Text("username") })
                OutlinedTextField(d.displayName, { d = d.copy(displayName = it) }, singleLine = true, label = { Text("display name (optional)") })
                Text("the display name is only what's shown; the username is what chores and points are kept under.",
                    style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                SwitchRow("does chores", d.plays) { d = d.copy(plays = it) }
                SwitchRow("admin", d.isAdmin) { d = d.copy(isAdmin = it) }
                if (d.isAdmin) CodeField(d.newCode, if (member?.isAdmin == true) "new code (leave empty to keep it)" else "their admin code") { d = d.copy(newCode = it) }
                if (problem != null) Text(problem, color = Bad, style = MaterialTheme.typography.labelMedium)
                if (member != null && vm.canRemove(member)) TextButton(onClick = { confirmingRemove = true }) { Text("remove ${member.name}…", color = Bad) }
            }
        },
        confirmButton = { TextButton(onClick = { if (vm.saveMember(d, member?.id)) { fb.approve(); onDismiss() } }, enabled = problem == null) { Text("save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("cancel") } },
    )
    if (confirmingRemove && member != null) AlertDialog(
        onDismissRequest = { confirmingRemove = false }, title = { Text("Remove ${member.name}?") },
        text = { Text("Their chores and points are deleted${if (vm.familySync) " from the family's phones" else " from this phone"}. This can't be undone.") },
        confirmButton = { TextButton(onClick = { vm.removeMember(member); fb.reject(); confirmingRemove = false; onDismiss() }) {
            Text("remove and delete their history", color = Bad) } },
        dismissButton = { TextButton(onClick = { confirmingRemove = false }) { Text("cancel") } },
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
                OutlinedTextField(name, { name = it }, singleLine = true, label = { Text("chore") })
                MinuteStepper(minutes) { minutes = it }
                Text("worth ${ChoreIntake.make("x", minutes).pts} points.", style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (clash) Text("there's already a chore with that name", color = Bad, style = MaterialTheme.typography.labelMedium)
                if (pool.size > 1) TextButton(onClick = { vm.removeChore(chore); fb.reject(); onDismiss() }) { Text("remove this chore", color = Bad) }
                Text("points already earned for it are kept.", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        confirmButton = { TextButton(onClick = { vm.updateChore(chore, name, minutes); fb.approve(); onDismiss() }, enabled = clean != null && !clash) { Text("save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("cancel") } },
    )
}
