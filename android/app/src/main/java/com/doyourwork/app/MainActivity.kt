package com.doyourwork.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
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
import com.doyourwork.app.ui.AppRoot
import com.doyourwork.app.ui.DoYourWorkTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** FragmentActivity because the biometric prompt needs one. */
class MainActivity : FragmentActivity() {
    private val vm: AppViewModel by viewModels()
    private var fold by mutableStateOf<FoldingFeature?>(null)
    // Whatever the answer, the reminders are set; Android just won't show them without a yes.
    private val askToNotify = registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

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

        // The two daily reminders: set again on every open (a new install or a restart clears
        // them), and once the family is set up, asked about once.
        ReminderReceiver.schedule(this)
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                vm.store.family.collect { if (it.isSetUp) askToNotifyOnce() }
            }
        }

        setContent { DoYourWorkTheme { AppRoot(vm, fold) } }
    }

    private fun askToNotifyOnce() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        val prefs = getSharedPreferences("reminders", MODE_PRIVATE)
        if (prefs.getBoolean("asked", false)) return
        prefs.edit().putBoolean("asked", true).apply()
        askToNotify.launch(Manifest.permission.POST_NOTIFICATIONS)
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
            runCatching { vm.restore(com.doyourwork.app.engine.Backup.decode(java.io.File(getExternalFilesDir(null), name).readText())) }
                .onFailure { android.util.Log.w("DOYOURWORK", "restoreFile $name: $it") }
        }
    }
}
