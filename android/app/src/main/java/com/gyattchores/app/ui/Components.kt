package com.gyattchores.app.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.Rank

/** "> LABEL" terminal-style button. */
@Composable
fun TermButton(label: String, enabled: Boolean = true, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick, enabled = enabled, shape = MaterialTheme.shapes.small,
        colors = ButtonDefaults.buttonColors(containerColor = Accent),
        modifier = modifier.fillMaxWidth().heightIn(min = 52.dp),
    ) { Text("> $label", fontWeight = FontWeight.Bold, letterSpacing = 1.sp) }
}

@Composable
fun SectionLabel(text: String, color: Color = MaterialTheme.colorScheme.onSurfaceVariant) {
    Text(text.uppercase(), color = color, style = MaterialTheme.typography.labelSmall, letterSpacing = 3.sp,
        modifier = Modifier.padding(top = 20.dp, bottom = 8.dp))
}

/**
 * One chore row. Before submit it's a checkbox ([+]/[ ]); after submit it shows the parent's verdict.
 * In the picker it shows minutes and the escalation badge instead.
 */
@Composable
fun ChoreRow(
    name: String,
    minutes: Int,
    escalLevel: Int,
    checked: Boolean,
    status: String? = null,
    onToggle: (() -> Unit)? = null,
) {
    val badge = listOf("", "!", "!!").getOrElse(escalLevel) { "" }
    val badgeColor = listOf(Color.Gray, Warn, Bad).getOrElse(escalLevel) { Color.Gray }
    val verdict = when (status) {
        "approved" -> "✓ approved" to Good
        "rejected" -> "✗ rejected" to Bad
        "pending" -> "· awaiting" to Warn
        else -> null
    }
    val rowMod = if (onToggle != null && status == null) {
        Modifier.toggleable(value = checked, role = Role.Checkbox, onValueChange = { onToggle() })
    } else {
        Modifier.semantics { contentDescription = "$name, ${verdict?.first ?: ""}" }
    }
    Column {
        Row(
            rowMod.fillMaxWidth().heightIn(min = 52.dp).padding(vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(if (checked) "[+]" else "[ ]", color = if (checked) Accent else Color.Gray)
            Text(name, modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
            if (badge.isNotEmpty()) Text(badge, color = badgeColor, fontWeight = FontWeight.Bold)
            if (verdict != null) Text(verdict.first, color = verdict.second, style = MaterialTheme.typography.labelMedium)
            else Text("${minutes}m", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        HorizontalDivider()
    }
}

/** Version, XP bar and streak for one player. */
@Composable
fun StatsHeader(rank: Rank, streak: Int) {
    val progress by animateFloatAsState(rank.pct / 100f, tween(700), label = "xp")
    Column(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(rank.version, style = MaterialTheme.typography.headlineMedium, color = Accent, fontWeight = FontWeight.Bold)
            Text("  → ${rank.nextVersion}", color = MaterialTheme.colorScheme.onSurfaceVariant)
            Box(Modifier.weight(1f))
            Text("🔥 $streak · ${"%.1f".format(Engine.momentumMult(streak))}x", style = MaterialTheme.typography.labelLarge)
        }
        LinearProgressIndicator(
            progress = { progress }, color = Accent,
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp).height(6.dp),
        )
        Text("${rank.into} / ${rank.need} xp", style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
    }
}

@Composable
fun MinutesBar(total: Int, cap: Int) {
    Box(Modifier.fillMaxWidth().height(6.dp).background(MaterialTheme.colorScheme.surfaceVariant)) {
        Box(Modifier.fillMaxWidth((total.toFloat() / cap).coerceIn(0f, 1f)).height(6.dp).background(Accent))
    }
}
