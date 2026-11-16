package com.gyattchores.app.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.luminance
import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.gyattchores.app.R

/**
 * A look for the app, chosen per phone (the same list as iOS's AppTheme). "Clear" is the default:
 * black, with Clear's red-to-yellow heat map for the players, its ocean blues for the admin area and
 * its plums for the dares. The rest are four colours each (background, main, muted, text), an idea
 * borrowed from monkeytype's themes; the palettes are from its dark themes, under names of our own.
 */
data class AppTheme(val id: String, val name: String, val bg: Color, val main: Color, val sub: Color, val text: Color) {
    val isClear get() = id == "clear"
    /** Text on a band of the main colour: the background colour when the main colour is light. */
    val ink get() = if (main.luminance() > 0.45f) bg else Color.White
    val surface get() = lerp(bg, text, if (isClear) 0.08f else 0.07f)
    /** Muted text and finished rows. */
    val muted get() = if (isClear) sub else lerp(sub, text, 0.25f)

    val heat get() = if (isClear) Palette(listOf(Color(0xFFD90015), Color(0xFFDB2A15), Color(0xFFE04A19), Color(0xFFE2751C), Color(0xFFE99A22), Color(0xFFEDB82A)), Color.White)
        else Palette(listOf(main, lerp(main, bg, 0.18f), lerp(main, bg, 0.34f), lerp(main, bg, 0.48f)), ink)
    val ocean get() = if (isClear) Palette(listOf(Color(0xFF3E9FC4), Color(0xFF45AAC0), Color(0xFF4FAFAE), Color(0xFF58B6A1), Color(0xFF60BD8F), Color(0xFF6BC276)), Color.White)
        else lerp(main, text, 0.25f).let { top -> Palette(listOf(top, lerp(main, bg, 0.2f), lerp(main, bg, 0.4f)), if (top.luminance() > 0.45f) bg else Color.White) }
    /** The dares: a quieter, after-dark version of the theme. */
    val plum get() = if (isClear) Palette(listOf(Color(0xFF34207A), Color(0xFF2B1869), Color(0xFF281760), Color(0xFF26165C), Color(0xFF201453)), Color(0xFFB9A2FF))
        else Palette(listOf(lerp(sub, bg, 0.2f), lerp(sub, bg, 0.45f), lerp(sub, bg, 0.6f)), text)

    companion object {
        val CLEAR = AppTheme("clear", "Clear", Color(0xFF000000), Color(0xFFD90015), Color(0xFF5A5A5E), Color(0xFFFFFFFF))
        val ALL = listOf(
            CLEAR,
            AppTheme("mustard", "Mustard", Color(0xFF323437), Color(0xFFE2B714), Color(0xFF646669), Color(0xFFD1D0C5)),
            AppTheme("ember", "Ember", Color(0xFF313131), Color(0xFFF66E0D), Color(0xFF616161), Color(0xFFF5E6C8)),
            AppTheme("bubblegum", "Bubblegum", Color(0xFF333A45), Color(0xFFF44C7F), Color(0xFF939EAE), Color(0xFFE9ECF0)),
            AppTheme("coral", "Coral", Color(0xFF2D394D), Color(0xFFFF7A90), Color(0xFF4A768D), Color(0xFFFFFAF8)),
            AppTheme("grape", "Grape", Color(0xFF282A36), Color(0xFFBD93F9), Color(0xFF6272A4), Color(0xFFF8F8F2)),
            AppTheme("fjord", "Fjord", Color(0xFF242933), Color(0xFF88C0D0), Color(0xFF929AAA), Color(0xFFD8DEE9)),
            AppTheme("lavender", "Lavender", Color(0xFF1E1E2E), Color(0xFFCBA6F7), Color(0xFF7F849C), Color(0xFFCDD6F4)),
            AppTheme("lagoon", "Lagoon", Color(0xFF1F1D27), Color(0xFF9CCFD8), Color(0xFFC4A7E7), Color(0xFFE0DEF4)),
            AppTheme("campfire", "Campfire", Color(0xFF282828), Color(0xFFD79921), Color(0xFF665C54), Color(0xFFEBDBB2)),
            AppTheme("matcha", "Matcha", Color(0xFF523525), Color(0xFF7EC160), Color(0xFF9E6749), Color(0xFFECDDCC)),
            AppTheme("neon", "Neon", Color(0xFF262A33), Color(0xFF43FFAF), Color(0xFF526777), Color(0xFFE5F7EF)),
            AppTheme("sunset", "Sunset", Color(0xFF18181A), Color(0xFFE4609B), Color(0xFF47BAC0), Color(0xFFFFFFFF)),
            AppTheme("aurora", "Aurora", Color(0xFF011926), Color(0xFF00E980), Color(0xFF245C69), Color(0xFFFFFFFF)),
            AppTheme("peach", "Peach", Color(0xFF1C1B1D), Color(0xFFDEAF9D), Color(0xFF4E3E3E), Color(0xFFF2EFED)),
        )
    }
}

/** This phone's theme. Read during drawing, so a change redraws every screen. */
object Themes {
    var current by mutableStateOf(AppTheme.CLEAR)
    private const val KEY = "theme"
    fun load(ctx: Context) {
        val id = ctx.getSharedPreferences("look", Context.MODE_PRIVATE).getString(KEY, null)
        current = AppTheme.ALL.firstOrNull { it.id == id } ?: AppTheme.CLEAR
    }
    fun pick(ctx: Context, t: AppTheme) {
        current = t
        ctx.getSharedPreferences("look", Context.MODE_PRIVATE).edit().putString(KEY, t.id).apply()
    }
}

/** Links and highlights. */
val Accent: Color get() = if (Themes.current.isClear) Color(0xFFE8572A) else Themes.current.main
val Warn = Color(0xFFEDB82A)
val Bad = Color(0xFFFF4D3D)
val Good = Color(0xFF6BC276)
/** Where a finished row goes, and quiet text. */
val Done: Color get() = Themes.current.muted
val SurfaceDark: Color get() = Themes.current.surface
/** The theme's background and ordinary text. */
val Bg: Color get() = Themes.current.bg
val Ink: Color get() = Themes.current.text
/** The puzzle's two colours of block. */
val BlockA: Color get() = if (Themes.current.isClear) Color(0xFFD90015) else Themes.current.main
val BlockB: Color get() = if (Themes.current.isClear) Color(0xFF45AAC0) else lerp(Themes.current.sub, Themes.current.text, 0.35f)

/** A run of colours that list rows step down, Clear-style, with the colour for text on them. */
data class Palette(val stops: List<Color>, val ink: Color) {
    /** Row [index] of [count]: as in Clear, a small step per row; a long list spreads the whole gradient out. */
    fun band(index: Int, count: Int): Color {
        if (count <= 1 || index <= 0 || stops.size < 2) return stops[0]
        val t = (index.toFloat() / maxOf(count - 1, 7)).coerceAtMost(1f) * (stops.size - 1)
        val i = minOf(t.toInt(), stops.size - 2)
        return lerp(stops[i], stops[i + 1], t - i)
    }

    companion object {
        val HEAT get() = Themes.current.heat
        val OCEAN get() = Themes.current.ocean
        val PLUM get() = Themes.current.plum
    }
}

/** Which run of bands this part of the app uses. */
val LocalPalette = compositionLocalOf { Palette.HEAT }

/** Schibsted Grotesk, in the four weights the app uses (anything else snaps to the nearest). */
val AppFont = FontFamily(
    Font(R.font.schibsted_grotesk_regular, FontWeight.Normal),
    Font(R.font.schibsted_grotesk_semibold, FontWeight.SemiBold),
    Font(R.font.schibsted_grotesk_bold, FontWeight.Bold),
    Font(R.font.schibsted_grotesk_black, FontWeight.Black),
)

/**
 * Dark only, like Clear: black behind everything, the colour is in the rows. One typeface
 * everywhere: Schibsted Grotesk (SIL Open Font License), bundled so it looks the same as on the iPhone.
 */
@Composable
fun GyattTheme(content: @Composable () -> Unit) {
    val ctx = LocalContext.current
    LaunchedEffect(Unit) { Themes.load(ctx) }
    val t = Themes.current
    val scheme = darkColorScheme(
        primary = Accent, onPrimary = t.ink, secondary = Accent,
        background = t.bg, onBackground = t.text, surface = t.bg, onSurface = t.text,
        surfaceVariant = t.surface, onSurfaceVariant = t.muted, outline = t.muted,
        surfaceContainer = t.surface, surfaceContainerHigh = lerp(t.bg, t.text, 0.1f), surfaceContainerHighest = lerp(t.bg, t.text, 0.13f),
        secondaryContainer = lerp(t.bg, t.text, 0.16f), onSecondaryContainer = t.text, error = Bad,
    )
    val ty = Typography()
    fun TextStyle.m() = copy(fontFamily = AppFont)
    val type = Typography(
        displayLarge = ty.displayLarge.m(), displayMedium = ty.displayMedium.m(), displaySmall = ty.displaySmall.m(),
        headlineLarge = ty.headlineLarge.m(), headlineMedium = ty.headlineMedium.m(), headlineSmall = ty.headlineSmall.m(),
        titleLarge = ty.titleLarge.m(), titleMedium = ty.titleMedium.m(), titleSmall = ty.titleSmall.m(),
        bodyLarge = ty.bodyLarge.m(), bodyMedium = ty.bodyMedium.m(), bodySmall = ty.bodySmall.m(),
        labelLarge = ty.labelLarge.m(), labelMedium = ty.labelMedium.m(), labelSmall = ty.labelSmall.m(),
    )
    val fb = remember { Feedback(ctx.applicationContext) }
    // The default bands follow the theme; a part of the app can still ask for another run (admin, dares).
    CompositionLocalProvider(LocalFeedback provides fb, LocalPalette provides t.heat) {
        MaterialTheme(colorScheme = scheme, typography = type, content = content)
    }
}
