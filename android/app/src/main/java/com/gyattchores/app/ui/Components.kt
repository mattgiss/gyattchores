package com.gyattchores.app.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.Rank

/**
 * One line of text that shrinks to fit the room it has, instead of wrapping or being cut off:
 * "GYATTCHORES" broken across two lines in a narrow pane reads as a bug. Below [minScale] it
 * stops shrinking and trims with an ellipsis.
 */
@Composable
fun FitText(
    text: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    color: Color = Color.Unspecified,
    fontWeight: FontWeight? = null,
    letterSpacing: TextUnit = 0.sp,
    minScale: Float = 0.6f,
) {
    BoxWithConstraints(modifier) {
        // Start again from full size when the text or the room changes (say, on unfolding).
        var scale by remember(text, maxWidth) { mutableFloatStateOf(1f) }
        var settled by remember(text, maxWidth) { mutableStateOf(false) }
        Text(
            text, color = color, fontWeight = fontWeight, maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis,
            style = style.copy(fontSize = style.fontSize * scale, letterSpacing = letterSpacing * scale),
            // Hidden until it fits, so the sizes tried on the way are never seen.
            modifier = Modifier.drawWithContent { if (settled) drawContent() },
            onTextLayout = { result ->
                if (result.hasVisualOverflow && scale > minScale) scale = (scale - 0.05f).coerceAtLeast(minScale) else settled = true
            },
        )
    }
}

/** "> LABEL" terminal-style button. The label stays on one line, shrinking a little if it must. */
@Composable
fun TermButton(label: String, enabled: Boolean = true, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick, enabled = enabled, shape = MaterialTheme.shapes.small,
        colors = ButtonDefaults.buttonColors(containerColor = Accent),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        modifier = modifier.fillMaxWidth().heightIn(min = 52.dp),
    ) { FitText("> $label", style = LocalTextStyle.current, fontWeight = FontWeight.Bold, letterSpacing = 1.sp, color = LocalContentColor.current) }
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
