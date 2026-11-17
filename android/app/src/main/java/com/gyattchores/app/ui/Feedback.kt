package com.gyattchores.app.ui

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.runtime.staticCompositionLocalOf
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sign
import kotlin.math.sin

val LocalFeedback = staticCompositionLocalOf<Feedback> { error("Feedback not provided") }

/**
 * The app's sound and touch feedback. Sounds are short synthesized chiptune-style blips (no audio
 * files), played at media volume like a game. Haptics use the system's tuned effects where they
 * exist and custom patterns for the celebrations.
 */
class Feedback(context: Context) {
    private val prefs = context.getSharedPreferences("feedback", Context.MODE_PRIVATE)
    private val vibrator: Vibrator? = context.getSystemService(Vibrator::class.java)
    private val pool = Executors.newFixedThreadPool(3)
    private val cache = HashMap<String, ShortArray>()

    var soundOn: Boolean
        get() = prefs.getBoolean("sound", true)
        set(v) = prefs.edit().putBoolean("sound", v).apply()

    // ─── Moments ────────────────────────────────────────────────────────────

    /** Navigation and small taps. */
    fun tap() { buzz(VibrationEffect.EFFECT_TICK); play("tap") { synth(N(84, 18, gain = 0.5f)) } }

    /** Checking or unchecking a chore. */
    fun tick(on: Boolean) {
        buzz(if (on) VibrationEffect.EFFECT_CLICK else VibrationEffect.EFFECT_TICK)
        if (on) play("on") { synth(N(76, 35), N(83, 60)) } else play("off") { synth(N(76, 30), N(69, 50, gain = 0.7f)) }
    }

    /** "Suggest a card": a quick run up the scale. */
    fun fill() {
        pattern(longArrayOf(0, 12, 35, 12, 35, 12, 35, 20), intArrayOf(0, 70, 0, 100, 0, 140, 0, 190))
        play("fill") { synth(N(72, 40), N(76, 40), N(79, 40), N(83, 40), N(84, 110)) }
    }

    /** The card just reached a full day's worth. */
    fun ready() { buzz(VibrationEffect.EFFECT_DOUBLE_CLICK); play("ready") { synth(N(79, 60), N(86, 140)) } }

    fun lockIn() { buzz(VibrationEffect.EFFECT_HEAVY_CLICK); play("lock") { synth(N(60, 70, wave = 1f), N(67, 70, wave = 1f), N(72, 160, wave = 1f)) } }

    fun submit() {
        pattern(longArrayOf(0, 25, 45, 25, 45, 80), intArrayOf(0, 90, 0, 130, 0, 200))
        play("submit") { synth(N(72, 80), N(76, 80), N(79, 80), N(84, 240)) }
    }

    /** A dare placed: a sly little two-step. */
    fun dare() {
        pattern(longArrayOf(0, 20, 60, 30), intArrayOf(0, 120, 0, 200))
        play("dare") { synth(N(70, 60, wave = 0.6f), N(0, 30), N(77, 50, wave = 0.6f), N(82, 140, wave = 0.6f)) }
    }

    /** Yesterday's dares landed: sparkle. */
    fun dareLanded() {
        pattern(longArrayOf(0, 20, 40, 20, 40, 120), intArrayOf(0, 120, 0, 180, 0, 255))
        play("landed") { synth(N(88, 45), N(91, 45), N(95, 45), N(100, 220, gain = 0.8f)) }
    }

    /** Parent approved a chore: a coin-like two-note chime. */
    fun approve() { buzz(VibrationEffect.EFFECT_CLICK); play("approve") { synth(N(83, 60), N(88, 220)) } }

    fun reject() {
        pattern(longArrayOf(0, 60, 60, 60), intArrayOf(0, 160, 0, 160))
        play("reject") { synth(N(57, 110, end = 52, wave = 1f, gain = 0.8f), N(50, 180, end = 45, wave = 1f, gain = 0.8f)) }
    }

    /** Something isn't allowed (chore doesn't fit, wrong code). */
    fun error() {
        pattern(longArrayOf(0, 40, 50, 40), intArrayOf(0, 200, 0, 200))
        play("error") { synth(N(48, 90, wave = 1f, gain = 0.8f), N(0, 30), N(48, 120, wave = 1f, gain = 0.8f)) }
    }

    fun unlock() { buzz(VibrationEffect.EFFECT_HEAVY_CLICK); play("unlock") { synth(N(67, 50), N(74, 50), N(79, 50), N(86, 180)) } }

    /** A new version shipped: the big one. */
    fun levelUp() {
        pattern(longArrayOf(0, 40, 40, 40, 40, 40, 40, 60, 60, 300), intArrayOf(0, 100, 0, 140, 0, 180, 0, 220, 0, 255))
        play("level") {
            synth(N(72, 90, wave = 0.6f), N(72, 90, wave = 0.6f), N(72, 90, wave = 0.6f), N(79, 180, wave = 0.6f),
                N(77, 90, wave = 0.6f), N(79, 90, wave = 0.6f), N(84, 420, wave = 0.6f), N(96, 300, gain = 0.5f))
        }
    }

    // ─── Puzzle ─────────────────────────────────────────────────────────────

    /** Picking up a block. */
    fun puzzleSelect() { buzz(VibrationEffect.EFFECT_TICK); play("pz-sel") { synth(N(88, 22, gain = 0.45f), N(95, 30, gain = 0.35f)) } }

    /** Two blocks collide and vanish: a sharp crack with a little weight behind it. */
    fun puzzleMatch() {
        compose(fallback = { pattern(longArrayOf(0, 16, 18, 28), intArrayOf(0, 255, 0, 110)) }) {
            addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 1f)
            addPrimitive(thud(), 0.55f, 12)
        }
        play("pz-hit") { synth(N(98, 22, end = 74, wave = 1f, gain = 0.55f), N(62, 70, end = 41, wave = 0.8f, gain = 0.7f)) }
    }

    /** That block can't be reached from here. */
    fun puzzleMiss() {
        pattern(longArrayOf(0, 22, 40, 22), intArrayOf(0, 120, 0, 120))
        play("pz-miss") { synth(N(52, 50, wave = 1f, gain = 0.6f), N(0, 20), N(47, 70, wave = 1f, gain = 0.6f)) }
    }

    /**
     * The board is clear — the big one, in three beats timed to the screen: the impact, [freezeMs] of
     * dead stillness while the frame is frozen, then a surge that quickens into a final slam.
     */
    fun puzzleLevelUp(freezeMs: Int) {
        compose(fallback = {
            pattern(
                longArrayOf(0, 45, freezeMs.toLong(), 90, 22, 34, 18, 30, 14, 26, 10, 24, 40, 220),
                intArrayOf(0, 255, 0, 170, 0, 210, 0, 235, 0, 255, 0, 255, 0, 255),
            )
        }) {
            addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 1f)
            addPrimitive(thud(), 1f, 0)
            addPrimitive(VibrationEffect.Composition.PRIMITIVE_QUICK_RISE, 1f, freezeMs)
            for ((gap, strength) in listOf(40 to 0.7f, 32 to 0.8f, 26 to 0.9f, 20 to 1f, 16 to 1f, 14 to 1f)) {
                addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, strength, gap)
            }
            addPrimitive(spin(), 1f, 24)
            addPrimitive(thud(), 1f, 50)
            addPrimitive(VibrationEffect.Composition.PRIMITIVE_QUICK_FALL, 0.8f, 40)
        }
        play("pz-level-$freezeMs") {
            synth(
                N(40, 110, end = 26, wave = 1f, gain = 0.9f), N(0, (freezeMs - 110).coerceAtLeast(0)),
                N(36, 90, end = 48, wave = 1f, gain = 0.8f),
                N(60, 55, wave = 0.6f), N(64, 55, wave = 0.6f), N(67, 55, wave = 0.6f), N(72, 55, wave = 0.6f),
                N(76, 55, wave = 0.6f), N(79, 55, wave = 0.6f), N(84, 340, wave = 0.6f),
                N(96, 60, gain = 0.45f), N(103, 260, gain = 0.4f),
            )
        }
    }

    // ─── Haptics ────────────────────────────────────────────────────────────

    // The richer primitives arrived in Android 12; before that, a click stands in for each.
    private fun thud() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) VibrationEffect.Composition.PRIMITIVE_THUD else VibrationEffect.Composition.PRIMITIVE_CLICK
    private fun spin() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) VibrationEffect.Composition.PRIMITIVE_SPIN else VibrationEffect.Composition.PRIMITIVE_QUICK_RISE

    /**
     * A composed effect from the haptic primitives, which feel sharper and heavier than a waveform,
     * on phones whose motor supports every primitive used; otherwise [fallback].
     */
    private fun compose(fallback: () -> Unit, build: VibrationEffect.Composition.() -> Unit) = runCatching {
        val v = vibrator ?: return@runCatching
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val used = mutableListOf(
                VibrationEffect.Composition.PRIMITIVE_CLICK, VibrationEffect.Composition.PRIMITIVE_QUICK_RISE,
                VibrationEffect.Composition.PRIMITIVE_QUICK_FALL, thud(), spin(),
            )
            if (v.areAllPrimitivesSupported(*used.toIntArray())) {
                v.vibrate(VibrationEffect.startComposition().apply(build).compose())
                return@runCatching
            }
        }
        fallback()
    }

    private fun buzz(effect: Int) = runCatching { vibrator?.vibrate(VibrationEffect.createPredefined(effect)) }

    private fun pattern(timings: LongArray, amplitudes: IntArray) = runCatching {
        val v = vibrator ?: return@runCatching
        if (v.hasAmplitudeControl()) v.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
        else v.vibrate(VibrationEffect.createWaveform(timings, -1))
    }

    // ─── Synth ──────────────────────────────────────────────────────────────

    /**
     * One note. [midi] 0 is a rest. [end] glides the pitch. [wave] blends sine (0) to square (1);
     * the default is a soft "electronic" mix.
     */
    private class N(val midi: Int, val ms: Int, val end: Int = midi, val wave: Float = 0.3f, val gain: Float = 1f)

    private fun freq(midi: Int) = 440.0 * 2.0.pow((midi - 69) / 12.0)

    private fun synth(vararg notes: N): ShortArray {
        val out = ShortArray(notes.sumOf { SR * it.ms / 1000 })
        var pos = 0
        for (n in notes) {
            val len = SR * n.ms / 1000
            if (n.midi != 0) {
                val f0 = freq(n.midi); val f1 = freq(n.end)
                val attack = (SR * 0.003).toInt().coerceAtLeast(1)
                val release = (SR * 0.006).toInt().coerceAtLeast(1)
                var phase = 0.0
                for (i in 0 until len) {
                    val t = i.toDouble() / len
                    phase += 2 * PI * (f0 + (f1 - f0) * t) / SR
                    val s = sin(phase)
                    val shaped = s * (1 - n.wave) + sign(s) * n.wave * 0.6
                    val env = minOf(1.0, i.toDouble() / attack) * exp(-3.0 * t) * minOf(1.0, (len - i).toDouble() / release)
                    out[pos + i] = (shaped * env * n.gain * MASTER * Short.MAX_VALUE).toInt().toShort()
                }
            }
            pos += len
        }
        return out
    }

    private fun play(key: String, build: () -> ShortArray) {
        if (!soundOn) return
        pool.execute {
            runCatching {
                val pcm = synchronized(cache) { cache.getOrPut(key, build) }
                val track = AudioTrack.Builder()
                    .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                    .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SR).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                    .setTransferMode(AudioTrack.MODE_STATIC).setBufferSizeInBytes(pcm.size * 2).build()
                try {
                    track.write(pcm, 0, pcm.size)
                    track.play()
                    Thread.sleep(pcm.size * 1000L / SR + 60)
                } finally { track.release() }
            }
        }
    }

    private companion object {
        const val SR = 44100
        const val MASTER = 0.32
    }
}
