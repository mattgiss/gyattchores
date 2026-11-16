package com.gyattchores.app.ui

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.engine.AdminCode
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.Chore

/**
 * First run: who's in charge, who's playing, what needs doing. The same steps as iOS. In the
 * public edition the family then exists on this phone and nowhere else; in the family edition it
 * goes to the family's shared tables and the other phones pick it up.
 */
@Composable
fun SetupScreen(vm: AppViewModel) {
    val fb = LocalFeedback.current
    val ctx = LocalContext.current
    var step by rememberSaveable { mutableStateOf(0) }
    var adminName by rememberSaveable { mutableStateOf("") }
    var code by rememberSaveable { mutableStateOf("") }
    var codeAgain by rememberSaveable { mutableStateOf("") }
    var adminPlays by rememberSaveable { mutableStateOf(false) }
    var bio by rememberSaveable { mutableStateOf(false) }
    val playerNames = remember { mutableStateListOf<String>() }
    var newName by rememberSaveable { mutableStateOf("") }
    var writingChores by rememberSaveable { mutableStateOf(false) }
    val canBio = remember { BiometricManager.from(ctx).canAuthenticate(BIOMETRIC_WEAK) == BiometricManager.BIOMETRIC_SUCCESS }
    /** People already here: a family carried over from an earlier version, or set up on another phone. */
    val family by vm.store.family.collectAsState()
    val alreadyHere = family.members.map { it.name }

    fun addName() {
        val name = newName.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
        newName = ""
        val taken = (alreadyHere + playerNames + adminName.trim()).map { it.lowercase() }
        if (name.isNotEmpty() && name.lowercase() !in taken) playerNames += name
    }
    fun finish(chores: List<Chore>) {
        fb.lockIn()
        vm.finishSetup(adminName, adminPlays, code, bio, playerNames.toList(), chores)
    }
    val (_, restoreBackup) = rememberBackup(vm)
    fun back() { if (step == 3 && writingChores) writingChores = false else step = maxOf(0, step - 1) }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
        Column(Modifier.widthIn(max = 560.dp).fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                FitText("GYATTCHORES", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold,
                    letterSpacing = 4.sp, color = Accent, modifier = Modifier.weight(1f))
                if (step > 0) Text("step $step of 3", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            when (step) {
                0 -> {
                    Text("a chore scoreboard for your family.", style = MaterialTheme.typography.titleMedium)
                    Muted("· everyone picks ${Engine.DAILY_MINUTES} minutes of chores a day\n· an admin approves what got done\n· points, streaks and a weekly winner follow")
                    if (vm.familySync) {
                        SectionLabel("shared with your family", padded = false)
                        Muted("· this edition keeps the family's chores and points in step across your family's phones")
                    } else {
                        SectionLabel("private by design", padded = false)
                        Muted("· everything stays on this phone\n· no accounts, no sign-in, no ads, no tracking\n· uninstall the app and it's all gone")
                    }
                    if (alreadyHere.isNotEmpty()) Text("your players and their points are still here. they just need someone in charge.",
                        style = MaterialTheme.typography.labelMedium, color = Warn)
                    TermButton("SET UP THIS ${if (vm.familySync) "FAMILY" else "PHONE"}") { fb.tap(); step = 1 }
                    OutlinedButton(onClick = { fb.tap(); restoreBackup() }, modifier = Modifier.fillMaxWidth()) { Text("restore from a backup") }
                }
                1 -> {
                    val problem = when {
                        code.isEmpty() -> null
                        !AdminCode.isLongEnough(code) -> "the code needs ${AdminCode.MIN_LENGTH} or more characters"
                        codeAgain.isNotEmpty() && code != codeAgain -> "those two codes don't match"
                        else -> null
                    }
                    val ready = adminName.isNotBlank() && AdminCode.isLongEnough(code) && code == codeAgain
                    Text("who's in charge?", style = MaterialTheme.typography.titleMedium)
                    Muted("an admin approves chores and can change the players and the chore list. you can make more people admins later.")
                    OutlinedTextField(adminName, { adminName = it }, singleLine = true, label = { Text("your name") }, modifier = Modifier.fillMaxWidth())
                    CodeField(code, "admin code (${AdminCode.MIN_LENGTH} or more)") { code = it }
                    CodeField(codeAgain, "the same code again") { codeAgain = it }
                    if (problem != null) Text(problem, color = Bad, style = MaterialTheme.typography.labelMedium)
                    Muted(if (vm.familySync) "keep the code from the players. it opens the admin area on every phone in the family."
                        else "keep the code from the players. it isn't stored anywhere but this phone, so nobody can look it up for you: if it's forgotten, the way back in is to erase the app's data and start a new scoreboard.")
                    SwitchRow("i do chores too", adminPlays) { adminPlays = it }
                    if (canBio) {
                        SwitchRow("fingerprint / face also opens the admin area", bio) { bio = it }
                        Muted("only turn this on if this is your own phone, not a player's.")
                    }
                    TermButton("NEXT", enabled = ready) { fb.tap(); step = 2 }
                }
                2 -> {
                    val admin = adminName.trim()
                    val adminListed = (alreadyHere + playerNames).any { it.equals(admin, ignoreCase = true) }
                    Text("who's playing?", style = MaterialTheme.typography.titleMedium)
                    Muted("everyone who does chores. first names or nicknames are plenty, and you can add or change them later.")
                    if (adminPlays && !adminListed) NameRow(admin, "you")
                    for (n in alreadyHere) NameRow(n, "already here")
                    for (n in playerNames.toList()) NameRow(n, null) { fb.tap(); playerNames.remove(n) }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(newName, { newName = it }, singleLine = true, label = { Text("a player's name") }, modifier = Modifier.weight(1f))
                        TextButton(onClick = { fb.tick(true); addName() }, enabled = newName.isNotBlank()) { Text("+ add") }
                    }
                    val anyone = adminPlays || alreadyHere.isNotEmpty() || playerNames.isNotEmpty() || newName.isNotBlank()
                    // A name still sitting in the box counts: it's easy to type it and forget to press add.
                    TermButton("NEXT", enabled = anyone) { fb.tap(); addName(); step = 3 }
                }
                else -> {
                    Text("what needs doing?", style = MaterialTheme.typography.titleMedium)
                    if (writingChores) ChoreIntakePanel(emptyList()) { finish(it) }
                    else {
                        Muted("start from a list of ${vm.store.starterChores.size} everyday chores, or write your own. either way an admin can add, change and remove chores at any time.")
                        TermButton("USE THE STARTER LIST") { finish(vm.store.starterChores) }
                        OutlinedButton(onClick = { fb.tap(); writingChores = true }, modifier = Modifier.fillMaxWidth()) { Text("write or say your own") }
                    }
                }
            }
            if (step > 0) TextButton(onClick = { fb.tap(); back() }) { Text("Back", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}

/** Family edition, before its first sync: it can't yet tell a new family from one it hasn't fetched. */
@Composable
fun WaitingForFamily(vm: AppViewModel, status: String) {
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally) {
        Text("GYATTCHORES", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, letterSpacing = 4.sp, color = Accent)
        Text(if (status == "offline") "can't reach the family's scoreboard. check the connection and try again."
            else "fetching your family's scoreboard…", color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (status == "offline") TermButton("TRY AGAIN", modifier = Modifier.widthIn(max = 320.dp)) { vm.requestSync() }
    }
}

@Composable
private fun Muted(text: String) = Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)

@Composable
fun CodeField(value: String, label: String, onChange: (String) -> Unit) {
    OutlinedTextField(value, onChange, singleLine = true, label = { Text(label) }, visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), modifier = Modifier.fillMaxWidth())
}

@Composable
fun SwitchRow(label: String, on: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(on, onChange)
    }
}

@Composable
private fun NameRow(name: String, note: String?, onRemove: (() -> Unit)? = null) {
    Column {
        Row(Modifier.heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("> ", color = Accent)
            Text(name, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            if (note != null) Text(" · $note", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Box(Modifier.weight(1f))
            if (onRemove != null) TextButton(onClick = onRemove) { Text("remove") }
        }
        HorizontalDivider()
    }
}
