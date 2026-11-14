package com.gyattchores.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.window.layout.FoldingFeature
import com.gyattchores.app.AppViewModel

/** Two panes need at least this much room for the list and for what opens beside it. */
private val MinPane = 300.dp
/** Wide enough for the list; any wider and it only pushes the names away from the numbers. */
private val MaxListPane = 420.dp
/** Rows stretched across a tablet are hard to read; keep the open screen column-width. */
private val MaxDetailPane = 640.dp

/**
 * How wide the list pane is beside the open screen.
 *
 * With a hinge running top to bottom (a foldable opened like a book), the list takes the half
 * left of the hinge, so nothing straddles the fold. Otherwise — a tablet, or a foldable turned on
 * its side, where the hinge runs across — it gets a little under half the width, within limits.
 */
fun listPaneWidth(window: Dp, hingeLeft: Dp?): Dp =
    hingeLeft?.takeIf { it >= MinPane && window - it >= MinPane }
        ?: (window * 0.42f).coerceIn(MinPane, MaxListPane)

/**
 * The whole app: one screen at a time on a phone (or a folded foldable), list and open screen
 * side by side once there's room for both. Kept apart from the activity so it can be drawn
 * without the activity's sync loop.
 */
@Composable
fun AppRoot(vm: AppViewModel, fold: FoldingFeature?) {
    val logs by vm.store.logs.collectAsState()
    val players by vm.store.players.collectAsState()
    val cards by vm.store.cards.collectAsState()
    val syncStatus by vm.syncStatus.collectAsState()
    val shared by vm.store.state.collectAsState()
    val me by vm.store.me.collectAsState()
    // Saved state, so fold/unfold and process death land on the same screen.
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    var adminOpen by rememberSaveable { mutableStateOf(false) }
    var daresOpen by rememberSaveable { mutableStateOf(false) }
    // The puzzle takes the whole window, even beside the list on a foldable, so its flash fills the screen.
    var puzzleId by rememberSaveable { mutableStateOf<String?>(null) }
    val selected = players.firstOrNull { it.id == selectedId }
    val puzzlePlayer = players.firstOrNull { it.id == puzzleId }

    // Tabletop: half-open with a horizontal hinge. Content above it, controls below.
    val hinge = if (fold != null && fold.state == FoldingFeature.State.HALF_OPENED && fold.orientation == FoldingFeature.Orientation.HORIZONTAL)
        Hinge(fold.bounds.top, fold.bounds.bottom) else null
    // Book posture or a flat inner screen held upright: the hinge runs top to bottom.
    val hingeX = if (fold != null && fold.orientation == FoldingFeature.Orientation.VERTICAL) fold.bounds.left else null

    val myId = me
    val showDares = daresOpen && myId != null
    BackHandler(enabled = puzzlePlayer != null || adminOpen || showDares || selected != null) {
        if (puzzlePlayer != null) puzzleId = null
        else if (adminOpen) adminOpen = false else if (showDares) daresOpen = false else selectedId = null
    }

    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        BoxWithConstraints(Modifier.fillMaxSize().safeDrawingPadding()) {
            // Two panes whenever both fit. The Z Fold 7's inner screen is about 750dp by 830dp, so
            // it gets two panes whichever way up it's held; its cover screen and other phones don't.
            val windowWidth = maxWidth
            val twoPane = windowWidth >= MinPane * 2
            val home = @Composable {
                HomeScreen(vm, players, logs, shared, me, selectedId.takeIf { twoPane && !adminOpen && !showDares }, syncStatus,
                    onPick = { adminOpen = false; daresOpen = false; selectedId = it.id }, onAdmin = { daresOpen = false; adminOpen = true },
                    onDares = { adminOpen = false; daresOpen = true })
            }
            if (puzzlePlayer != null) {
                PuzzleScreen(vm, puzzlePlayer, onBack = { puzzleId = null })
            } else if (twoPane) {
                val hingeLeft = hingeX?.let { with(LocalDensity.current) { it.toDp() } }
                Row(Modifier.fillMaxSize()) {
                    Box(Modifier.width(listPaneWidth(windowWidth, hingeLeft)).fillMaxHeight()) { home() }
                    VerticalDivider()
                    Box(Modifier.weight(1f).fillMaxHeight(), contentAlignment = Alignment.TopCenter) {
                        Box(Modifier.widthIn(max = MaxDetailPane).fillMaxSize()) {
                            when {
                                adminOpen -> AdminScreen(vm, logs, players, onBack = { adminOpen = false })
                                showDares -> DaresScreen(vm, players, logs, shared, myId!!, onBack = { daresOpen = false })
                                selected != null -> PlayerScreen(vm, selected, logs, cards, hinge, onBack = null, onPuzzle = { puzzleId = selected.id })
                                else -> Text("> pick a player", color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.align(Alignment.Center))
                            }
                        }
                    }
                }
            } else {
                when {
                    adminOpen -> AdminScreen(vm, logs, players, onBack = { adminOpen = false })
                    showDares -> DaresScreen(vm, players, logs, shared, myId!!, onBack = { daresOpen = false })
                    selected != null -> PlayerScreen(vm, selected, logs, cards, hinge, onBack = { selectedId = null },
                        onPuzzle = { puzzleId = selected.id })
                    else -> home()
                }
            }
        }
    }
}
