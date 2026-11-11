package com.gyattchores.app

import android.os.Bundle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.material3.windowsizeclass.ExperimentalMaterial3WindowSizeClassApi
import androidx.compose.material3.windowsizeclass.WindowWidthSizeClass
import androidx.compose.material3.windowsizeclass.calculateWindowSizeClass
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import com.gyattchores.app.ui.AdminScreen
import com.gyattchores.app.ui.GyattTheme
import com.gyattchores.app.ui.Hinge
import com.gyattchores.app.ui.HomeScreen
import com.gyattchores.app.ui.PlayerScreen
import kotlinx.coroutines.launch

/** FragmentActivity because the biometric prompt needs one. */
class MainActivity : FragmentActivity() {
    private val vm: AppViewModel by viewModels()
    private var fold by mutableStateOf<FoldingFeature?>(null)

    @OptIn(ExperimentalMaterial3WindowSizeClassApi::class)
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

        setContent {
            GyattTheme {
                val logs by vm.store.logs.collectAsState()
                val players by vm.store.players.collectAsState()
                val cards by vm.store.cards.collectAsState()
                // Saved state, so fold/unfold and process death land on the same screen.
                var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
                var adminOpen by rememberSaveable { mutableStateOf(false) }
                val selected = players.firstOrNull { it.id == selectedId }

                // The Z Fold 7's inner screen is ~750dp wide, which is "Medium", so two panes start there.
                val twoPane = calculateWindowSizeClass(this).widthSizeClass != WindowWidthSizeClass.Compact
                val f = fold
                // Tabletop: half-open with a horizontal hinge. Content above it, controls below.
                val hinge = if (f != null && f.state == FoldingFeature.State.HALF_OPENED && f.orientation == FoldingFeature.Orientation.HORIZONTAL)
                    Hinge(f.bounds.top, f.bounds.bottom) else null
                // Book posture or a flat inner screen: split the panes at the vertical hinge.
                val hingeX = if (f != null && f.orientation == FoldingFeature.Orientation.VERTICAL) f.bounds.left else null

                BackHandler(enabled = adminOpen || selected != null) {
                    if (adminOpen) adminOpen = false else selectedId = null
                }

                Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    val now = vm.now()
                    val home = @androidx.compose.runtime.Composable { m: Modifier ->
                        HomeScreen(players, logs, vm.store.poolById, now, vm.zone, selectedId.takeIf { twoPane && !adminOpen },
                            onPick = { adminOpen = false; selectedId = it.id }, onAdmin = { adminOpen = true }, modifier = m)
                    }
                    if (twoPane) {
                        Row(Modifier.fillMaxSize().safeDrawingPadding()) {
                            val listMod = if (hingeX != null) Modifier.width(with(androidx.compose.ui.platform.LocalDensity.current) { hingeX.toDp() }) else Modifier.weight(0.42f)
                            Box(listMod.fillMaxHeight()) { home(Modifier) }
                            VerticalDivider()
                            Box(Modifier.weight(1f).fillMaxHeight()) {
                                when {
                                    adminOpen -> AdminScreen(vm, logs, players, onBack = { adminOpen = false })
                                    selected != null -> PlayerScreen(vm, selected, logs, cards, hinge, onBack = null)
                                    else -> Text("> pick a player", color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.align(Alignment.Center).width(200.dp))
                                }
                            }
                        }
                    } else {
                        Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                            when {
                                adminOpen -> AdminScreen(vm, logs, players, onBack = { adminOpen = false })
                                selected != null -> PlayerScreen(vm, selected, logs, cards, hinge, onBack = { selectedId = null })
                                else -> home(Modifier)
                            }
                        }
                    }
                }
            }
        }
    }
}
