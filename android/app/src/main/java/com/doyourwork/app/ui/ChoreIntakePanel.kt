package com.doyourwork.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.doyourwork.app.engine.ChoreIntake
import com.doyourwork.app.model.Chore

/**
 * Write or say what needs doing around the house; get back a list to tick, rename and re-time
 * before any of it is added. Sorting happens on the phone ([ChoreIntake]). Speaking uses the
 * keyboard's own mic key, so this app never listens and needs no microphone permission.
 */
@Composable
fun ChoreIntakePanel(existing: List<Chore>, onDone: (List<Chore>) -> Unit) {
    data class Found(val name: String, val minutes: Int, val on: Boolean = true)

    val fb = LocalFeedback.current
    var text by remember { mutableStateOf("") }
    var reviewing by remember { mutableStateOf(false) }
    val found = remember { mutableStateListOf<Found>() }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (!reviewing) {
            Text("List the chores in your home, in your own words. Type them, or tap the mic on the keyboard and say them.",
                color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(text, { text = it }, modifier = Modifier.fillMaxWidth().heightIn(min = 140.dp),
                placeholder = { Text("Dishes, take out the trash, feed the dog 5 minutes…") })
            TermButton("Sort into chores", enabled = text.isNotBlank()) {
                fb.tap()
                found.clear()
                found += ChoreIntake.parse(text, existing).map { Found(it.name, it.tiers[0]) }
                reviewing = true
            }
            Text("Sorted on this phone. Nothing you write or say here is sent anywhere by this app.",
                style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            val chosen = found.filter { it.on && ChoreIntake.tidyName(it.name) != null }
            if (found.isEmpty()) {
                Text("Couldn't find any new chores in that. Try one per line, or separate them with commas.", color = Warn)
            } else {
                Text("Found ${found.size}. Untick any you don't want, and fix names and minutes as you like.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                found.forEachIndexed { i, f ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TextButton(onClick = { fb.tick(!f.on); found[i] = f.copy(on = !f.on) }) {
                            Text(if (f.on) "[+]" else "[ ]", color = if (f.on) Accent else MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        OutlinedTextField(f.name, { found[i] = f.copy(name = it) }, singleLine = true, enabled = f.on,
                            modifier = Modifier.weight(1f))
                        MinuteStepper(f.minutes, enabled = f.on) { found[i] = f.copy(minutes = it) }
                    }
                    HorizontalDivider()
                }
            }
            val n = chosen.size
            TermButton(if (n == 0) "Nothing to add" else "Add $n chore${if (n == 1) "" else "s"}", enabled = n > 0) {
                val ids = existing.map { it.id }.toMutableSet()
                onDone(chosen.map { item -> ChoreIntake.make(item.name, item.minutes, ids).also { ids += it.id } })
            }
            OutlinedButton(onClick = { fb.tap(); reviewing = false }, modifier = Modifier.fillMaxWidth()) { Text("Write some more") }
        }
    }
}

/** "– 5m +" within [ChoreIntake.minuteRange]. */
@Composable
fun MinuteStepper(minutes: Int, enabled: Boolean = true, onChange: (Int) -> Unit) {
    val r = ChoreIntake.minuteRange
    Row(verticalAlignment = Alignment.CenterVertically) {
        TextButton(onClick = { onChange(minutes - 1) }, enabled = enabled && minutes > r.first, modifier = Modifier.widthIn(min = 40.dp)) { Text("–") }
        Text("${minutes}m")
        TextButton(onClick = { onChange(minutes + 1) }, enabled = enabled && minutes < r.last, modifier = Modifier.widthIn(min = 40.dp)) { Text("+") }
    }
}
