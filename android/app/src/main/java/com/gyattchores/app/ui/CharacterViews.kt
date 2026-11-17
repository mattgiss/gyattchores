package com.gyattchores.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.gyattchores.app.engine.Characters
import com.gyattchores.app.engine.PlayerCharacter

private fun outline(path: String): Path = Path().apply {
    for (s in Characters.steps(path)) when (s) {
        is Characters.Step.Move -> moveTo(s.x, s.y)
        is Characters.Step.Line -> lineTo(s.x, s.y)
        is Characters.Step.Quad -> quadraticTo(s.cx, s.cy, s.x, s.y)
        is Characters.Step.Cubic -> cubicTo(s.c1x, s.c1y, s.c2x, s.c2y, s.x, s.y)
        Characters.Step.Close -> close()
    }
}

/**
 * A player's character, drawn in two colours: the theme's background for the body and its text
 * colour for the eyes and other details, so it stands out on any band of any theme.
 */
@Composable
fun CharacterIcon(character: PlayerCharacter, size: Dp, modifier: Modifier = Modifier, body: Color = Bg, detail: Color = Ink) {
    val layers = remember(character.id) { character.layers.map { it.detail to outline(it.path) } }
    Canvas(modifier.size(size)) {
        scale(this.size.width / Characters.SIZE, pivot = Offset.Zero) {
            for ((isDetail, path) in layers) drawPath(path, if (isDetail) detail else body)
        }
    }
}

/** The little flame beside a streak count: the Flame character's outline, in the text's colour. */
@Composable
fun StreakFlame(size: Dp, color: Color, modifier: Modifier = Modifier) {
    val path = remember { outline(Characters.all.first { it.id == "flame" }.layers.first().path) }
    Canvas(modifier.size(size)) { scale(this.size.width / Characters.SIZE, pivot = Offset.Zero) { drawPath(path, color) } }
}

/**
 * Pick a character. Each is shown on a band of the theme, as it will be on the scoreboard. One
 * another player already has is dimmed and says whose it is: everyone gets their own.
 */
@Composable
fun CharacterPicker(current: PlayerCharacter?, takenBy: Map<String, String>, onPick: (PlayerCharacter) -> Unit, onDismiss: () -> Unit) {
    val fb = LocalFeedback.current
    val all = Characters.all
    AlertDialog(
        onDismissRequest = onDismiss, title = { Text("Pick your character") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                for (row in all.chunked(4)) Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    for (c in row) {
                        val owner = takenBy[c.id]
                        val mine = c.id == current?.id
                        Box(
                            Modifier.weight(1f).aspectRatio(1f).background(Palette.HEAT.band(all.indexOf(c) % 8, 8))
                                .then(if (mine) Modifier.border(3.dp, Palette.HEAT.ink) else Modifier)
                                .alpha(if (owner != null) 0.35f else 1f)
                                .clickable(enabled = owner == null, onClickLabel = "pick ${c.name}") { fb.tap(); onPick(c) }
                                .clearAndSetSemantics {
                                    contentDescription = c.name; role = Role.Button; selected = mine
                                    if (owner != null) stateDescription = "$owner has this one"
                                },
                            contentAlignment = Alignment.Center,
                        ) { CharacterIcon(c, 44.dp) }
                    }
                    repeat(4 - row.size) { Box(Modifier.weight(1f)) }
                }
                if (takenBy.isNotEmpty()) Text("The faded ones are already someone else's.", style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Done") } },
    )
}
