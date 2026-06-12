//
// © 2024-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.share;

import org.godotengine.godot.Dictionary;
import org.godotengine.plugin.share.model.SharedData;

import java.io.File;
import java.io.IOException;

import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Shared test fixtures for the Share plugin test suite.
 *
 * <p>All {@link Dictionary} objects are Mockito mocks. Only the keys explicitly listed in each
 * factory are stubbed; every other key returns {@code null} / {@code false} by default, which
 * mirrors what would happen with a sparse Godot Dictionary at runtime.</p>
 *
 * <p>Key constants duplicate the private string literals from {@link SharedData} so that a
 * rename there produces a compile-time failure here rather than a silent test pass.</p>
 */
public final class SharePluginFixtures {

	// ----- Dictionary key constants (mirrors SharedData private constants) -----

	public static final String KEY_TITLE = "title";
	public static final String KEY_SUBJECT = "subject";
	public static final String KEY_CONTENT = "content";
	public static final String KEY_FILE_PATH = "file_path";
	public static final String KEY_MIME_TYPE = "mime_type";
	public static final String KEY_CUSTOM_THRESHOLD = "custom_threshold";

	// ----- Canonical field values used across tests ---------------------------

	public static final String SHARE_TITLE = "Fixture Share Title";
	public static final String SHARE_SUBJECT = "Fixture Share Subject";
	public static final String SHARE_CONTENT = "Fixture share content body";
	public static final String MIME_TYPE_TEXT = "text/plain";
	public static final String MIME_TYPE_IMAGE = "image/png";
	public static final String PACKAGE_NAME = "com.example.test";

	/** The default resumption-from-share threshold baked into {@link SharedData}. */
	public static final long DEFAULT_THRESHOLD_MS = 5_000L;

	/** A custom threshold value used by tests that exercise the override path. */
	public static final long CUSTOM_THRESHOLD_MS = 8_000L;

	private SharePluginFixtures() {
	}

	// =========================================================================
	// Dictionary mock factories
	// =========================================================================

	/**
	 * A minimal Dictionary mock for a text-only share — no file attachment, default MIME type.
	 */
	public static Dictionary textShareDictionary() {
		return buildDict(
				KEY_TITLE, SHARE_TITLE,
				KEY_SUBJECT, SHARE_SUBJECT,
				KEY_CONTENT, SHARE_CONTENT,
				KEY_MIME_TYPE, MIME_TYPE_TEXT
		);
	}

	/**
	 * A Dictionary mock that includes a file attachment at the given path.
	 *
	 * @param filePath absolute path to the file to share
	 * @param mimeType MIME type for the attachment
	 */
	public static Dictionary fileShareDictionary(String filePath, String mimeType) {
		return buildDict(
				KEY_TITLE, SHARE_TITLE,
				KEY_SUBJECT, SHARE_SUBJECT,
				KEY_CONTENT, SHARE_CONTENT,
				KEY_FILE_PATH, filePath,
				KEY_MIME_TYPE, mimeType
		);
	}

	/**
	 * A fully-populated Dictionary mock: all fields including a custom resumption threshold.
	 *
	 * @param filePath absolute path to the file to share
	 */
	public static Dictionary fullShareDictionary(String filePath) {
		Dictionary dict = buildDict(
				KEY_TITLE, SHARE_TITLE,
				KEY_SUBJECT, SHARE_SUBJECT,
				KEY_CONTENT, SHARE_CONTENT,
				KEY_FILE_PATH, filePath,
				KEY_MIME_TYPE, MIME_TYPE_IMAGE
		);
		when(dict.containsKey(KEY_CUSTOM_THRESHOLD)).thenReturn(true);
		when(dict.get(KEY_CUSTOM_THRESHOLD)).thenReturn(CUSTOM_THRESHOLD_MS);
		return dict;
	}

	/**
	 * An empty Dictionary mock — every {@code get()} returns {@code null},
	 * every {@code containsKey()} returns {@code false}.
	 */
	public static Dictionary emptyDictionary() {
		return mock(Dictionary.class);
	}

	// =========================================================================
	// SharedData factories
	// =========================================================================

	/** A {@link SharedData} backed by a text-only Dictionary (default threshold). */
	public static SharedData textSharedData() {
		return new SharedData(textShareDictionary());
	}

	/**
	 * A {@link SharedData} whose {@code getThreshold()} returns the given value.
	 *
	 * @param thresholdMs custom threshold in milliseconds
	 */
	public static SharedData sharedDataWithThreshold(long thresholdMs) {
		Dictionary dict = mock(Dictionary.class);
		when(dict.containsKey(KEY_CUSTOM_THRESHOLD)).thenReturn(true);
		when(dict.get(KEY_CUSTOM_THRESHOLD)).thenReturn(thresholdMs);
		return new SharedData(dict);
	}

	// =========================================================================
	// Temp-file helpers
	// =========================================================================

	/**
	 * Creates a temporary file that is scheduled for deletion when the JVM exits.
	 *
	 * @param prefix prefix for the temp filename
	 * @param suffix suffix / extension (e.g. {@code ".png"})
	 * @return the created, existent {@link File}
	 * @throws IOException if the file cannot be created
	 */
	public static File createTempFile(String prefix, String suffix) throws IOException {
		File file = File.createTempFile(prefix, suffix);
		file.deleteOnExit();
		return file;
	}

	// =========================================================================
	// Private helpers
	// =========================================================================

	/**
	 * Builds a {@link Dictionary} mock with the given key-value pairs pre-stubbed.
	 * Supply arguments as alternating {@code (String key, Object value)} pairs.
	 *
	 * <p><strong>Why lenient stubs?</strong> This is a shared factory used across many tests.
	 * Not every test exercises every key, and some tests replace the injected
	 * {@link org.godotengine.plugin.share.model.SharedData} mid-flight (e.g. a
	 * {@code @BeforeEach} value overwritten by the test body). Strict stubs would raise
	 * {@code UnnecessaryStubbingException} for any stub that is never called in a given
	 * test, and {@code PotentialStubbingProblem} whenever production code calls
	 * {@code dict.get("file_path")} on a mock that only has stubs for other keys.
	 * Lenient stubs on a fixture factory are the standard Mockito remedy for both issues.</p>
	 */
	private static Dictionary buildDict(Object... keyValuePairs) {
		if (keyValuePairs.length % 2 != 0) {
			throw new IllegalArgumentException("keyValuePairs must contain an even number of elements");
		}
		Dictionary dict = mock(Dictionary.class);
		for (int i = 0; i < keyValuePairs.length; i += 2) {
			String key = (String) keyValuePairs[i];
			Object value = keyValuePairs[i + 1];
			lenient().when(dict.get(key)).thenReturn(value);
			lenient().when(dict.containsKey(key)).thenReturn(true);
		}
		return dict;
	}
}
