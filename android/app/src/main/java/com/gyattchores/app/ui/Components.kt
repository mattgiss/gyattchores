package com.gyattchores.app.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.size
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.layout
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.text.style.TextDecoration
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
 * "DOYOURWORK" broken across two lines in a narrow pane reads as a bug. Below [minScale] it
 * stops shrinking and trims with an ellipsis. Given a [shorter] text, that's used instead whenever
 * [text] doesn't fit at full size, and shrinks the same way.
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
    shorter: String? = null,
) {
    BoxWithConstraints(modifier) {
        // Start again from full size when the text or the room changes (say, on unfolding).
        var scale by remember(text, shorter, maxWidth) { mutableFloatStateOf(1f) }
        var settled by remember(text, shorter, maxWidth) { mutableStateOf(false) }
        var short by remember(text, shorter, maxWidth) { mutableStateOf(false) }
        Text(
            if (short && shorter != null) shorter else text, color = color, fontWeight = fontWeight, maxLines = 1, softWrap = false, overflow = TextOverflow.Ellipsis,
            style = style.copy(fontSize = style.fontSize * scale, letterSpacing = letterSpacing * scale),
            // Hidden until it fits, so the sizes tried on the way are never seen.
            modifier = Modifier.drawWithContent { if (settled) drawContent() },
            onTextLayout = { result ->
                if (result.hasVisualOverflow && !short && shorter != null) short = true
                else if (result.hasVisualOverflow && scale > minScale) scale = (scale - 0.05f).coerceAtLeast(minScale) else settled = true
            },
        )
    }
}

/**
 * The one main action on a screen: a full-width band of the screen's first colour, like the top row
 * of a Clear list; dark grey when it can't be pressed yet. The label stays on one line, shrinking a
 * little if it must; a [shortLabel] takes its place when the full one doesn't fit.
 */
@Composable
fun TermButton(label: String, enabled: Boolean = true, modifier: Modifier = Modifier, shortLabel: String? = null, onClick: () -> Unit) {
    val palette = LocalPalette.current
    Button(
        onClick = onClick, enabled = enabled, shape = RectangleShape,
        colors = ButtonDefaults.buttonColors(containerColor = palette.stops[0], contentColor = palette.ink,
            disabledContainerColor = SurfaceDark, disabledContentColor = Done),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
        modifier = modifier.fillMaxWidth().heightIn(min = 54.dp),
    ) { FitText(label, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
        color = LocalContentColor.current, shorter = shortLabel) }
}

/** A secondary action: a quiet dark band, so it never competes with the main one. */
@Composable
fun QuietButton(label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Button(
        onClick = onClick, shape = RectangleShape,
        colors = ButtonDefaults.buttonColors(containerColor = SurfaceDark, contentColor = Ink),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
        modifier = modifier.fillMaxWidth().heightIn(min = 46.dp),
    ) { FitText(label, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = LocalContentColor.current) }
}

/**
 * One full-width row of colour: Clear's whole idea. Content is white (or lavender) and bold enough to
 * read on any step of the gradient; a finished ([done]) row drops to black.
 */
@Composable
fun Band(index: Int, count: Int, modifier: Modifier = Modifier, done: Boolean = false, minHeight: androidx.compose.ui.unit.Dp = 56.dp,
         content: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) {
    val palette = LocalPalette.current
    CompositionLocalProvider(LocalContentColor provides if (done) Done else palette.ink) {
        Row(
            modifier.fillMaxWidth().background(if (done) Bg else palette.band(index, count))
                .heightIn(min = minHeight).padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp), content = content,
        )
    }
}

@Composable
fun SectionLabel(text: String, color: Color = Done, padded: Boolean = true) {
    // Said plainly, as a heading in a sentence would be, not spaced-out capitals.
    Text(text.replaceFirstChar { it.uppercase() }, color = color, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(horizontal = if (padded) 16.dp else 0.dp).padding(top = 18.dp, bottom = 8.dp))
}

/** Not a parent's verdict: another player got this chore in first today. */
const val TAKEN = "taken"

/**
 * One chore row, as a band of colour. Picking ([picking]): rows light up when picked. On a card: a
 * row ticked off drops to black and is struck through, as in Clear; after submit it shows the admin's
 * verdict.
 */
@Composable
fun ChoreRow(
    name: String,
    minutes: Int,
    escalLevel: Int,
    checked: Boolean,
    status: String? = null,
    index: Int = 0,
    count: Int = 1,
    picking: Boolean = false,
    onToggle: (() -> Unit)? = null,
) {
    val badge = listOf("", "!", "!!").getOrElse(escalLevel) { "" }
    val verdict = when (status) {
        "approved" -> "approved" to Good
        "rejected" -> "turned down" to Bad
        "pending" -> "waiting" to LocalPalette.current.ink.copy(alpha = 0.85f)
        TAKEN -> "taken" to Done
        else -> null
    }
    val lit = if (picking) checked else if (status == null) !checked else status == "pending"
    val struck = !picking && (if (status == null) checked else status == "approved" || status == TAKEN)
    val rowMod = if (onToggle != null && status == null) {
        Modifier.toggleable(value = checked, role = Role.Checkbox, onValueChange = { onToggle() })
    } else {
        Modifier.semantics { contentDescription = "$name, ${verdict?.first ?: ""}" }
    }
    Band(index, count, rowMod, done = !lit, minHeight = 50.dp) {
        Text(name, modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
            color = if (lit) LocalPalette.current.ink else if (picking || status == "rejected") Ink else Done,
            textDecoration = if (struck) TextDecoration.LineThrough else null)
        if (badge.isNotEmpty()) Text(badge, fontWeight = FontWeight.Black, color = if (lit) LocalPalette.current.ink else if (escalLevel == 1) Warn else Bad)
        if (verdict != null) Text(verdict.first, color = verdict.second, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        else Text("${minutes}m", color = if (lit) LocalPalette.current.ink.copy(alpha = 0.85f) else Done)
    }
}

/** Version, XP bar and streak for one player. Sits on the screen's top band, so it's all white. */
@Composable
fun StatsHeader(rank: Rank, streak: Int) {
    val progress by animateFloatAsState(rank.pct / 100f, tween(700), label = "xp")
    val ink = Palette.HEAT.ink
    Column(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(rank.version, fontSize = 32.sp, fontWeight = FontWeight.Black, color = ink)
            Box(Modifier.weight(1f))
            Text(if (streak == 0) "No streak yet" else "$streak-day streak · ${"%.1f".format(Engine.momentumMult(streak))}x points",
                style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, color = ink, modifier = Modifier.padding(bottom = 6.dp))
        }
        Box(Modifier.fillMaxWidth().padding(top = 6.dp).height(6.dp).clip(CircleShape).background(ink.copy(alpha = 0.25f))) {
            Box(Modifier.fillMaxWidth(progress).height(6.dp).clip(CircleShape).background(ink))
        }
        Text("${rank.into} of ${rank.need} xp to ${rank.nextVersion}", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold,
            color = ink.copy(alpha = 0.75f), modifier = Modifier.padding(top = 4.dp))
    }
}

@Composable
fun MinutesBar(total: Int, cap: Int) {
    // How full the card is, as a strip of the heat gradient across the screen.
    Box(Modifier.fillMaxWidth().height(4.dp).background(SurfaceDark)) {
        Box(Modifier.fillMaxWidth((total.toFloat() / cap).coerceIn(0f, 1f)).height(4.dp)
            .background(androidx.compose.ui.graphics.Brush.horizontalGradient(Palette.HEAT.stops)))
    }
}

/** Lets a band in a padded column run edge to edge: widens the child by [by] on each side. */
fun Modifier.bleed(by: androidx.compose.ui.unit.Dp) = layout { measurable, constraints ->
    val extra = (by * 2).roundToPx()
    val placeable = measurable.measure(constraints.copy(minWidth = constraints.minWidth + extra, maxWidth = constraints.maxWidth + extra))
    layout(placeable.width - extra, placeable.height) { placeable.place(-extra / 2, 0) }
}

/**
 * Pick a look, monkeytype-style: every theme's button is painted in that theme, so you see it before
 * you choose. Picking applies straight away; the sheet stays open to try another.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun ThemePicker(onDone: () -> Unit) {
    val ctx = androidx.compose.ui.platform.LocalContext.current
    val current = Themes.current
    androidx.compose.material3.ModalBottomSheet(onDismissRequest = onDone, containerColor = current.bg, contentColor = current.text) {
        Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 24.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Pick a look", fontSize = 26.sp, fontWeight = FontWeight.Black, color = current.text, modifier = Modifier.weight(1f))
                androidx.compose.material3.TextButton(onClick = onDone) { Text("Done", color = current.text, fontWeight = FontWeight.Bold) }
            }
            Text("Just for this phone. Everyone can pick their own.", color = current.muted, style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(bottom = 12.dp))
            for (row in AppTheme.ALL.chunked(2)) {
                Row(Modifier.padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (t in row) {
                        val on = t.id == current.id
                        Row(
                            Modifier.weight(1f).heightIn(min = 52.dp).clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp)).background(t.bg)
                                .border(if (on) 2.dp else 1.dp, if (on) current.text else Color.White.copy(alpha = 0.08f), androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
                                .clickable(onClickLabel = "use ${t.name}") { Themes.pick(ctx, t) }.padding(horizontal = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(t.name, fontWeight = FontWeight.Bold, color = if (t.isClear) Color.White else t.main, modifier = Modifier.weight(1f))
                            for (c in t.heat.stops.take(3)) Box(Modifier.padding(start = 3.dp).size(9.dp).clip(CircleShape).background(c))
                        }
                    }
                    if (row.size == 1) Box(Modifier.weight(1f))
                }
            }
        }
    }
}
