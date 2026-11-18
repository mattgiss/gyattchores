package com.gyattchores.app.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.engine.Backup
import com.gyattchores.app.engine.BackupException
import com.gyattchores.app.engine.BackupFile

/**
 * Saving and restoring a backup through the system's file picker, so it can go to Downloads,
 * Drive or anywhere else the phone offers. Returns (save, restore) actions; the dialogs that
 * confirm a restore and say how it went are drawn here.
 */
@Composable
fun rememberBackup(vm: AppViewModel, onRestored: () -> Unit = {}): Pair<() -> Unit, () -> Unit> {
    val ctx = LocalContext.current
    val fb = LocalFeedback.current
    var message by remember { mutableStateOf<String?>(null) }
    var pending by remember { mutableStateOf<BackupFile?>(null) }

    val saver = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument(BackupFile.MIME)) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        message = runCatching {
            ctx.contentResolver.openOutputStream(uri, "wt")!!.use { it.write(vm.exportBackup().toByteArray()) }
            "Backup saved. Keep it somewhere safe: it holds everyone's chores and the admin codes (scrambled)."
        }.getOrElse { "Couldn't save the backup there. Try another place." }
    }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        try {
            val text = ctx.contentResolver.openInputStream(uri)!!.use { it.readBytes().decodeToString() }
            val b = Backup.decode(text)
            val problem = if (vm.relayLinked.value) null else Backup.replaceProblem(b)
            when {
                problem != null -> { message = problem; fb.error() }
                vm.alreadyRestored(b) -> message = "This backup has already been restored into the family."
                else -> pending = b
            }
        } catch (e: BackupException) {
            message = e.message; fb.error()
        } catch (e: Exception) {
            message = "Couldn't read that file."; fb.error()
        }
    }

    pending?.let { b ->
        val what = "${b.players} player${if (b.players == 1) "" else "s"}, ${b.chores.size} chores and ${b.logs.size} chores logged"
        // Linked: merged into the family. Unlinked: it replaces what's on this phone.
        val joining = vm.relayLinked.value
        val setUp = vm.store.family.value.isSetUp
        AlertDialog(
            onDismissRequest = { pending = null },
            title = { Text(if (joining) "Add this backup to the family?" else "Restore this backup?") },
            text = {
                Text(when {
                    !joining && !setUp -> "It holds $what. It becomes this phone's scoreboard."
                    !joining -> "It holds $what. Everything on this phone is replaced by it. This can't be undone."
                    setUp -> "It holds $what. Players are matched by username and their history is added; chores already logged that day aren't added twice. The family's admins and codes stay as they are."
                    else -> "It holds $what. Players are matched by username and their history is added. The backup's admins and their codes come in too, so the family has someone in charge."
                })
            },
            confirmButton = {
                TextButton(onClick = {
                    val c = vm.restore(b)
                    pending = null
                    fb.lockIn()
                    // Said by AppRoot: a restore during setup leaves this screen at once.
                    vm.notice.value = "Restored: ${c.describe()}."
                    onRestored()
                }) { Text(if (joining) "Add to the family" else "Replace and restore") }
            },
            dismissButton = { TextButton(onClick = { pending = null }) { Text("Cancel") } },
        )
    }
    message?.let { m ->
        AlertDialog(onDismissRequest = { message = null }, text = { Text(m) },
            confirmButton = { TextButton(onClick = { message = null }) { Text("OK") } })
    }

    return Pair(
        { saver.launch(vm.backupFileName()) },
        // Some file pickers label a .gyattchores file as a generic binary, so accept those too.
        { picker.launch(arrayOf(BackupFile.MIME, "application/octet-stream", "text/plain", "*/*")) },
    )
}
