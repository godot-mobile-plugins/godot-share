//
// © 2024-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.share.model;

import org.godotengine.godot.Dictionary;

public class SharedData {
	// Threshold (ms) to consider a share to be completed upon returning to app.
	private static final long DEFAULT_RESUMPTION_FROM_SHARE_THRESHOLD_MS = 5000L;

	private static String DATA_KEY_TITLE = "title";
	private static String DATA_KEY_SUBJECT = "subject";
	private static String DATA_KEY_CONTENT = "content";
	private static String DATA_KEY_FILE_PATH = "file_path";
	private static String DATA_KEY_MIME_TYPE = "mime_type";
	private static String DATA_KEY_CUSTOM_THRESHOLD_MS = "custom_threshold";

	private Dictionary data;

	public SharedData(Dictionary data) {
		this.data = data;
	}

	public String getTitle() {
		return (String) data.get(DATA_KEY_TITLE);
	}

	public String getSubject() {
		return (String) data.get(DATA_KEY_SUBJECT);
	}

	public String getContent() {
		return (String) data.get(DATA_KEY_CONTENT);
	}

	public String getFilePath() {
		return (String) data.get(DATA_KEY_FILE_PATH);
	}

	public String getMimeType() {
		return (String) data.get(DATA_KEY_MIME_TYPE);
	}

	public long getThreshold() {
		return data.containsKey(DATA_KEY_CUSTOM_THRESHOLD_MS) ?
				(long) data.get(DATA_KEY_CUSTOM_THRESHOLD_MS) :
				DEFAULT_RESUMPTION_FROM_SHARE_THRESHOLD_MS;
	}
}
