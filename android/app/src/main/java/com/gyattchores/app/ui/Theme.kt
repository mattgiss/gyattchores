package com.gyattchores.app.ui

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily

val Accent = Color(0xFFF23861)
val Warn = Color(0xFFF5A623)
val Bad = Color(0xFFEF4444)
val Good = Color(0xFF16A34A)

/**
 * Material You: surfaces and containers follow the wallpaper (Pixel's dynamic color) on Android 12+,
 * while primary stays GyattChores pink so the brand survives. Monospace everywhere, like the web app.
 */
@Composable
fun GyattTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val ctx = LocalContext.current
    val base = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> if (dark) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
        dark -> darkColorScheme()
        else -> lightColorScheme(background = Color.White, surface = Color.White)
    }
    val scheme = base.copy(primary = Accent, onPrimary = Color.White)
    val mono = FontFamily.Monospace
    val t = Typography()
    fun TextStyle.m() = copy(fontFamily = mono)
    val type = Typography(
        displayLarge = t.displayLarge.m(), displayMedium = t.displayMedium.m(), displaySmall = t.displaySmall.m(),
        headlineLarge = t.headlineLarge.m(), headlineMedium = t.headlineMedium.m(), headlineSmall = t.headlineSmall.m(),
        titleLarge = t.titleLarge.m(), titleMedium = t.titleMedium.m(), titleSmall = t.titleSmall.m(),
        bodyLarge = t.bodyLarge.m(), bodyMedium = t.bodyMedium.m(), bodySmall = t.bodySmall.m(),
        labelLarge = t.labelLarge.m(), labelMedium = t.labelMedium.m(), labelSmall = t.labelSmall.m(),
    )
    val fb = remember { Feedback(ctx.applicationContext) }
    CompositionLocalProvider(LocalFeedback provides fb) {
        MaterialTheme(colorScheme = scheme, typography = type, content = content)
    }
}
