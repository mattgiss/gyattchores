package com.gyattchores.app.ui

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.EnrichedChore
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
            .setTitle("Parent access").setSubtitle("Unlock chore approvals")
            .setNegativeButtonText("Use code").setAllowedAuthenticators(BIOMETRIC_WEAK).build()
    )
}

/** Parent area: fingerprint/face first, the web app's admin code as the fallback. */
@Composable
fun AdminScreen(vm: AppViewModel, logs: List<ChoreLog>, players: List<Player>, onBack: (() -> Unit)?) {
    // Not saved: leaving the screen or killing the app locks it again.
    var authed by remember { mutableStateOf(false) }
    val activity = LocalContext.current as FragmentActivity
    val fb = LocalFeedback.current
    LaunchedEffect(authed) { if (authed) fb.unlock() }

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) TextButton(onClick = onBack) { Text("← back") }
            Text("ADMIN", color = Accent, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(12.dp))
        }
        if (!authed) {
            val canBio = remember { biometricAvailable(activity) }
            LaunchedEffect(Unit) { if (canBio) promptBiometric(activity) { authed = true } }
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
            }
        } else {
            AdminContent(vm, logs, players)
        }
    }
}

@Composable
private fun AdminContent(vm: AppViewModel, logs: List<ChoreLog>, players: List<Player>) {
    var filter by rememberSaveable { mutableStateOf(Status.PENDING) }
    val fb = LocalFeedback.current
    val shown = logs.filter { filter == "all" || it.status == filter }.sortedByDescending { it.timestamp }
    val fmt = remember { DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT).withZone(vm.zone) }
    var editing by remember { mutableStateOf<Player?>(null) }
    var adding by remember { mutableStateOf(false) }
    var pickingFor by remember { mutableStateOf<Player?>(null) }
    val picks by vm.store.pickEntries.collectAsState()

    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        item {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (f in listOf(Status.PENDING, Status.APPROVED, Status.REJECTED, "all")) {
                    FilterChip(selected = filter == f, onClick = { filter = f }, label = { Text(f) })
                }
            }
        }
        if (shown.isEmpty()) item { Text("nothing $filter", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(vertical = 24.dp)) }
        items(shown, key = { it.id }) { l ->
            Column(Modifier.padding(vertical = 10.dp)) {
                Text("${l.playerName} · ${l.choreName}" + if (l.parentPick) " ★ your pick, 2x" else "", style = MaterialTheme.typography.bodyLarge)
                Text("${l.points} xp · ${l.minutes?.let { "${it}m · " } ?: ""}${fmt.format(Instant.ofEpochMilli(l.timestamp))} · ${l.status}",
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (l.status == Status.PENDING) Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 6.dp)) {
                    OutlinedButton(onClick = { if (vm.approve(l)) fb.levelUp() else fb.approve() }) { Text("✓ approve", color = Good) }
                    OutlinedButton(onClick = { vm.setStatus(l, Status.REJECTED); fb.reject() }) { Text("✗ reject", color = Bad) }
                }
            }
            HorizontalDivider()
        }
        item { SectionLabel("today's picks · hidden from kids") }
        item { Text("pick chores for each kid. they can't see these; a match earns 2x xp when they submit.",
            style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(players, key = { "pick" + it.id }) { p ->
            val mine = picks["${p.id}|${vm.today()}"]?.choreIds.orEmpty()
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(p.name)
                    Text(if (mine.isEmpty()) "no picks yet" else mine.joinToString { vm.store.poolById[it]?.name ?: it },
                        style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                TextButton(onClick = { pickingFor = p }) { Text(if (mine.isEmpty()) "pick" else "change") }
            }
        }
        item { SectionLabel("players") }
        items(players, key = { "p" + it.id }) { p ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(p.name, modifier = Modifier.weight(1f))
                TextButton(onClick = { editing = p }) { Text("edit") }
            }
        }
        item { OutlinedButton(onClick = { adding = true }, modifier = Modifier.padding(vertical = 12.dp)) { Text("+ add player") } }
    }

    pickingFor?.let { p ->
        PicksDialog(p.name, vm.pickable(p.id, logs), picks["${p.id}|${vm.today()}"]?.choreIds.orEmpty(), onDismiss = { pickingFor = null }) {
            vm.setParentPicks(p, it); pickingFor = null
        }
    }
    editing?.let { p ->
        NameDialog("Edit player", p.name, onDismiss = { editing = null },
            onRemove = if (players.size > 1) ({ vm.removePlayer(p); editing = null }) else null) { vm.renamePlayer(p, it); editing = null }
    }
    if (adding) NameDialog("Add player", "", onDismiss = { adding = false }, onRemove = null) { vm.addPlayer(it); adding = false }
}

@Composable
private fun NameDialog(title: String, initial: String, onDismiss: () -> Unit, onRemove: (() -> Unit)?, onSave: (String) -> Unit) {
    var name by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss, title = { Text(title) },
        text = {
            Column {
                OutlinedTextField(name, { name = it }, singleLine = true, label = { Text("name") })
                if (onRemove != null) TextButton(onClick = onRemove) { Text("remove player (keeps their history)", color = Bad) }
            }
        },
        confirmButton = { TextButton(onClick = { onSave(name) }, enabled = name.isNotBlank()) { Text("save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("cancel") } },
    )
}

/** The parent's picker for one kid: the same list the kid sees, most overdue first. */
@Composable
private fun PicksDialog(name: String, pool: List<EnrichedChore>, initial: List<String>, onDismiss: () -> Unit, onSave: (List<String>) -> Unit) {
    var picked by remember { mutableStateOf(initial) }
    val fb = LocalFeedback.current
    AlertDialog(
        onDismissRequest = onDismiss, title = { Text("Picks for $name · ${pool.filter { it.id in picked }.sumOf { it.currentMinutes }}m") },
        text = {
            LazyColumn(Modifier.heightIn(max = 440.dp)) {
                items(pool, key = { it.id }) { c ->
                    ChoreRow(c.name, c.currentMinutes, c.escalLevel, checked = c.id in picked,
                        onToggle = { fb.tick(c.id !in picked); picked = if (c.id in picked) picked - c.id else picked + c.id })
                }
            }
        },
        confirmButton = { TextButton(onClick = { onSave(picked) }) { Text("save") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("cancel") } },
    )
}
