package com.gyattchores.app

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import com.gyattchores.app.ui.AppRoot
import com.gyattchores.app.ui.GyattTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** FragmentActivity because the biometric prompt needs one. */
class MainActivity : FragmentActivity() {
    private val vm: AppViewModel by viewModels()
    private var fold by mutableStateOf<FoldingFeature?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Dark only: white status and navigation bar icons over the colour bands and the black.
        enableEdgeToEdge(
            statusBarStyle = androidx.activity.SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
            navigationBarStyle = androidx.activity.SystemBarStyle.dark(android.graphics.Color.TRANSPARENT),
        )
        takeTestIntent(intent)

        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                WindowInfoTracker.getOrCreate(this@MainActivity).windowLayoutInfo(this@MainActivity).collect { info ->
                    fold = info.displayFeatures.filterIsInstance<FoldingFeature>().firstOrNull()
                }
            }
        }

        // Sync on open and every 10 seconds while the app is on screen.
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) { while (true) { vm.requestSync(); delay(10_000) } }
        }

        setContent { GyattTheme { AppRoot(vm, fold) } }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        takeTestIntent(intent)
        vm.requestSync()
    }

    /**
     * Debug builds: `adb shell am start ... --es restoreFile <name>` restores a backup pushed to the
     * app's external files folder (for previews on an emulator). `--ez memoryRelay true` syncs with
     * an in-memory encrypted relay instead of the real one, and `--es scanResult <code>` (or
     * `seeded`, a family made up on that relay) is what "Join with a code" reads instead of the
     * camera. All ignored in release.
     */
    private fun takeTestIntent(intent: android.content.Intent?) {
        if (BuildConfig.DEBUG && intent?.getBooleanExtra("memoryRelay", false) == true) vm.useMemoryRelay()
        if (BuildConfig.DEBUG) intent?.getStringExtra("scanResult")?.let { vm.setTestScanResult(it) }
        if (BuildConfig.DEBUG) intent?.getStringExtra("restoreFile")?.let { name ->
            runCatching { vm.restore(com.gyattchores.app.engine.Backup.decode(java.io.File(getExternalFilesDir(null), name).readText())) }
                .onFailure { android.util.Log.w("GyattChores", "restoreFile $name: $it") }
        }
    }
}
