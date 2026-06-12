//
// © 2024-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.share;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Bundle;
import android.util.Log;

import java.util.List;

/**
 * Lightweight transparent share-target entry point.
 *
 * <p>When another Android app shares content with this Godot app, Android routes the share
 * intent here (because this activity carries the {@code ACTION_SEND / ACTION_SEND_MULTIPLE}
 * intent-filters). {@link ShareTargetActivity} immediately resolves the real Godot launcher
 * activity at runtime — without hardcoding its class name — forwards the share payload to it,
 * and finishes itself. The user sees no UI.</p>
 *
 * <h3>Why a real Activity instead of an activity-alias?</h3>
 * <p>Android's {@code PackageParser} validates {@code <activity-alias>} targets against
 * activities parsed so far in the same XML pass. Godot's export plugin injects manifest
 * additions <em>before</em> the main {@code <activity>} element, so the target is never
 * found ({@code parsedActivities = []}), causing
 * {@code INSTALL_PARSE_FAILED_MANIFEST_MALFORMED}. A standalone {@code <activity>} has no
 * such forward-reference requirement.</p>
 *
 * <h3>Intent construction — why we do NOT copy the received intent</h3>
 * <p>Share intents from third-party apps frequently carry flags such as
 * {@link Intent#FLAG_ACTIVITY_MULTIPLE_TASK} or {@link Intent#FLAG_ACTIVITY_NEW_DOCUMENT}.
 * Forwarding these flags verbatim (via {@code new Intent(received)}) bypasses the
 * {@code singleTask} launch-mode semantics of the Godot main activity: Android creates a
 * brand-new instance rather than routing to the existing one, causing the app to restart and
 * leaving no focused task after {@code finish()} — so the app never comes to the
 * foreground.</p>
 *
 * <p>Instead we build a <em>fresh</em> intent that copies only the share payload (action,
 * type, extras, clip data) and sets our own explicit flags:</p>
 * <ul>
 *   <li>{@link Intent#FLAG_ACTIVITY_NEW_TASK} — required when starting from a different
 *       task; for a {@code singleTask} activity this brings the existing instance's task to
 *       the foreground rather than creating a second one.</li>
 *   <li>{@link Intent#FLAG_ACTIVITY_SINGLE_TOP} — delivers the intent via
 *       {@code onNewIntent} if the activity is already at the top of its task.</li>
 *   <li>{@link Intent#FLAG_GRANT_READ_URI_PERMISSION} — re-grants {@code content://} URI
 *       read access to the receiving activity's process.</li>
 * </ul>
 *
 * <h3>Intent routing</h3>
 * <ul>
 *   <li><b>App not running (cold start):</b> the forwarded intent becomes the Godot
 *       activity's launch intent; {@link SharePlugin#onMainCreate} stashes it;
 *       {@link SharePlugin#onMainResume} processes it once the engine is ready.</li>
 *   <li><b>App already running:</b> Android delivers the intent to the running activity via
 *       {@code onNewIntent}; Godot's {@code GodotApp} calls {@code setIntent()} there, so
 *       {@code activity.getIntent()} reflects the new intent on the next
 *       {@link SharePlugin#onMainResume} call.</li>
 * </ul>
 *
 * <p>This activity is declared with {@code android:enabled="false"} in the manifest. Call
 * {@code Share.set_share_target(true)} from GDScript to register the app in Android's
 * share sheet.</p>
 */
public class ShareTargetActivity extends Activity {
	private static final String LOG_TAG = "godot::ShareTargetActivity";

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		forwardShareIntent(getIntent());
	}

	@Override
	protected void onNewIntent(Intent intent) {
		super.onNewIntent(intent);
		setIntent(intent);
		forwardShareIntent(intent);
	}

	// -------------------------------------------------------------------------

	/**
	 * Builds a sanitised copy of {@code received}, sets an explicit component pointing at
	 * the Godot launcher activity, applies the correct flags, and starts it.
	 *
	 * <p>We intentionally do <em>not</em> use {@code new Intent(received)} because that
	 * constructor copies {@link Intent#getFlags()}, which may include flags that break
	 * {@code singleTask} routing. See class-level Javadoc for the full rationale.</p>
	 */
	private void forwardShareIntent(Intent received) {
		if (received == null) {
			Log.w(LOG_TAG, "forwardShareIntent(): received intent is null.");
			finish();
			return;
		}

		ComponentName main = resolveGodotActivity();
		if (main == null) {
			Log.e(LOG_TAG, "forwardShareIntent(): could not resolve the Godot launcher activity"
					+ " for package '" + getPackageName() + "'.");
			finish();
			return;
		}

		// Build a fresh intent that carries only the share payload.
		// Do NOT use new Intent(received) — see class-level Javadoc.
		Intent forward = new Intent(received.getAction());
		forward.setType(received.getType());
		if (received.getExtras() != null) {
			forward.putExtras(received.getExtras());
		}
		if (received.getClipData() != null) {
			forward.setClipData(received.getClipData());
		}
		// getData() is not used by ACTION_SEND / SEND_MULTIPLE, but copy it for completeness.
		if (received.getData() != null) {
			forward.setData(received.getData());
		}
		forward.setComponent(main);
		forward.addFlags(
				// Bring the singleTask Godot instance's task to the foreground,
				// or create a new task if no instance exists yet.
				Intent.FLAG_ACTIVITY_NEW_TASK
						// If the Godot activity is already at the top of its task,
						// deliver via onNewIntent instead of creating a second instance.
						| Intent.FLAG_ACTIVITY_SINGLE_TOP
						// Re-grant content-URI read access to the Godot process so that
						// ReceivedSharedData can open the URI via ContentResolver.
						| Intent.FLAG_GRANT_READ_URI_PERMISSION
		);

		Log.d(LOG_TAG, "forwardShareIntent(): forwarding " + received.getAction()
				+ " to " + main.flattenToShortString());

		try {
			startActivity(forward);
		} catch (ActivityNotFoundException e) {
			Log.e(LOG_TAG, "forwardShareIntent(): could not start Godot activity: " + e.getMessage(), e);
		}

		// Finish immediately.  Android 12+ requires activities using a NoDisplay or
		// Translucent theme to call finish() before onResume() returns; our theme
		// (Theme.NoDisplay) falls into this category.  The FLAG_ACTIVITY_NEW_TASK flag
		// on the forward intent ensures Android has already committed to bringing the
		// Godot task to the foreground before it processes our finish().
		finish();
	}

	/**
	 * Resolves the app's main launcher {@link Activity} component at runtime.
	 *
	 * <p>Uses the package manager's intent resolver rather than any hardcoded class name,
	 * so the plugin stays compatible across Godot versions and custom activity subclasses.</p>
	 *
	 * @return The {@link ComponentName} of the launcher activity, or {@code null} when none
	 *         could be found.
	 */
	private ComponentName resolveGodotActivity() {
		Intent queryIntent = new Intent(Intent.ACTION_MAIN);
		queryIntent.addCategory(Intent.CATEGORY_LAUNCHER);
		queryIntent.setPackage(getPackageName());

		List<ResolveInfo> results = getPackageManager()
				.queryIntentActivities(queryIntent, PackageManager.MATCH_DEFAULT_ONLY);

		if (results == null || results.isEmpty()) {
			return null;
		}

		ActivityInfo info = results.get(0).activityInfo;
		return new ComponentName(info.packageName, info.name);
	}
}
