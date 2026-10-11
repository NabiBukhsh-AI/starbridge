package dev.starbridge.app

import android.content.ClipboardManager
import android.content.Context
import android.widget.Magnifier
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.click
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeRight
import androidx.compose.ui.test.withKeyDown
import androidx.test.core.app.ApplicationProvider
import dev.starbridge.app.ui.inbox.DecisionActions
import dev.starbridge.app.ui.inbox.InboxScreen
import dev.starbridge.app.ui.theme.StarbridgeTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import java.time.Instant

/**
 * A card's question can be selected and copied (#1143): a long press selects it without opening
 * the sheet, while a tap still opens it, an option still answers and a swipe still snoozes.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36], qualifiers = "w412dp-h892dp-xxhdpi", shadows = [NoMagnifier::class])
class SelectableTextTest {
    @get:Rule val compose = createComposeRule()
    private val now = Instant.parse("2026-10-04T14:00:00Z")
    private val d = Fake(now).decisions.first()
    private val opened = mutableListOf<String>()
    private val answered = mutableListOf<String?>()
    private val snoozed = mutableListOf<String>()

    private fun inbox() = compose.setContent {
        StarbridgeTheme {
            InboxScreen(
                listOf(d),
                now,
                DecisionActions(answer = { _, choice, _ -> answered += choice }, open = { opened += it }, snooze = { id, _ -> snoozed += id }, pick = {}),
            )
        }
    }

    @Test fun aLongPressSelectsTheQuestionWithoutOpeningIt() {
        inbox()
        compose.onNodeWithText(d.question, useUnmergedTree = true).performTouchInput { longClick() }
        compose.waitForIdle()
        assertEquals(emptyList<String>(), opened)
        // Ctrl+C copies the selected word.
        compose.onNodeWithText(d.question, useUnmergedTree = true).performKeyInput { withKeyDown(Key.CtrlLeft) { pressKey(Key.C) } }
        val clipboard = ApplicationProvider.getApplicationContext<Context>().getSystemService(ClipboardManager::class.java)
        val copied = clipboard.primaryClip?.getItemAt(0)?.text?.toString().orEmpty()
        assertTrue(copied, copied.isNotBlank() && d.question.contains(copied))
    }

    @Test fun aTapOnTheQuestionStillOpensIt() {
        inbox()
        compose.onNodeWithText(d.question, useUnmergedTree = true).performTouchInput { click() }
        compose.waitForIdle()
        assertEquals(listOf(d.id), opened)
    }

    @Test fun anOptionStillAnswers() {
        inbox()
        compose.onNodeWithText(d.options.first()).performClick()
        compose.waitForIdle()
        assertEquals(listOf(d.options.first()), answered)
        assertEquals(emptyList<String>(), opened)
    }

    @Test fun aSwipeFromTheQuestionStillSnoozes() {
        inbox()
        compose.onNodeWithText(d.question, useUnmergedTree = true).performTouchInput { swipeRight(startX = left, endX = left + 300f * density) }
        compose.waitForIdle()
        assertEquals(listOf(d.id), snoozed)
        assertEquals(emptyList<String>(), opened)
    }
}

/** Robolectric's Magnifier has no surface and throws when a selection dismisses it. */
@Implements(Magnifier::class)
class NoMagnifier {
    @Implementation fun show(sourceCenterX: Float, sourceCenterY: Float) = Unit

    @Implementation fun show(sourceCenterX: Float, sourceCenterY: Float, magnifierCenterX: Float, magnifierCenterY: Float) = Unit

    @Implementation fun update() = Unit

    @Implementation fun dismiss() = Unit
}
