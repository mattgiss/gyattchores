package com.gyattchores.app.ui

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.sync.JoinCode
import com.gyattchores.app.sync.RelayDevice
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * Admin → this phone → phones: add a phone with a QR code, join a family by scanning one, and see
 * or remove the family's phones (docs/design/encrypted-relay-join.md).
 */
@Composable
fun PhonesSection(vm: AppViewModel) {
    val fb = LocalFeedback.current
    val scope = rememberCoroutineScope()
    val linked by vm.relayLinked.collectAsState()
    var phones by remember { mutableStateOf<List<Pair<RelayDevice, Boolean>>?>(null) }
    var reload by remember { mutableIntStateOf(0) }
    var adding by remember { mutableStateOf(false) }
    val join = rememberJoinFlow(vm)
    var removing by remember { mutableStateOf<RelayDevice?>(null) }
    var deleting by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val dates = remember { DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withZone(vm.zone) }

    LaunchedEffect(linked, reload, adding) { if (linked && !adding) phones = vm.phones().getOrNull() }

    Column(Modifier.padding(top = 8.dp)) {
        SectionLabel("phones", padded = false)
        Text(if (linked) "Shared with the family's phones, encrypted. Only this family's phones can read what's sent."
            else "The family is only on this phone. Add a phone shares it: everything is encrypted on this phone before it's sent, and only phones that scan the code can read it.",
            style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (linked) {
            val list = phones
            if (list == null) Text("Can't list the phones right now.", style = MaterialTheme.typography.labelMedium, color = Done, modifier = Modifier.padding(top = 8.dp))
            else for ((d, mine) in list) Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("${if (mine) "This phone" else "Phone"} · joined ${dates.format(Instant.ofEpochMilli(d.joinedAt))}", modifier = Modifier.weight(1f))
                if (!mine) TextButton(onClick = { fb.tap(); removing = d }) { Text("Remove", color = Bad) }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(vertical = 8.dp)) {
            OutlinedButton(onClick = { fb.tap(); adding = true }) { Text("Add a phone") }
            if (!linked) OutlinedButton(onClick = { fb.tap(); join() }) { Text("Join with a code") }
        }
        if (linked) TextButton(onClick = { fb.tap(); deleting = true }) { Text("Delete this family from the server…", color = Bad) }
    }

    if (deleting) AlertDialog(
        onDismissRequest = { deleting = false },
        title = { Text("Delete the family from the server?") },
        text = { Text("Every phone stops syncing, and everything sent is deleted from the server. The family stays on this phone. This can't be undone.") },
        confirmButton = { TextButton(onClick = {
            deleting = false
            scope.launch { vm.deleteFromServer()?.let { fb.error(); message = it } ?: fb.reject() }
        }) { Text("Delete from the server", color = Bad) } },
        dismissButton = { TextButton(onClick = { deleting = false }) { Text("Cancel") } },
    )

    if (adding) AddPhoneDialog(vm, onDone = { adding = false })
    removing?.let { d -> AlertDialog(
        onDismissRequest = { removing = null },
        title = { Text("Remove this phone?") },
        text = { Text("It stops getting updates. What it already has stays on it.") },
        confirmButton = { TextButton(onClick = {
            removing = null
            scope.launch { if (vm.removePhone(d.userId)) { fb.reject(); reload++ } else { fb.error(); message = "Can't reach the server. Check the connection and try again." } }
        }) { Text("Remove", color = Bad) } },
        dismissButton = { TextButton(onClick = { removing = null }) { Text("Cancel") } },
    ) }
    message?.let { m -> AlertDialog(onDismissRequest = { message = null }, text = { Text(m) },
        confirmButton = { TextButton(onClick = { message = null }) { Text("OK") } }) }
}

/**
 * "Join with a code": asks first, then opens the camera (or, in a debug build started with
 * `scanResult`, takes that instead) and joins the family the code belongs to. Returns what starts it.
 */
@Composable
fun rememberJoinFlow(vm: AppViewModel): () -> Unit {
    val fb = LocalFeedback.current
    val scope = rememberCoroutineScope()
    var confirming by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val onScanned: (String?) -> Unit = { text -> scope.launch { vm.joinWith(text)?.let { fb.error(); message = it } } }
    val scan = rememberQrScanner(onScanned)

    if (confirming) AlertDialog(
        onDismissRequest = { confirming = false },
        title = { Text("Join this family?") },
        text = { Text(if (vm.store.family.value.isSetUp || vm.store.logs.value.isNotEmpty())
            "This phone will load the family from the phone that showed the code. Everything on this phone now is replaced by it, so save a backup first if you want to keep it."
            else "This phone will load the family from the phone that showed the code.") },
        confirmButton = { TextButton(onClick = {
            confirming = false
            scope.launch { vm.testScan()?.let(onScanned) ?: scan() }
        }) { Text("Scan the code") } },
        dismissButton = { TextButton(onClick = { confirming = false }) { Text("Cancel") } },
    )
    message?.let { m -> AlertDialog(onDismissRequest = { message = null }, text = { Text(m) },
        confirmButton = { TextButton(onClick = { message = null }) { Text("OK") } }) }
    return { confirming = true }
}

/** Shows a one-time code for the other phone, counting down its 10 minutes. */
@Composable
private fun AddPhoneDialog(vm: AppViewModel, onDone: () -> Unit) {
    var attempt by remember { mutableIntStateOf(0) }
    var code by remember { mutableStateOf<Pair<JoinCode, Long>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(attempt) {
        code = null; error = null
        vm.addPhone().onSuccess { code = it }.onFailure { error = it.message ?: "Can't reach the server. Check the connection and try again." }
    }
    LaunchedEffect(code) { while (code != null) { now = System.currentTimeMillis(); delay(1000) } }
    val left = code?.let { ((it.second - now) / 1000).coerceAtLeast(0) }
    val expired = left == 0L

    AlertDialog(
        onDismissRequest = onDone,
        title = { Text("Add a phone") },
        text = {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                val c = code
                when {
                    error != null -> Text(error!!)
                    c == null -> CircularProgressIndicator(Modifier.padding(24.dp))
                    expired -> Text("This code expired.")
                    else -> {
                        val bitmap = remember(c.first.text) { qrBitmap(c.first.text).asImageBitmap() }
                        Image(bitmap, contentDescription = "QR code for the other phone to scan", filterQuality = FilterQuality.None,
                            modifier = Modifier.size(240.dp).background(Color.White).testTag("joinQR"))
                        Text("Scan this with the other phone's camera, inside DOYOURWORK.", modifier = Modifier.padding(top = 12.dp))
                        Text("Expires in ${left!! / 60}:${"%02d".format(left % 60)}", style = MaterialTheme.typography.labelMedium, color = Done,
                            modifier = Modifier.padding(top = 4.dp))
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDone) { Text("Done") } },
        dismissButton = { if (expired || error != null) TextButton(onClick = { attempt++ }) { Text(if (expired) "New code" else "Try again") } },
    )
}

/** Black on white with a quiet zone, the way every camera app expects a QR code. */
private fun qrBitmap(text: String, size: Int = 512): Bitmap {
    val m = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size,
        mapOf(EncodeHintType.MARGIN to 2, EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M))
    val px = IntArray(m.width * m.height) { if (m.get(it % m.width, it / m.width)) android.graphics.Color.BLACK else android.graphics.Color.WHITE }
    return Bitmap.createBitmap(px, m.width, m.height, Bitmap.Config.ARGB_8888)
}
