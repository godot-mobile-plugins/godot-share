//
// © 2024-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.share.model;

import org.godotengine.godot.Dictionary;
import org.godotengine.plugin.share.SharePluginFixtures;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Unit tests for {@link SharedData}.
 *
 * <p>Each nested class targets a single getter so that a breakage surfaces under a
 * recognisable heading in the test report. Tests use Mockito-mocked {@link Dictionary}
 * instances rather than real ones so that behaviour never depends on Godot SDK internals.</p>
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("SharedData")
class SharedDataTest {

	// =========================================================================
	// getTitle()
	// =========================================================================

	@Nested
	@DisplayName("getTitle()")
	class GetTitle {

		@Test
		@DisplayName("returns the String stored under the 'title' key")
		void returnsStoredTitle() {
			Dictionary dict = mock(Dictionary.class);
			when(dict.get("title")).thenReturn("My Title");

			assertEquals("My Title", new SharedData(dict).getTitle());
		}

		@Test
		@DisplayName("returns null when the 'title' key is absent")
		void returnsNullWhenAbsent() {
			assertNull(new SharedData(SharePluginFixtures.emptyDictionary()).getTitle());
		}
	}

	// =========================================================================
	// getSubject()
	// =========================================================================

	@Nested
	@DisplayName("getSubject()")
	class GetSubject {

		@Test
		@DisplayName("returns the String stored under the 'subject' key")
		void returnsStoredSubject() {
			Dictionary dict = mock(Dictionary.class);
			when(dict.get("subject")).thenReturn("Email subject line");

			assertEquals("Email subject line", new SharedData(dict).getSubject());
		}

		@Test
		@DisplayName("returns null when the 'subject' key is absent")
		void returnsNullWhenAbsent() {
			assertNull(new SharedData(SharePluginFixtures.emptyDictionary()).getSubject());
		}
	}

	// =========================================================================
	// getContent()
	// =========================================================================

	@Nested
	@DisplayName("getContent()")
	class GetContent {

		@Test
		@DisplayName("returns the String stored under the 'content' key")
		void returnsStoredContent() {
			Dictionary dict = mock(Dictionary.class);
			when(dict.get("content")).thenReturn("Body text to share");

			assertEquals("Body text to share", new SharedData(dict).getContent());
		}

		@Test
		@DisplayName("returns null when the 'content' key is absent")
		void returnsNullWhenAbsent() {
			assertNull(new SharedData(SharePluginFixtures.emptyDictionary()).getContent());
		}
	}

	// =========================================================================
	// getFilePath()
	// =========================================================================

	@Nested
	@DisplayName("getFilePath()")
	class GetFilePath {

		@Test
		@DisplayName("returns the String stored under the 'file_path' key")
		void returnsStoredFilePath() {
			Dictionary dict = mock(Dictionary.class);
			when(dict.get("file_path")).thenReturn("/sdcard/screenshot.png");

			assertEquals("/sdcard/screenshot.png", new SharedData(dict).getFilePath());
		}

		@Test
		@DisplayName("returns null when the 'file_path' key is absent")
		void returnsNullWhenAbsent() {
			assertNull(new SharedData(SharePluginFixtures.emptyDictionary()).getFilePath());
		}
	}

	// =========================================================================
	// getMimeType()
	// =========================================================================

	@Nested
	@DisplayName("getMimeType()")
	class GetMimeType {

		@Test
		@DisplayName("returns the String stored under the 'mime_type' key")
		void returnsStoredMimeType() {
			Dictionary dict = mock(Dictionary.class);
			when(dict.get("mime_type")).thenReturn("image/jpeg");

			assertEquals("image/jpeg", new SharedData(dict).getMimeType());
		}

		@Test
		@DisplayName("returns null when the 'mime_type' key is absent")
		void returnsNullWhenAbsent() {
			assertNull(new SharedData(SharePluginFixtures.emptyDictionary()).getMimeType());
		}
	}

	// =========================================================================
	// getThreshold()
	// =========================================================================

	@Nested
	@DisplayName("getThreshold()")
	class GetThreshold {

		@Test
		@DisplayName("returns exactly 5 000 ms when 'custom_threshold' is absent")
		void returnsDefaultThreshold() {
			SharedData data = new SharedData(SharePluginFixtures.emptyDictionary());

			assertEquals(5_000L, data.getThreshold(),
					"Hard-coded default must be 5 000 ms");
		}

		@Test
		@DisplayName("default threshold is strictly positive")
		void defaultThresholdIsPositive() {
			SharedData data = new SharedData(SharePluginFixtures.emptyDictionary());

			assertTrue(data.getThreshold() > 0,
					"Default resumption threshold must be > 0 ms");
		}

		@Test
		@DisplayName("returns the custom value when 'custom_threshold' is present")
		void returnsCustomThreshold() {
			SharedData data = SharePluginFixtures.sharedDataWithThreshold(10_000L);

			assertEquals(10_000L, data.getThreshold());
		}

		@Test
		@DisplayName("returns zero when 'custom_threshold' is explicitly set to 0")
		void returnsZeroCustomThreshold() {
			// Zero is a valid override — it makes every resume look like a completed share.
			SharedData data = SharePluginFixtures.sharedDataWithThreshold(0L);

			assertEquals(0L, data.getThreshold());
		}

		@Test
		@DisplayName("returns a large custom value without overflow or truncation")
		void returnsLargeCustomThreshold() {
			long huge = Long.MAX_VALUE / 2;
			SharedData data = SharePluginFixtures.sharedDataWithThreshold(huge);

			assertEquals(huge, data.getThreshold());
		}

		@Test
		@DisplayName("custom threshold of 1 ms is honoured (minimum meaningful override)")
		void returnsMinimalCustomThreshold() {
			SharedData data = SharePluginFixtures.sharedDataWithThreshold(1L);

			assertEquals(1L, data.getThreshold());
		}
	}

	// =========================================================================
	// All fields together
	// =========================================================================

	@Nested
	@DisplayName("fully-populated dictionary")
	class FullyPopulated {

		@Test
		@DisplayName("all getters return their expected values from a fully-populated dictionary")
		void allGettersReturnCorrectValues() {
			Dictionary dict = SharePluginFixtures.fullShareDictionary("/sdcard/photo.png");
			SharedData data = new SharedData(dict);

			assertAll(
					() -> assertEquals(SharePluginFixtures.SHARE_TITLE,
							data.getTitle(), "title"),
					() -> assertEquals(SharePluginFixtures.SHARE_SUBJECT,
							data.getSubject(), "subject"),
					() -> assertEquals(SharePluginFixtures.SHARE_CONTENT,
							data.getContent(), "content"),
					() -> assertEquals("/sdcard/photo.png",
							data.getFilePath(), "file_path"),
					() -> assertEquals(SharePluginFixtures.MIME_TYPE_IMAGE,
							data.getMimeType(), "mime_type"),
					() -> assertEquals(SharePluginFixtures.CUSTOM_THRESHOLD_MS,
							data.getThreshold(), "custom_threshold")
			);
		}

		@Test
		@DisplayName("getters are independent — querying one does not affect another")
		void gettersAreIndependent() {
			Dictionary dict = SharePluginFixtures.fullShareDictionary("/sdcard/clip.mp4");
			SharedData data = new SharedData(dict);

			// Call in a different order than the fields are declared
			String mime = data.getMimeType();
			long threshold = data.getThreshold();
			String path = data.getFilePath();
			String content = data.getContent();
			String subject = data.getSubject();
			String title = data.getTitle();

			assertAll(
					() -> assertEquals(SharePluginFixtures.SHARE_TITLE, title),
					() -> assertEquals(SharePluginFixtures.SHARE_SUBJECT, subject),
					() -> assertEquals(SharePluginFixtures.SHARE_CONTENT, content),
					() -> assertEquals("/sdcard/clip.mp4", path),
					() -> assertEquals(SharePluginFixtures.MIME_TYPE_IMAGE, mime),
					() -> assertEquals(SharePluginFixtures.CUSTOM_THRESHOLD_MS, threshold)
			);
		}
	}
}
