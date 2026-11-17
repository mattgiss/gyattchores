package com.gyattchores.app

import android.app.Application
import android.content.Intent
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasScrollToNodeAction
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureScreenRoboImage
import com.gyattchores.app.engine.AdminCode
import com.gyattchores.app.engine.BackupFile
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.Player
import com.gyattchores.app.model.Status
import kotlinx.serialization.json.Json
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ProxySelector
import java.net.SocketAddress
import java.net.URI
import java.time.LocalDate
import java.time.ZoneId

/**
 * Takes the Play Store listing's screenshots: the real app, drawn on this computer with no phone
 * or emulator, showing a made-up family (pat is the admin, code 2468; sockninja, dishwizard and
 * broomrider play). The pictures land in android/PlayStore/screenshots/, one folder per upload
 * slot; android/PlayStore/README.md says which goes where.
 *
 * It is only compiled and run when the build is given -PstoreScreenshots, so ordinary test runs
 * and release builds never see it or the libraries it needs. Use
 * android/PlayStore/take-screenshots.sh, which runs one device per run: drawn back to back in one
 * run, a picture can pick up the previous device's last screen.
 *
 * Public edition only. It restores the made-up family through the app's own debug "restoreFile"
 * switch, the same way an emulator preview does.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34])
class StoreScreenshotsTest {
    @get:Rule val rule = createEmptyComposeRule()
    private val app get() = ApplicationProvider.getApplicationContext<Application>()
    private val zone = ZoneId.systemDefault()
    private val today = LocalDate.now(zone)

    @Before fun setUp() {
        assumeTrue("only when asked for, with -PstoreScreenshots", System.getProperty("storeScreenshots") == "true")
        assumeTrue("the public edition only: the family edition syncs", !BuildConfig.FAMILY_SYNC)
        // Belt and braces: nothing here may reach the network.
        ProxySelector.setDefault(object : ProxySelector() {
            override fun select(uri: URI?) = listOf(Proxy(Proxy.Type.HTTP, InetSocketAddress("127.0.0.1", 9)))
            override fun connectFailed(uri: URI?, sa: SocketAddress?, ioe: IOException?) {}
        })
    }

    // Phone 1080 x 1920. Play wants the long side no more than twice the short one.
    @Test @Config(qualifiers = "w360dp-h640dp-port-xxhdpi") fun phone() = shootAll("phone", wide = false)

    // 7-inch tablet 1920 x 1200 and 10-inch tablet 2560 x 1600, both on their side for the two-pane layout.
    @Test @Config(qualifiers = "w960dp-h600dp-land-xhdpi") fun tablet7() = shootAll("tablet-7-inch", wide = true)
    @Test @Config(qualifiers = "w1280dp-h800dp-land-xhdpi") fun tablet10() = shootAll("tablet-10-inch", wide = true)

    private fun shootAll(folder: String, wide: Boolean) {
        fun shot(name: String) {
            rule.waitForIdle()
            val file = File("../PlayStore/screenshots/$folder/$name.png")
            captureScreenRoboImage(file.path)
            flatten(file)
        }

        // 2. A fresh install: what the app is and what it doesn't do with your data.
        launch(withFamily = false).use { shot("02-private-by-design") }

        launch(withFamily = true).use {
            // 1. The scoreboard. On a tablet, a day waiting on an admin fills the other half.
            if (wide) tap("dishwizard")
            shot("01-scoreboard")

            // 3. Picking today's chores, with a suggested card.
            tap("broomrider")
            tap("Suggest a 25-minute card")
            shot("03-pick-chores")

            // 4. The card, partly checked off.
            tap("Lock in my card")
            repeat(2) { i -> rule.onAllNodes(checkbox)[i].performClick(); rule.waitForIdle() }
            shot("04-todays-card")

            // 6. The admin area, with today's chores waiting for a yes or no.
            if (!wide) tap("Back")
            tap("Admin")
            rule.onAllNodes(hasSetTextAction()).onFirst().performTextInput("2468")
            tap("Unlock")
            shot("06-approvals")

            // 5. A household's own chores, said in a sentence and sorted into a list.
            rule.onAllNodes(hasScrollToNodeAction()).onFirst().performScrollToNode(hasText("Add chores"))
            tap("Add chores")
            rule.onAllNodes(hasSetTextAction()).onFirst()
                .performTextInput("Wash the car, walk the dog for 15 minutes, feed the fish and tidy the playroom. Clean out the fridge")
            tap("Sort into chores")
            check(rule.onAllNodes(hasText("Found 5.", substring = true)).fetchSemanticsNodes().isNotEmpty()) { "the sentence should sort into five chores" }
            shot("05-your-own-chores")
        }
    }

    /** Play turns away a PNG with a transparency channel, which these captures carry: write it again without one. */
    private fun flatten(file: File) {
        val bitmap = android.graphics.BitmapFactory.decodeFile(file.path)
        bitmap.setHasAlpha(false)
        file.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
    }

    private val checkbox = SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Checkbox)

    private fun tap(text: String) {
        rule.onAllNodes(hasClickAction() and hasText(text, substring = true)).onFirst().performClick()
        rule.waitForIdle()
    }

    private fun launch(withFamily: Boolean): ActivityScenario<MainActivity> {
        val intent = Intent(app, MainActivity::class.java)
        if (withFamily) {
            File(app.getExternalFilesDir(null), "store.json").writeText(Json.encodeToString(BackupFile.serializer(), family()))
            intent.putExtra("restoreFile", "store.json")
        }
        val scenario = ActivityScenario.launch<MainActivity>(intent)
        rule.waitForIdle()
        // A restore says what it brought in; that note isn't part of any picture.
        if (rule.onAllNodes(hasClickAction() and hasText("OK")).fetchSemanticsNodes().isNotEmpty()) tap("OK")
        return scenario
    }

    /** A made-up family with a month behind it: one steady player, one hit-and-miss, one who hasn't picked today. */
    private fun family(): BackupFile {
        val pool: List<Chore> = Json { ignoreUnknownKeys = true }.decodeFromString(app.assets.open("chores.json").bufferedReader().readText())
        val members = listOf(Player("1", "pat", isAdmin = true, plays = false), Player("2", "sockninja"), Player("3", "dishwizard"), Player("4", "broomrider"))
        val code = AdminCode.make("2468", salt = "STORE-SCREENSHOTS")!!
        // The chores went on the list yesterday, so the picker isn't a wall of overdue marks.
        val added = today.minusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
        val logs = ArrayList<BackupFile.Log>()
        for (daysAgo in 0L until 30L) {
            val morning = today.minusDays(daysAgo).atTime(7, 48).atZone(zone).toInstant().toEpochMilli()
            for ((index, player) in members.drop(1).withIndex()) {
                val dayOff = when (index) { 2 -> daysAgo == 0L || daysAgo % 7 == 5L; 0 -> daysAgo % 9 == 4L; else -> daysAgo % 3 == 1L }
                if (dayOff) continue
                val goal = if (index != 1 || daysAgo % 4 != 0L) 25 else 14 // the middle player has some short days
                var minutes = 0
                var slot = (daysAgo * 5 + index * 11).toInt()
                val used = HashSet<String>()
                while (minutes < goal && used.size < pool.size) {
                    val c = pool[slot % pool.size]; slot++
                    if (!used.add(c.id)) continue
                    val status = if (daysAgo == 0L && index == 1) Status.PENDING else Status.APPROVED
                    logs += BackupFile.Log("s-$daysAgo-$index-${c.id}", null, player.id, player.name, c.id, c.name, c.pts, c.tiers[0], status, morning - used.size * 1000L)
                    minutes += c.tiers[0]
                }
            }
        }
        return BackupFile(id = "store-screenshots", exportedAt = added, source = "android-public", appVersion = "1.0",
            members = members, adminCodes = listOf(BackupFile.Code("1", code.salt, code.hash)), chores = pool,
            choreAdded = pool.associate { it.id to added }, memberJoined = members.associate { it.id to added }, nextPlayerId = 5, logs = logs)
    }
}
