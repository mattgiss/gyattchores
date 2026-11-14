package com.gyattchores.app

import androidx.compose.ui.unit.dp
import com.gyattchores.app.ui.listPaneWidth
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** How the screen is split between the list and what's open beside it. */
class LayoutTest {
    // The Z Fold 7's inner screen is about 750dp by 832dp.

    @Test fun foldTurnedSidewaysGivesTheListAProperShare() {
        // The hinge runs across, so there's nothing to split at. This used to come out at 246dp
        // (0.42 against 1, not 0.42 of the width), which broke the title over two lines.
        val list = listPaneWidth(832.dp, hingeLeft = null)
        assertEquals(349.44f, list.value, 0.01f)
        assertTrue("the list needs room for a full-size title", list >= 300.dp)
        assertTrue("and so does what opens beside it", 832.dp - list >= 300.dp)
    }

    @Test fun foldHeldUprightSplitsAtTheHinge() {
        assertEquals(375.dp, listPaneWidth(750.dp, hingeLeft = 375.dp))
    }

    @Test fun aHingeTooNearAnEdgeIsIgnored() {
        // A dual-screen or oddly reported hinge mustn't leave either pane a sliver.
        assertEquals(listPaneWidth(832.dp, null), listPaneWidth(832.dp, hingeLeft = 120.dp))
        assertEquals(listPaneWidth(832.dp, null), listPaneWidth(832.dp, hingeLeft = 700.dp))
    }

    @Test fun theListNeverGetsTooNarrowOrTooWide() {
        assertEquals(300.dp, listPaneWidth(600.dp, null))    // the narrowest window that shows two panes
        assertEquals(420.dp, listPaneWidth(1280.dp, null))   // a tablet: the open screen gets the rest
        assertEquals(420.dp, listPaneWidth(2000.dp, null))
    }
}
