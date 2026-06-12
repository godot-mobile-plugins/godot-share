//
// © 2024-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.share.model;

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Parcelable;
import android.provider.OpenableColumns;
import android.util.Log;

import org.godotengine.godot.Dictionary;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Represents data received when another Android app shares content with this Godot app.
 *
 * <p>File URIs are copied from the sender's content provider into this app's private cache
 * directory ({@code getCacheDir()/share_received/}) so that Godot GDScript can access them
 * via ordinary filesystem paths. The cache is managed by Android and cleared on low storage.</p>
 *
 * <p>Create via {@link #fromIntent(Context, Intent)}. Returns {@code null} when the intent
 * carries no usable content (wrong action, no text, no stream URI).</p>
 */
public class ReceivedSharedData {
	private static final String LOG_TAG = "godot::ReceivedSharedData";
	private static final String CACHE_SUBDIR = "share_received";

	/** Keys used in the {@link Dictionary} returned to GDScript. */
	public static final String KEY_MIME_TYPE = "mime_type";
	public static final String KEY_TEXT = "text";
	public static final String KEY_SUBJECT = "subject";
	public static final String KEY_FILE_PATHS = "file_paths";
	public static final String KEY_IS_MULTIPLE = "is_multiple";

	private final String mimeType;
	private final String text;
	private final String subject;
	private final List<String> filePaths;
	private final boolean isMultiple;

	private ReceivedSharedData(String mimeType, String text, String subject,
							List<String> filePaths, boolean isMultiple) {
		this.mimeType = mimeType;
		this.text = text;
		this.subject = subject;
		this.filePaths = filePaths;
		this.isMultiple = isMultiple;
	}

	// -------------------------------------------------------------------------
	// Factory
	// -------------------------------------------------------------------------

	/**
	 * Parses a share intent into a {@link ReceivedSharedData} instance.
	 *
	 * @param context App context used for URI resolution and cache access.
	 * @param intent  The Android {@link Intent} to parse.
	 * @return A populated {@link ReceivedSharedData}, or {@code null} when the intent is not a
	 *         share action or carries no text/file content.
	 */
	public static ReceivedSharedData fromIntent(Context context, Intent intent) {
		if (intent == null) {
			return null;
		}

		final String action = intent.getAction();
		if (!Intent.ACTION_SEND.equals(action) && !Intent.ACTION_SEND_MULTIPLE.equals(action)) {
			return null;
		}

		final boolean isMultiple = Intent.ACTION_SEND_MULTIPLE.equals(action);
		final String mimeType = intent.getType();
		final String text = intent.getStringExtra(Intent.EXTRA_TEXT);
		final String subject = intent.getStringExtra(Intent.EXTRA_SUBJECT);
		final List<String> filePaths = new ArrayList<>();

		if (isMultiple) {
			for (Uri uri : extractUriList(intent)) {
				String path = copyUriToCache(context, uri, mimeType);
				if (path != null) {
					filePaths.add(path);
				}
			}
		} else {
			Uri uri = extractSingleUri(intent);
			if (uri != null) {
				String path = copyUriToCache(context, uri, mimeType);
				if (path != null) {
					filePaths.add(path);
				}
			}
		}

		// Only return a result when there is something actionable
		boolean hasText = (text != null && !text.isEmpty());
		if (!hasText && filePaths.isEmpty()) {
			Log.w(LOG_TAG, "Share intent received but contained no text or file content.");
			return null;
		}

		return new ReceivedSharedData(mimeType, text, subject, filePaths, isMultiple);
	}

	// -------------------------------------------------------------------------
	// Private URI helpers
	// -------------------------------------------------------------------------

	@SuppressWarnings("deprecation")
	private static Uri extractSingleUri(Intent intent) {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			return intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri.class);
		}
		Parcelable p = intent.getParcelableExtra(Intent.EXTRA_STREAM);
		return (p instanceof Uri) ? (Uri) p : null;
	}

	@SuppressWarnings("deprecation")
	private static List<Uri> extractUriList(Intent intent) {
		List<Uri> result = new ArrayList<>();
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			List<Uri> uris = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri.class);
			if (uris != null) {
				result.addAll(uris);
			}
		} else {
			ArrayList<Parcelable> parcelables = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
			if (parcelables != null) {
				for (Parcelable p : parcelables) {
					if (p instanceof Uri) {
						result.add((Uri) p);
					}
				}
			}
		}
		return result;
	}

	// -------------------------------------------------------------------------
	// Private file helpers
	// -------------------------------------------------------------------------

	/**
	 * Copies the content at {@code uri} into the app's private cache directory.
	 *
	 * @return Absolute path of the copied file, or {@code null} on failure.
	 */
	private static String copyUriToCache(Context context, Uri uri, String mimeType) {
		try {
			final String filename = resolveFileName(context, uri, mimeType);

			File cacheDir = new File(context.getCacheDir(), CACHE_SUBDIR);
			if (!cacheDir.exists() && !cacheDir.mkdirs()) {
				Log.e(LOG_TAG, "Failed to create cache directory: " + cacheDir.getAbsolutePath());
				return null;
			}

			File outFile = new File(cacheDir, filename);
			try (InputStream in = context.getContentResolver().openInputStream(uri);
					FileOutputStream out = new FileOutputStream(outFile)) {
				if (in == null) {
					Log.e(LOG_TAG, "Cannot open input stream for URI: " + uri);
					return null;
				}
				byte[] buffer = new byte[8192];
				int bytesRead;
				while ((bytesRead = in.read(buffer)) != -1) {
					out.write(buffer, 0, bytesRead);
				}
			}

			Log.d(LOG_TAG, "Copied shared file to: " + outFile.getAbsolutePath());
			return outFile.getAbsolutePath();
		} catch (Exception e) {
			Log.e(LOG_TAG, "Failed to copy URI to cache: " + e.getMessage(), e);
			return null;
		}
	}

	private static String resolveFileName(Context context, Uri uri, String mimeType) {
		// 1. Query the content provider's display name
		if (ContentResolver.SCHEME_CONTENT.equals(uri.getScheme())) {
			try (Cursor cursor = context.getContentResolver().query(
					uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
				if (cursor != null && cursor.moveToFirst()) {
					String name = cursor.getString(0);
					if (name != null && !name.isEmpty()) {
						return sanitizeFilename(name);
					}
				}
			} catch (Exception e) {
				Log.w(LOG_TAG, "Could not query display name for URI: " + e.getMessage());
			}
		}

		// 2. Use the last segment of the URI path
		String segment = uri.getLastPathSegment();
		if (segment != null && !segment.isEmpty()) {
			return sanitizeFilename(segment);
		}

		// 3. Fall back to a timestamped name with a guessed extension
		return "shared_" + System.currentTimeMillis() + extensionForMimeType(mimeType);
	}

	private static String sanitizeFilename(String name) {
		// Replace characters that are unsafe on most filesystems
		return name.replaceAll("[^a-zA-Z0-9._\\-]", "_");
	}

	private static String extensionForMimeType(String mimeType) {
		if (mimeType == null) {
			return "";
		}
		switch (mimeType) {
			case "image/jpeg":       return ".jpg";
			case "image/png":        return ".png";
			case "image/gif":        return ".gif";
			case "image/webp":       return ".webp";
			case "text/plain":       return ".txt";
			case "text/html":        return ".html";
			case "application/pdf":  return ".pdf";
			default:
				if (mimeType.startsWith("video/")) {
					return ".mp4";
				}
				if (mimeType.startsWith("audio/")) {
					return ".mp3";
				}
				return "";
		}
	}

	// -------------------------------------------------------------------------
	// Public API
	// -------------------------------------------------------------------------

	/**
	 * Serialises this object into a {@link Dictionary} for consumption in GDScript.
	 *
	 * <p>Keys: {@code mime_type}, {@code text}, {@code subject}, {@code file_paths}
	 * ({@code String[]}), {@code is_multiple}.</p>
	 */
	public Dictionary toDictionary() {
		Dictionary dict = new Dictionary();
		dict.put(KEY_MIME_TYPE, mimeType != null ? mimeType : "");
		dict.put(KEY_TEXT, text != null ? text : "");
		dict.put(KEY_SUBJECT, subject != null ? subject : "");
		dict.put(KEY_FILE_PATHS, filePaths.toArray(new String[0]));
		dict.put(KEY_IS_MULTIPLE, isMultiple);
		return dict;
	}

	public String getMimeType() {
		return mimeType;
	}

	public String getText() {
		return text;
	}

	public String getSubject() {
		return subject;
	}

	public List<String> getFilePaths() {
		return filePaths;
	}

	public boolean isMultiple() {
		return isMultiple;
	}

	@Override
	public String toString() {
		return "ReceivedSharedData{"
				+ "mimeType='" + mimeType + '\''
				+ ", text='" + (text != null ? text.substring(0, Math.min(text.length(), 40)) : "null") + "...'"
				+ ", filePaths=" + filePaths
				+ ", isMultiple=" + isMultiple
				+ '}';
	}
}
