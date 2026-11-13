package com.gyattchores.app.ui

import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutLinearInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gyattchores.app.AppViewModel
import com.gyattchores.app.engine.PuzzleBoard
import com.gyattchores.app.model.Player
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.random.Random

/** How long the frame holds still between the last hit and the level-up surge. */
private const val FREEZE_MS = 300

/** One shard of a burst: where it started, how it flies, and when. Positions are in board pixels. */
private class Shard(
    val x: Float, val y: Float, val vx: Float, val vy: Float, val size: Float,
    val color: Color, val born: Long, val lifeMs: Float, val spin: Float,
)

/** A ring of light spreading out from an impact. */
private class Ring(val x: Float, val y: Float, val born: Long, val delayMs: Float, val speed: Float)

/**
 * The reward puzzle, "CLEAR THE GRID". Tap a block, then a block of the other colour in line with
 * it and nothing between: the first flies into the second and both shatter. Clear the board to
 * level up — the last hit freezes the frame for a beat, then the screen flashes, shakes and
 * the new level slams in, timed to the phone's strongest haptics.
 */
@Composable
fun PuzzleScreen(vm: AppViewModel, player: Player, onBack: () -> Unit) {
    val fb = LocalFeedback.current
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    // "Remove animations" in the system settings turns off the shake, jitter and big flash.
    val calm = remember {
        Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
    val pack = vm.puzzlePack
    val ink = MaterialTheme.colorScheme.onSurface
    val wallColor = MaterialTheme.colorScheme.outlineVariant
    val dotColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)
    val bg = MaterialTheme.colorScheme.background

    var level by rememberSaveable(player.id) { mutableIntStateOf(vm.puzzleLevel(player.id)) }
    // The board as its cell string, so folding or rotating the phone keeps the game in progress.
    var cells by rememberSaveable(player.id, level) { mutableStateOf(pack.levels[pack.index(level)].cells) }
    val start = pack.board(level)
    val board = PuzzleBoard(start.width, start.height, cells)
    var selected by remember(level) { mutableStateOf<Int?>(null) }
    var busy by remember { mutableStateOf(false) }
    var flying by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    val fly = remember { Animatable(0f) }
    var frozen by remember { mutableStateOf(false) }
    var celebrating by rememberSaveable(player.id, level) { mutableStateOf(false) }
    var miss by remember { mutableStateOf<Pair<Int, Long>?>(null) }
    val shards = remember { mutableStateListOf<Shard>() }
    val rings = remember { mutableStateListOf<Ring>() }
    val flash = remember { Animatable(0f) }
    val shakeX = remember { Animatable(0f) }
    val shakeY = remember { Animatable(0f) }
    val zoom = remember { Animatable(1f) }
    var cleared by remember { mutableIntStateOf(0) }

    // One clock for everything that moves on its own: the selection pulse, shards and rings.
    var now by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        while (true) {
            withFrameNanos { now = it / 1_000_000 }
            // Forget effects that have finished.
            if (shards.isNotEmpty()) shards.removeAll { now - it.born > it.lifeMs }
            if (rings.isNotEmpty()) rings.removeAll { now - it.born - it.delayMs > 600 }
        }
    }

    var cellPx by remember { mutableStateOf(0f) }
    fun center(i: Int) = Offset((board.column(i) + 0.5f) * cellPx, (board.row(i) + 0.5f) * cellPx)

    /** Shards flying out from [at]; [power] is roughly how many cells a second the fastest travel. */
    fun burst(at: Offset, colors: List<Color>, count: Int, power: Float) {
        val r = Random(now)
        repeat(count) {
            val angle = r.nextFloat() * 2 * PI.toFloat()
            val speed = (0.35f + r.nextFloat()) * power * cellPx / 1000f   // pixels per millisecond
            shards += Shard(
                at.x, at.y, cos(angle) * speed, sin(angle) * speed - power * cellPx / 4000f,
                cellPx * (0.07f + r.nextFloat() * 0.13f), colors[it % colors.size], now,
                500f + r.nextFloat() * 500f, (r.nextFloat() - 0.5f) * 1.4f,
            )
        }
    }

    fun shake(strength: Float) = scope.launch {
        if (calm) return@launch
        val steps = listOf(1f, -0.85f, 0.7f, -0.55f, 0.4f, -0.25f, 0.12f, 0f)
        for (s in steps) {
            launch { shakeY.animateTo(-s * strength * 0.6f, tween(32, easing = LinearEasing)) }
            shakeX.animateTo(s * strength, tween(32, easing = LinearEasing))
        }
    }

    fun restart() {
        fb.tap(); cells = pack.levels[pack.index(level)].cells; selected = null; shards.clear(); rings.clear()
    }

    fun nextLevel() {
        fb.unlock(); celebrating = false; shards.clear(); rings.clear(); selected = null
        level = vm.puzzleLevel(player.id)
    }

    fun play(from: Int, to: Int) {
        busy = true
        selected = null
        scope.launch {
            flying = from to to
            fly.snapTo(0f)
            fly.animateTo(1f, tween(110, easing = FastOutLinearInEasing))
            val next = board.match(from, to) ?: run { flying = null; busy = false; return@launch }
            val hit = center(to)
            if (next.cleared) {
                // Hit-stop: the impact, then the whole frame holds perfectly still.
                fb.puzzleLevelUp(FREEZE_MS)
                frozen = true
                zoom.snapTo(1.06f)
                delay(FREEZE_MS.toLong())
                frozen = false
                cells = next.cellString
                flying = null
                cleared = board.blocksLeft
                vm.puzzleCleared(player.id, level)
                launch { zoom.animateTo(1f, spring(dampingRatio = 0.4f, stiffness = Spring.StiffnessMedium)) }
                burst(hit, listOf(Accent, ink, Accent, Color.White), 90, 7f)
                repeat(3) { rings += Ring(hit.x, hit.y, now, it * 90f, cellPx * (6f + it * 2f)) }
                launch { flash.snapTo(if (calm) 0.35f else 0.92f); flash.animateTo(0f, tween(520)) }
                shake(cellPx * 0.28f)
                // Let the explosion read on the board before the card covers it.
                delay(350)
                celebrating = true
            } else {
                fb.puzzleMatch()
                cells = next.cellString
                flying = null
                burst(hit, listOf(Accent, ink), 22, 3f)
                rings += Ring(hit.x, hit.y, now, 0f, cellPx * 3f)
                shake(cellPx * 0.06f)
                if (next.stuck) { delay(250); fb.reject() }
            }
            busy = false
        }
    }

    fun tap(i: Int) {
        if (busy || celebrating) return
        val sel = selected
        when {
            i !in 0 until board.size || !board.isBlock(i) -> selected = null
            sel == null || sel == i -> { if (sel == i) selected = null else { fb.puzzleSelect(); selected = i } }
            board[sel] == board[i] -> { fb.puzzleSelect(); selected = i }
            board.canMatch(sel, i) -> play(sel, i)
            // Not reachable from here: the block in hand shakes its head and is put down.
            else -> { fb.puzzleMiss(); miss = sel to now; selected = null }
        }
    }

    // The tap handler reads this composition's board; the gesture detector outlives compositions.
    val onTap by rememberUpdatedState<(Int) -> Unit> { tap(it) }

    Box(Modifier.fillMaxSize().background(bg)) {
        Column(
            Modifier.fillMaxSize()
                .offset { IntOffset(shakeX.value.roundToInt(), shakeY.value.roundToInt()) },
        ) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { fb.tap(); onBack() }) { Text("← back") }
                Text("CLEAR THE GRID", style = MaterialTheme.typography.labelMedium, letterSpacing = 3.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, softWrap = false,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis, modifier = Modifier.weight(1f).padding(horizontal = 4.dp))
                Text("LVL $level", color = Accent, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                TextButton(onClick = ::restart, enabled = !busy && !celebrating) { Text("restart") }
            }
            Text(
                when {
                    board.stuck -> "no moves left — the order matters. restart and try another way."
                    selected != null -> "now tap a ${if (board[selected!!] == PuzzleBoard.PINK) "black" else "pink"} block in line with it"
                    else -> "tap a block, then one of the other colour in line with it. clear them all."
                },
                color = if (board.stuck) Bad else MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp),
            )
            BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().padding(20.dp), contentAlignment = Alignment.Center) {
                val density = LocalDensity.current
                val cell = min(maxWidth.value / board.width, maxHeight.value / board.height).coerceAtMost(72f)
                cellPx = with(density) { cell.dp.toPx() }
                Canvas(
                    Modifier.size((cell * board.width).dp, (cell * board.height).dp)
                        .graphicsLayer { scaleX = zoom.value; scaleY = zoom.value }
                        .semantics { contentDescription = "puzzle board, ${board.blocksLeft} blocks left" }
                        .pointerInput(board.width, board.height, cellPx) {
                            detectTapGestures { p ->
                                val x = (p.x / cellPx).toInt(); val y = (p.y / cellPx).toInt()
                                if (x in 0 until board.width && y in 0 until board.height) onTap(y * board.width + x) else onTap(-1)
                            }
                        },
                ) {
                    val t = now
                    drawBoard(board, cellPx, t, selected, flying, fly.value, frozen, miss, ink, wallColor, dotColor)
                    drawEffects(shards, rings, t, frozen, cellPx)
                }
            }
            Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp)) {
                Text("${board.blocksLeft} blocks left", color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 8.dp))
                if (board.stuck && !busy) TermButton("RESTART LEVEL") { restart() }
            }
        }

        // The flash, in the app's pink.
        if (flash.value > 0f) Box(Modifier.fillMaxSize().background(Accent.copy(alpha = flash.value)))
        if (celebrating) LevelUp(level + 1, cleared, now, calm, onNext = ::nextLevel, onBack = { fb.tap(); onBack() })
    }
}

private fun DrawScope.drawBoard(
    board: PuzzleBoard, cell: Float, now: Long, selected: Int?, flying: Pair<Int, Int>?, fly: Float, frozen: Boolean,
    miss: Pair<Int, Long>?, ink: Color, wall: Color, dot: Color,
) {
    val pad = cell * 0.08f
    val corner = CornerRadius(cell * 0.16f)
    val pulse = (sin(now / 140.0) * 0.5 + 0.5).toFloat()
    val targets = selected?.let { board.targets(it).toSet() } ?: emptySet()
    for (i in 0 until board.size) {
        val origin = Offset(board.column(i) * cell, board.row(i) * cell)
        val c = board[i]
        if (c == PuzzleBoard.EMPTY) {
            drawCircle(dot, cell * 0.04f, origin + Offset(cell / 2, cell / 2))
            continue
        }
        if (c == PuzzleBoard.WALL) {
            drawRoundRect(wall, origin + Offset(pad, pad), Size(cell - 2 * pad, cell - 2 * pad), corner,
                style = Stroke(cell * 0.05f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(cell * 0.1f, cell * 0.07f))))
            drawLine(wall, origin + Offset(cell * 0.3f, cell * 0.7f), origin + Offset(cell * 0.7f, cell * 0.3f), cell * 0.05f)
            continue
        }
        if (flying?.first == i) continue   // drawn on top, in flight
        // During the freeze everything else drops back while the impact hangs in the air.
        val color = (if (c == PuzzleBoard.PINK) Accent else ink).let { if (frozen) it.copy(alpha = 0.3f) else it }
        var shift = Offset.Zero
        if (miss != null && miss.first == i && now - miss.second < 260) {
            val k = (now - miss.second) / 260f
            shift = Offset(sin(k * 6 * PI).toFloat() * cell * 0.08f * (1 - k), 0f)
        }
        val grow = if (i == selected) cell * 0.04f * (1 + pulse) else 0f
        val topLeft = origin + shift + Offset(pad - grow, pad - grow)
        val size = Size(cell - 2 * pad + 2 * grow, cell - 2 * pad + 2 * grow)
        if (i == selected) {
            drawRoundRect(Accent.copy(alpha = 0.25f + 0.25f * pulse), topLeft - Offset(cell * 0.06f, cell * 0.06f),
                Size(size.width + cell * 0.12f, size.height + cell * 0.12f), CornerRadius(cell * 0.22f))
        }
        drawRoundRect(color, topLeft, size, corner)
        // A small highlight so blocks read as solid tiles, not flat squares.
        drawRoundRect(Color.White.copy(alpha = 0.18f), topLeft + Offset(size.width * 0.12f, size.height * 0.1f),
            Size(size.width * 0.76f, size.height * 0.14f), CornerRadius(cell * 0.06f))
        if (i in targets) {
            drawRoundRect(Accent.copy(alpha = 0.5f + 0.5f * pulse), topLeft - Offset(cell * 0.04f, cell * 0.04f),
                Size(size.width + cell * 0.08f, size.height + cell * 0.08f), CornerRadius(cell * 0.2f),
                style = Stroke(cell * 0.045f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(cell * 0.12f, cell * 0.08f), now / 30f % (cell * 0.2f))))
        }
    }
    if (flying != null) {
        val (from, to) = flying
        val a = Offset(board.column(from) * cell, board.row(from) * cell)
        val b = Offset(board.column(to) * cell, board.row(to) * cell)
        val p = a + (b - a) * fly
        val color = if (board[from] == PuzzleBoard.PINK) Accent else ink
        // A streak behind the block in flight.
        drawLine(color.copy(alpha = 0.35f), a + Offset(cell / 2, cell / 2), p + Offset(cell / 2, cell / 2), cell * 0.5f)
        drawRoundRect(color, p + Offset(pad, pad), Size(cell - 2 * pad, cell - 2 * pad), corner)
        if (frozen) {
            // The moment of impact, held: a white-hot core in a pink halo.
            val hit = b + Offset(cell / 2, cell / 2)
            drawCircle(Accent.copy(alpha = 0.55f), cell * 1.1f, hit)
            drawCircle(Color.White, cell * 0.55f, hit)
        }
    }
}

private fun DrawScope.drawEffects(shards: List<Shard>, rings: List<Ring>, now: Long, frozen: Boolean, cell: Float) {
    if (frozen) return
    for (r in rings) {
        val t = (now - r.born - r.delayMs) / 1000f
        if (t < 0f || t > 0.6f) continue
        val k = t / 0.6f
        drawCircle(Accent.copy(alpha = (1 - k) * 0.9f), r.speed * t + 4f, Offset(r.x, r.y), style = Stroke((1 - k) * cell * 0.12f + 1f))
    }
    for (s in shards) {
        val ms = (now - s.born).toFloat()
        if (ms < 0 || ms > s.lifeMs) continue
        val gravity = cell * 12f / 1_000_000f   // about twelve cells per second per second
        val x = s.x + s.vx * ms
        val y = s.y + s.vy * ms + 0.5f * gravity * ms * ms
        val alpha = 1 - ms / s.lifeMs
        translate(x, y) {
            rotate(s.spin * ms / 3f, Offset.Zero) {
                drawRect(s.color.copy(alpha = alpha), Offset(-s.size / 2, -s.size / 2), Size(s.size, s.size))
            }
        }
    }
}

/** The level-up card: glitching "LEVEL UP", the new level slamming in, then the way on. */
@Composable
private fun LevelUp(newLevel: Int, cleared: Int, now: Long, calm: Boolean, onNext: () -> Unit, onBack: () -> Unit) {
    val born = remember { now }
    val slam = remember { Animatable(if (calm) 1f else 3f) }
    var ready by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        launch { slam.animateTo(1f, spring(dampingRatio = 0.42f, stiffness = 380f)) }
        delay(750); ready = true
    }
    val age = now - born
    // The glitch: three copies of the title, split apart and jittering for the first moments.
    val jitter = if (calm || age > 650) 0f else (Random(now / 40).nextFloat() - 0.5f) * 18f * (1 - age / 650f)
    // The colour split closes up as the glitch settles, leaving a clean title.
    val split = if (calm) 0f else 3f * (1 - (age / 650f).coerceIn(0f, 1f))
    val ink = MaterialTheme.colorScheme.onSurface
    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background.copy(alpha = 0.82f)), contentAlignment = Alignment.Center) {
        // Scanlines over the whole card, fading out.
        Canvas(Modifier.fillMaxSize()) {
            val a = (1 - age / 1200f).coerceIn(0f, 1f) * 0.12f
            if (a > 0f) {
                var y = 0f
                while (y < size.height) { drawRect(ink.copy(alpha = a), Offset(0f, y), Size(size.width, 2f)); y += 6f }
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(32.dp)) {
            Box {
                val title = "LEVEL UP"
                val style = MaterialTheme.typography.displaySmall
                Text(title, style = style, fontWeight = FontWeight.Black, color = ink.copy(alpha = 0.7f),
                    modifier = Modifier.offset((-split + jitter).dp, 0.dp))
                Text(title, style = style, fontWeight = FontWeight.Black, color = Accent.copy(alpha = 0.85f),
                    modifier = Modifier.offset((split - jitter).dp, (jitter / 3).dp))
                Text(title, style = style, fontWeight = FontWeight.Black, color = ink)
            }
            Spacer(Modifier.height(12.dp))
            Text("LVL $newLevel", fontSize = 64.sp, fontWeight = FontWeight.Black, color = Accent,
                modifier = Modifier.graphicsLayer { scaleX = slam.value; scaleY = slam.value })
            Text("$cleared blocks cleared", color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))
            Spacer(Modifier.height(28.dp))
            if (ready) {
                TermButton("NEXT LEVEL", onClick = onNext)
                OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) { Text("back to my chores") }
            } else Spacer(Modifier.height(104.dp))
        }
    }
}
