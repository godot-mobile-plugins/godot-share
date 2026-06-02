//
// © 2024-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.share;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

import androidx.core.content.FileProvider;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.plugin.share.model.SharedData;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;

import java.io.File;
import java.lang.reflect.Field;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link SharePlugin}.
 *
 * <h3>Android framework stubs</h3>
 * The Gradle build sets {@code isReturnDefaultValues = true}, so every un-mocked Android SDK
 * call returns 0 / false / null instead of throwing. Classes outside the Android SDK (Godot
 * library) are handled with Mockito mocks.
 *
 * <h3>Signal verification strategy</h3>
 * {@code GodotPlugin.emitSignal} is a static method. Each test that needs to observe signal
 * emissions wraps the code under test in a {@code try (MockedStatic<GodotPlugin> gdp = …)}
 * block and then calls {@code gdp.verify(…)} or {@code gdp.verifyNoMoreInteractions()}.
 * The private {@code SignalInfo} constants are accessed via reflection once in
 * {@link #setUp()} and reused throughout, giving exact reference-equality matches.
 *
 * <h3>Private-field injection</h3>
 * Several tests must place the plugin into a specific mid-flight state (e.g. an active share)
 * without triggering the full {@link SharePlugin#share} flow. The helpers
 * {@link #setField(String, Object)} and {@link #getField(String)} set/read private fields via
 * reflection so tests remain white-box without modifying production code.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("SharePlugin")
class SharePluginTest {

	// =========================================================================
	// Test-level infrastructure
	// =========================================================================

	@Mock
	private Godot mockGodot;

	private SharePlugin plugin;

	// Reflected private-static SignalInfo instances — same objects the plugin uses,
	// enabling eq() reference matching rather than fragile name-string comparisons.
	private SignalInfo signalCompleted;
	private SignalInfo signalCanceled;
	private SignalInfo signalFailed;

	@BeforeEach
	void setUp() throws Exception {
		plugin = new SharePlugin(mockGodot);
		signalCompleted = getStaticField("SHARE_COMPLETED_SIGNAL");
		signalCanceled  = getStaticField("SHARE_CANCELED_SIGNAL");
		signalFailed    = getStaticField("SHARE_FAILED_SIGNAL");
	}

	// =========================================================================
	// share() — plugin not yet initialised (null Activity)
	// =========================================================================

	@Nested
	@DisplayName("share() — null Activity")
	class ShareNullActivity {

		@Test
		@DisplayName("emits share_failed when onMainCreate() has not been called yet")
		void emitsShareFailed() {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.share(SharePluginFixtures.textShareDictionary());

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalFailed), any()));
			}
		}

		@Test
		@DisplayName("share_failed message mentions the uninitialized Activity")
		void failedMessageMentionsActivity() {
			ArgumentCaptor<String> msgCaptor = ArgumentCaptor.forClass(String.class);

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.share(SharePluginFixtures.textShareDictionary());

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalFailed), msgCaptor.capture()));
			}

			String message = msgCaptor.getValue();
			assertContains(message, "Activity is null",
					"Error message should mention a null Activity");
		}

		@Test
		@DisplayName("no other signals are emitted — exactly one emitSignal call total")
		void noOtherSignalsEmitted() {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.share(SharePluginFixtures.textShareDictionary());

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalFailed), any()));
				gdp.verifyNoMoreInteractions();
			}
		}
	}

	// =========================================================================
	// share() — requested file does not exist on disk
	// =========================================================================

	@Nested
	@DisplayName("share() — non-existent file path")
	class ShareNonExistentFile {

		@BeforeEach
		void injectActivity() throws Exception {
			injectMockActivity(SharePluginFixtures.PACKAGE_NAME);
		}

		@Test
		@DisplayName("emits share_failed when the file is not found on disk")
		void emitsShareFailed() {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.share(SharePluginFixtures.fileShareDictionary(
						"/no/such/file.png", "image/png"));

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalFailed), any()));
			}
		}

		@Test
		@DisplayName("share_failed message contains the missing file path")
		void failedMessageContainsMissingPath() {
			String badPath = "/totally/missing/asset.png";
			ArgumentCaptor<String> msgCaptor = ArgumentCaptor.forClass(String.class);

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.share(SharePluginFixtures.fileShareDictionary(badPath, "image/png"));

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalFailed), msgCaptor.capture()));
			}

			assertContains(msgCaptor.getValue(), badPath,
					"Error message should echo the path that was not found");
		}

		@Test
		@DisplayName("no completed or canceled signal is emitted for a missing file")
		void noOtherSignalsEmitted() {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.share(SharePluginFixtures.fileShareDictionary(
						"/ghost/file.png", "image/png"));

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalFailed), any()));
				gdp.verifyNoMoreInteractions();
			}
		}
	}

	// =========================================================================
	// share() — FileProvider rejects the file (path not in provider paths)
	// =========================================================================

	@Nested
	@DisplayName("share() — FileProvider rejects file")
	class ShareFileProviderRejects {

		@Test
		@DisplayName("emits share_failed when FileProvider.getUriForFile() throws IllegalArgumentException")
		void emitsShareFailed() throws Exception {
			File tmpFile = SharePluginFixtures.createTempFile("share_test", ".png");
			injectMockActivity(SharePluginFixtures.PACKAGE_NAME);

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class);
					MockedStatic<FileProvider> fpMock = mockStatic(FileProvider.class)) {

				fpMock.when(() -> FileProvider.getUriForFile(any(), anyString(), any(File.class)))
						.thenThrow(new IllegalArgumentException("file not in configured paths"));

				plugin.share(SharePluginFixtures.fileShareDictionary(
						tmpFile.getAbsolutePath(), "image/png"));

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalFailed), any()));
			}
		}

		@Test
		@DisplayName("share_failed message mentions the problematic file path")
		void failedMessageContainsPath() throws Exception {
			File tmpFile = SharePluginFixtures.createTempFile("share_fp_test", ".png");
			injectMockActivity(SharePluginFixtures.PACKAGE_NAME);
			ArgumentCaptor<String> msgCaptor = ArgumentCaptor.forClass(String.class);

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class);
					MockedStatic<FileProvider> fpMock = mockStatic(FileProvider.class)) {

				fpMock.when(() -> FileProvider.getUriForFile(any(), anyString(), any(File.class)))
						.thenThrow(new IllegalArgumentException("not in paths"));

				plugin.share(SharePluginFixtures.fileShareDictionary(
						tmpFile.getAbsolutePath(), "image/png"));

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalFailed), msgCaptor.capture()));
			}

			assertContains(msgCaptor.getValue(), tmpFile.getAbsolutePath(),
					"Error message should include the file path that was rejected");
		}
	}

	// =========================================================================
	// onMainResume() — no share in progress
	// =========================================================================

	@Nested
	@DisplayName("onMainResume() — no share in progress")
	class ResumeNoShareInProgress {

		@Test
		@DisplayName("emits no signals when sharedDataInProgress is null")
		void emitsNoSignals() {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();

				gdp.verifyNoMoreInteractions();
			}
		}
	}

	// =========================================================================
	// onMainResume() — long duration  →  share_completed
	// =========================================================================

	@Nested
	@DisplayName("onMainResume() — long duration (share completed)")
	class ResumeLongDuration {

		/**
		 * Sets up a share that started {@code threshold + 1 000 ms} ago so that
		 * {@code System.currentTimeMillis() - shareStartTime > threshold}.
		 */
		@BeforeEach
		void injectLongRunningShare() throws Exception {
			long threshold = SharePluginFixtures.DEFAULT_THRESHOLD_MS;
			SharedData data = SharePluginFixtures.textSharedData(); // threshold = DEFAULT_THRESHOLD_MS
			injectShareInProgress(data, System.currentTimeMillis() - (threshold + 1_000L));
		}

		@Test
		@DisplayName("emits share_completed with 'UnknownActivity' after a duration longer than the threshold")
		void emitsShareCompleted() {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(),
						eq("SharePlugin"),
						eq(signalCompleted),
						eq("UnknownActivity")));
			}
		}

		@Test
		@DisplayName("does not emit share_canceled after a long duration")
		void doesNotEmitShareCanceled() {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalCompleted), any()));
				gdp.verifyNoMoreInteractions();
			}
		}

		@Test
		@DisplayName("clears sharedDataInProgress after emitting share_completed")
		void clearsSharedDataInProgress() throws Exception {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();
			}

			assertNull(getField("sharedDataInProgress"),
					"sharedDataInProgress must be null after onMainResume()");
		}

		@Test
		@DisplayName("resets shareStartTime to 0 after emitting share_completed")
		void resetsShareStartTime() throws Exception {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();
			}

			assertEquals(0L, (long) getField("shareStartTime"),
					"shareStartTime must be reset to 0 after onMainResume()");
		}
	}

	// =========================================================================
	// onMainResume() — short duration  →  share_canceled
	// =========================================================================

	@Nested
	@DisplayName("onMainResume() — short duration (chooser dismissed)")
	class ResumeShortDuration {

		/**
		 * Sets shareStartTime to "now" so that elapsed time ≈ 0 ms, which is less than the
		 * default 5 000 ms threshold and therefore treated as a chooser dismissal.
		 */
		@BeforeEach
		void injectQuickDismissal() throws Exception {
			injectShareInProgress(SharePluginFixtures.textSharedData(),
					System.currentTimeMillis());
		}

		@Test
		@DisplayName("emits share_canceled when the chooser is dismissed below the threshold")
		void emitsShareCanceled() {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(),
						eq("SharePlugin"),
						eq(signalCanceled)));
			}
		}

		@Test
		@DisplayName("does not emit share_completed after a quick dismissal")
		void doesNotEmitShareCompleted() {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalCanceled)));
				gdp.verifyNoMoreInteractions();
			}
		}

		@Test
		@DisplayName("clears sharedDataInProgress after emitting share_canceled")
		void clearsSharedDataInProgress() throws Exception {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();
			}

			assertNull(getField("sharedDataInProgress"),
					"sharedDataInProgress must be null after onMainResume()");
		}

		@Test
		@DisplayName("resets shareStartTime to 0 after emitting share_canceled")
		void resetsShareStartTime() throws Exception {
			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();
			}

			assertEquals(0L, (long) getField("shareStartTime"),
					"shareStartTime must be reset to 0 after onMainResume()");
		}

		@Test
		@DisplayName("boundary: threshold exactly at custom value — zero elapsed time is canceled")
		void zeroElapsedTimeIsCanceled() throws Exception {
			// Custom threshold of 1 ms — elapsed time of 0 ms is still below it
			SharedData fastData = SharePluginFixtures.sharedDataWithThreshold(1L);
			injectShareInProgress(fastData, System.currentTimeMillis());

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				plugin.onMainResume();

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(), any(), eq(signalCanceled)));
			}
		}
	}

	// =========================================================================
	// onMainDestroy()
	// =========================================================================

	@Nested
	@DisplayName("onMainDestroy()")
	class Destroy {

		@Test
		@DisplayName("does not throw when no in-flight share state exists")
		void doesNotThrowWhenClean() {
			assertDoesNotThrow(() -> plugin.onMainDestroy(),
					"onMainDestroy() must never throw, even with a clean state");
		}

		@Test
		@DisplayName("clears sharedDataInProgress on destroy")
		void clearsSharedDataInProgress() throws Exception {
			injectShareInProgress(SharePluginFixtures.textSharedData(), 0L);

			plugin.onMainDestroy();

			assertNull(getField("sharedDataInProgress"),
					"sharedDataInProgress must be null after onMainDestroy()");
		}

		@Test
		@DisplayName("resets shareStartTime to 0 on destroy")
		void resetsShareStartTime() throws Exception {
			injectShareInProgress(SharePluginFixtures.textSharedData(),
					System.currentTimeMillis());

			plugin.onMainDestroy();

			assertEquals(0L, (long) getField("shareStartTime"),
					"shareStartTime must be reset to 0 after onMainDestroy()");
		}

		@Test
		@DisplayName("does not throw when called a second time (idempotent cleanup)")
		void idempotentCleanup() {
			assertDoesNotThrow(() -> {
				plugin.onMainDestroy();
				plugin.onMainDestroy();
			}, "Calling onMainDestroy() twice must not throw");
		}
	}

	// =========================================================================
	// Chooser BroadcastReceiver
	// =========================================================================

	@Nested
	@DisplayName("chooser BroadcastReceiver")
	class ChooserReceiver {

		private Activity mockActivity;

		@BeforeEach
		void setUpActivity() throws Exception {
			mockActivity = buildMockActivity(SharePluginFixtures.PACKAGE_NAME);
			injectActivity(mockActivity);
		}

		@Test
		@DisplayName("emits share_completed with the flattened component name when a target is chosen")
		void emitsShareCompletedWithChosenComponent() throws Exception {
			ComponentName component = mock(ComponentName.class);
			when(component.flattenToShortString()).thenReturn("com.example/.ShareActivity");

			BroadcastReceiver receiver = runShareAndCaptureReceiver();

			Intent broadcastIntent = broadcastIntentWithComponent(component);

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				receiver.onReceive(mock(Context.class), broadcastIntent);

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(),
						eq("SharePlugin"),
						eq(signalCompleted),
						eq("com.example/.ShareActivity")));
			}
		}

		@Test
		@DisplayName("emits share_completed with 'UnknownActivity' when chosen component is null")
		void emitsShareCompletedWithUnknownActivityWhenComponentNull() throws Exception {
			BroadcastReceiver receiver = runShareAndCaptureReceiver();

			Intent broadcastIntent = broadcastIntentWithComponent(null);

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				receiver.onReceive(mock(Context.class), broadcastIntent);

				gdp.verify(() -> GodotPlugin.emitSignal(
						any(),
						eq("SharePlugin"),
						eq(signalCompleted),
						eq("UnknownActivity")));
			}
		}

		@Test
		@DisplayName("only the first onReceive() call emits a signal — the handled flag prevents re-entry")
		void onlyFirstBroadcastIsProcessed() throws Exception {
			BroadcastReceiver receiver = runShareAndCaptureReceiver();

			Intent broadcastIntent = broadcastIntentWithComponent(null);

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				receiver.onReceive(mock(Context.class), broadcastIntent);
				receiver.onReceive(mock(Context.class), broadcastIntent); // duplicate — must be ignored

				gdp.verify(() -> GodotPlugin.emitSignal(
								any(), any(), eq(signalCompleted), any()),
						times(1));
			}
		}

		@Test
		@DisplayName("receiver clears sharedDataInProgress after processing the broadcast")
		void clearsSharedDataInProgressAfterBroadcast() throws Exception {
			BroadcastReceiver receiver = runShareAndCaptureReceiver();

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				receiver.onReceive(mock(Context.class), broadcastIntentWithComponent(null));
			}

			assertNull(getField("sharedDataInProgress"),
					"sharedDataInProgress must be null after the receiver fires");
		}

		@Test
		@DisplayName("receiver resets shareStartTime to 0 after processing the broadcast")
		void resetsShareStartTimeAfterBroadcast() throws Exception {
			BroadcastReceiver receiver = runShareAndCaptureReceiver();

			try (MockedStatic<GodotPlugin> gdp = mockStatic(GodotPlugin.class)) {
				receiver.onReceive(mock(Context.class), broadcastIntentWithComponent(null));
			}

			assertEquals(0L, (long) getField("shareStartTime"),
					"shareStartTime must be reset to 0 after the receiver fires");
		}

		// ----- Nested-class helpers ------------------------------------------

		/**
		 * Drives a successful text-only {@link SharePlugin#share} call with all required
		 * Android statics mocked, then captures and returns the {@link BroadcastReceiver}
		 * that the plugin registered with the Activity.
		 *
		 * <p>The static mocks are scoped only to this method's try-with-resources block.
		 * The returned receiver can be invoked freely in the calling test's own mock scope.</p>
		 */
		private BroadcastReceiver runShareAndCaptureReceiver() throws Exception {
			PendingIntent mockPI    = mock(PendingIntent.class);
			Intent        mockChooser = mock(Intent.class);

			ArgumentCaptor<BroadcastReceiver> receiverCaptor =
					ArgumentCaptor.forClass(BroadcastReceiver.class);

			try (MockedStatic<GodotPlugin>   gdp        = mockStatic(GodotPlugin.class);
					MockedStatic<PendingIntent> piMock     = mockStatic(PendingIntent.class);
					MockedStatic<Intent>        intentMock = mockStatic(Intent.class)) {

				piMock.when(() ->
						PendingIntent.getBroadcast(any(), anyInt(), any(Intent.class), anyInt()))
						.thenReturn(mockPI);

				intentMock.when(() ->
						Intent.createChooser(any(Intent.class), anyString()))
						.thenReturn(mockChooser);

				plugin.share(SharePluginFixtures.textShareDictionary());
			}

			// Verify on the instance mock — unaffected by the closed static mocks above.
			// Build.VERSION.SDK_INT == 0 at test time, so the 2-arg registerReceiver() path runs.
			verify(mockActivity).registerReceiver(
					receiverCaptor.capture(), any(IntentFilter.class));

			return receiverCaptor.getValue();
		}

		/**
		 * Returns a mock {@link Intent} whose deprecated {@code getParcelableExtra(String)}
		 * is stubbed to return the given {@link ComponentName} (may be {@code null}).
		 *
		 * <p>The deprecated variant is used because {@code Build.VERSION.SDK_INT == 0} at test
		 * time, which is below {@code Build.VERSION_CODES.TIRAMISU (33)}, so the plugin takes
		 * the pre-API-33 code path.</p>
		 */
		@SuppressWarnings("deprecation")
		private Intent broadcastIntentWithComponent(ComponentName component) {
			Intent intent = mock(Intent.class);
			when(intent.getParcelableExtra(Intent.EXTRA_CHOSEN_COMPONENT))
					.thenReturn(component);
			return intent;
		}
	}

	// =========================================================================
	// Private helpers
	// =========================================================================

	/**
	 * Creates a Mockito {@link Activity} mock with {@code getPackageName()} stubbed to return
	 * the supplied package name.
	 */
	private static Activity buildMockActivity(String packageName) {
		Activity activity = mock(Activity.class);
		when(activity.getPackageName()).thenReturn(packageName);
		return activity;
	}

	/**
	 * Injects a mocked {@link Activity} into the plugin's private {@code activity} field and
	 * derives the authority string used by the {@link FileProvider}.
	 */
	private void injectMockActivity(String packageName) throws Exception {
		injectActivity(buildMockActivity(packageName));
	}

	/**
	 * Injects an already-constructed Activity mock into the plugin and sets the derived
	 * {@code authority} field.
	 */
	private void injectActivity(Activity activity) throws Exception {
		setField("activity", activity);
		setField("authority", activity.getPackageName() + ".sharefileprovider");
	}

	/**
	 * Puts the plugin into the state it would be in during an in-progress share:
	 * {@code sharedDataInProgress} is set to the given {@link SharedData} and
	 * {@code shareStartTime} is set to the given epoch-millisecond timestamp.
	 */
	private void injectShareInProgress(SharedData sharedData, long startTimeMs)
			throws Exception {
		setField("sharedDataInProgress", sharedData);
		setField("shareStartTime", startTimeMs);
	}

	// ----- Reflection utilities -----------------------------------------------

	/** Reads a private instance field from {@link #plugin}. */
	@SuppressWarnings("unchecked")
	private <T> T getField(String name) throws Exception {
		Field field = SharePlugin.class.getDeclaredField(name);
		field.setAccessible(true);
		return (T) field.get(plugin);
	}

	/** Writes a private instance field on {@link #plugin}. */
	private void setField(String name, Object value) throws Exception {
		Field field = SharePlugin.class.getDeclaredField(name);
		field.setAccessible(true);
		field.set(plugin, value);
	}

	/** Reads a private *static* field declared on {@link SharePlugin}. */
	@SuppressWarnings("unchecked")
	private static <T> T getStaticField(String name) throws Exception {
		Field field = SharePlugin.class.getDeclaredField(name);
		field.setAccessible(true);
		return (T) field.get(null);
	}

	// ----- Assertion utilities ------------------------------------------------

	/**
	 * Asserts that {@code actual} contains the {@code expectedSubstring}, using
	 * {@code message} as the assertion label.
	 */
	private static void assertContains(String actual, String expectedSubstring, String message) {
		if (actual == null || !actual.contains(expectedSubstring)) {
			throw new AssertionError(
					message + " — expected [" + actual + "] to contain [" + expectedSubstring + "]");
		}
	}
}
