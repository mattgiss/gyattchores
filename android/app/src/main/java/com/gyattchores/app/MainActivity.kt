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
        enableEdgeToEdge()

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
}
