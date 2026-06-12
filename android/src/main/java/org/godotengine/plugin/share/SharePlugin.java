//
// © 2024-present https://github.com/cengiz-pz
//

package org.godotengine.plugin.share;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ClipData;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.util.Log;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.FileProvider;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.godotengine.plugin.share.model.ReceivedSharedData;
import org.godotengine.plugin.share.model.SharedData;

import java.io.File;
import java.util.HashSet;
import java.util.Set;

/**
 * SharePlugin
 *
 * <h3>Outgoing shares (existing functionality)</h3>
 * <ul>
 *   <li>Uses a chooser callback ({@link PendingIntent} broadcast) when available to learn the
 *       chosen target app.</li>
 *   <li>Falls back to lifecycle detection ({@code onResume}) when the callback is unavailable.</li>
 * </ul>
 *
 * <h3>Incoming shares - share-target mode (new functionality)</h3>
 * <p>Call {@link #set_share_target(boolean) set_share_target(true)} from GDScript to enable this app
 * as a share-target in Android's share sheet. This toggles the {@link ShareTargetActivity}
 * {@code <activity>} declared in the manifest (injected automatically by the Godot editor
 * export plugin in {@code SharePlugin.gd}).</p>
 *
 * <p>When another app shares content to this app the plugin emits {@code share_received} with a
 * {@link Dictionary} containing the received data. If the signal fires before GDScript has
 * connected to it (e.g. on first launch), call {@link #get_received_data()} in your
 * {@code _ready()} function to retrieve and consume the pending data.</p>
 *
 * <h3>Intent routing for incoming shares</h3>
 * <p>The {@code GodotPlugin} base class does not expose an {@code onNewIntent} callback, so
 * both the initial launch-by-share and the in-app-share cases are detected in
 * {@link #onMainResume()}:</p>
 * <ul>
 *   <li><b>Launch-by-share:</b> the intent is captured in {@link #onMainCreate(Activity)} and
 *       stored in {@code pendingIncomingIntent} for processing on the next resume.</li>
 *   <li><b>In-app share (app already running):</b> Android calls {@code onNewIntent} on the
 *       host activity. Godot's {@code GodotApp} follows the standard Android pattern of
 *       calling {@code setIntent(intent)} there, so {@code activity.getIntent()} reflects the
 *       new intent when {@link #onMainResume()} fires. Object-identity comparison against
 *       {@code lastHandledIncomingIntent} prevents reprocessing the same intent on every
 *       subsequent resume.</li>
 * </ul>
 *
 * <h3>Notes</h3>
 * <ul>
 *   <li>Outgoing shares never guarantee the receiving app actually completed sending - Android
 *       does not provide that information.</li>
 *   <li>Received files are copied to {@code getCacheDir()/share_received/}; Android manages
 *       cache eviction automatically.</li>
 * </ul>
 */
public class SharePlugin extends GodotPlugin {
	private static final String CLASS_NAME = SharePlugin.class.getSimpleName();
	private static final String LOG_TAG = "godot::" + CLASS_NAME;
	private static final String FILE_PROVIDER = ".sharefileprovider";
	private static final String MIME_TYPE_TEXT = "text/plain";

	/**
	 * Fully-qualified class name of {@link ShareTargetActivity}.
	 * Used as the second argument of {@link android.content.ComponentName} in
	 * {@link #set_share_target} and {@link #is_share_target}.
	 * The first argument is always the <em>app's</em> package name (not the plugin's).
	 */
	private static final String SHARE_TARGET_CLASS_NAME =
			"org.godotengine.plugin.share.ShareTargetActivity";

	// -------------------------------------------------------------------------
	// Signals
	// -------------------------------------------------------------------------

	/** Emitted when an outgoing share completes. Carries the chosen app's component name. */
	private static final SignalInfo SHARE_COMPLETED_SIGNAL =
			new SignalInfo("share_completed", String.class);

	/** Emitted when the user dismisses the share chooser without selecting a target. */
	private static final SignalInfo SHARE_CANCELED_SIGNAL =
			new SignalInfo("share_canceled");

	/** Emitted when the outgoing share intent cannot be dispatched. Carries an error message. */
	private static final SignalInfo SHARE_FAILED_SIGNAL =
			new SignalInfo("share_failed", String.class);

	/**
	 * Emitted when another app shares data to this app (share-target mode).
	 * The payload is a {@link Dictionary} with the keys defined in
	 * {@link ReceivedSharedData}: {@code mime_type}, {@code text}, {@code subject},
	 * {@code file_paths} ({@code String[]}), {@code is_multiple}.
	 */
	private static final SignalInfo SHARE_RECEIVED_SIGNAL =
			new SignalInfo("share_received", Dictionary.class);

	// -------------------------------------------------------------------------
	// State - outgoing share
	// -------------------------------------------------------------------------

	private Activity activity;
	private String authority;

	private BroadcastReceiver chooserReceiver;
	private String chooserAction;

	private SharedData sharedDataInProgress;
	private long shareStartTime;

	// -------------------------------------------------------------------------
	// State - incoming share
	// -------------------------------------------------------------------------

	/**
	 * Share intent captured in {@link #onMainCreate(Activity)} when the app is launched
	 * directly by a share action. Consumed and cleared in the first {@link #onMainResume()}.
	 */
	private Intent pendingIncomingIntent;

	/**
	 * Reference to the last intent we acted on. Used in {@link #onMainResume()} to guard
	 * against reprocessing the same intent on every subsequent resume (object-identity
	 * comparison via {@code !=}).
	 *
	 * <p>When the app is already running and another app shares to it, Android delivers the
	 * new intent by calling {@code onNewIntent} on the host activity. Godot's
	 * {@code GodotApp} activity follows the standard pattern of calling
	 * {@code setIntent(intent)} there, so {@code activity.getIntent()} always reflects the
	 * most recently delivered intent. We detect a "new" share by comparing the reference
	 * returned by {@code getIntent()} against this field.</p>
	 */
	private Intent lastHandledIncomingIntent;

	/**
	 * The last successfully parsed incoming share payload, retained so GDScript can
	 * call {@link #getReceivedData()} in {@code _ready()} to consume data that arrived
	 * before signals were connected (i.e. the app was launched directly by a share action).
	 */
	private Dictionary lastReceivedData;

	// -------------------------------------------------------------------------
	// Constructor / plugin boilerplate
	// -------------------------------------------------------------------------

	public SharePlugin(Godot godot) {
		super(godot);
	}

	@NonNull
	@Override
	public String getPluginName() {
		return CLASS_NAME;
	}

	@NonNull
	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(SHARE_COMPLETED_SIGNAL);
		signals.add(SHARE_CANCELED_SIGNAL);
		signals.add(SHARE_FAILED_SIGNAL);
		signals.add(SHARE_RECEIVED_SIGNAL);
		return signals;
	}

	// =========================================================================
	// Public API - outgoing share (unchanged)
	// =========================================================================

	@UsedByGodot
	public void share(Dictionary data) {
		Log.d(LOG_TAG, "share() called");

		if (activity == null) {
			String err = "Activity is null; plugin not initialized.";
			Log.e(LOG_TAG, err);
			GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_FAILED_SIGNAL, err);
			return;
		}

		sharedDataInProgress = new SharedData(data);

		Intent shareIntent = new Intent(Intent.ACTION_SEND);
		shareIntent.putExtra(Intent.EXTRA_SUBJECT, sharedDataInProgress.getSubject());
		shareIntent.putExtra(Intent.EXTRA_TEXT, sharedDataInProgress.getContent());

		String path = sharedDataInProgress.getFilePath();
		if (path != null && !path.isEmpty()) {
			File f = new File(path);
			if (!f.exists()) {
				String errorMessage = "File does not exist: " + path;
				Log.e(LOG_TAG, errorMessage);
				GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_FAILED_SIGNAL, errorMessage);
				return;
			}

			Uri uri;
			try {
				uri = FileProvider.getUriForFile(activity, authority, f);
			} catch (IllegalArgumentException e) {
				String errorMessage = String.format("The selected file can't be shared: %s", path);
				Log.e(LOG_TAG, errorMessage, e);
				GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_FAILED_SIGNAL, errorMessage);
				return;
			}

			shareIntent.setClipData(ClipData.newRawUri("", uri));
			shareIntent.putExtra(Intent.EXTRA_STREAM, uri);
			shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
		}

		String mimeType = sharedDataInProgress.getMimeType();
		if (mimeType == null) {
			mimeType = MIME_TYPE_TEXT;
		}
		shareIntent.setType(mimeType);

		// Prepare unique action for chooser callback
		chooserAction = activity.getPackageName() + ".CHOOSER_TARGET_SELECTED." + System.currentTimeMillis();

		Intent callbackIntent = new Intent(chooserAction);
		callbackIntent.setPackage(activity.getPackageName());

		int flags = PendingIntent.FLAG_UPDATE_CURRENT;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {  // API 31+
			flags |= PendingIntent.FLAG_MUTABLE;
		}

		PendingIntent pendingIntent;
		try {
			int requestCode = (int) (System.currentTimeMillis() & 0x7fffffff);
			pendingIntent = PendingIntent.getBroadcast(activity, requestCode, callbackIntent, flags);
		} catch (Exception e) {
			String errorMessage = "Failed to create pending intent for chooser callback: " + e.getMessage();
			Log.e(LOG_TAG, errorMessage, e);
			GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_FAILED_SIGNAL, errorMessage);
			return;
		}

		Intent chooser = Intent.createChooser(shareIntent, sharedDataInProgress.getTitle());
		chooser.putExtra(Intent.EXTRA_CHOSEN_COMPONENT_INTENT_SENDER, pendingIntent.getIntentSender());

		shareStartTime = System.currentTimeMillis();
		unregisterChooserReceiverIfAny();

		chooserReceiver = new BroadcastReceiver() {
			private boolean handled = false;

			@Override
			public void onReceive(Context context, Intent intent) {
				if (handled) {
					return;
				}
				handled = true;

				unregisterChooserReceiverIfAny();

				sharedDataInProgress = null;
				shareStartTime = 0L;

				ComponentName chosen = null;
				try {
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {	// API 33+
						chosen = intent.getParcelableExtra(Intent.EXTRA_CHOSEN_COMPONENT, ComponentName.class);
					} else {
						@SuppressWarnings("deprecation")
						ComponentName deprecatedChosen = intent.getParcelableExtra(Intent.EXTRA_CHOSEN_COMPONENT);
						chosen = deprecatedChosen;
					}
				} catch (Exception e) {
					Log.w(LOG_TAG, "Error reading chosen component: " + e.getMessage());
				}

				if (chosen != null) {
					String cname = chosen.flattenToShortString();
					Log.d(LOG_TAG, "Chooser target selected: " + cname);
					GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_COMPLETED_SIGNAL, cname);
				} else {
					Log.d(LOG_TAG, "Chooser invoked but chosen component was null. Emitting share_completed with"
							+ " 'UnknownActivity'.");
					GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_COMPLETED_SIGNAL, "UnknownActivity");
				}
			}
		};

		try {
			IntentFilter filter = new IntentFilter(chooserAction);
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {  // API 34+
				activity.registerReceiver(chooserReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
			} else {
				activity.registerReceiver(chooserReceiver, filter);
			}
		} catch (Exception e) {
			Log.w(LOG_TAG, "Failed to register chooser receiver: " + e.getMessage());
			chooserReceiver = null;
		}

		try {
			activity.startActivity(chooser);
		} catch (Exception e) {
			shareStartTime = 0L;
			unregisterChooserReceiverIfAny();
			sharedDataInProgress = null;
			String errorMessage = "Failed to start share activity: " + e.getMessage();
			Log.e(LOG_TAG, errorMessage, e);
			GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_FAILED_SIGNAL, errorMessage);
		}
	}

	// =========================================================================
	// Public API - incoming share / share-target mode (new)
	// =========================================================================

	/**
	 * Enables or disables this app as a share-target in Android's share sheet.
	 *
	 * <p>Internally toggles the {@link ShareTargetActivity} component via
	 * {@link PackageManager#setComponentEnabledSetting}. The activity is declared with
	 * {@code android:enabled="false"} by default and injected into the app's manifest
	 * automatically by the Godot editor export plugin ({@code SharePlugin.gd}).</p>
	 *
	 * <p>The change takes effect for share dialogs opened after the call; any currently visible
	 * share sheet is unaffected. Persist the user's preference across launches with
	 * {@code ProjectSettings} or a save file and call this method on startup.</p>
	 *
	 * @param enabled {@code true} to appear in share target lists; {@code false} to hide.
	 */
	@UsedByGodot
	public void set_share_target(boolean enabled) {
		if (activity == null) {
			Log.e(LOG_TAG, "set_share_target: activity is null; plugin not initialized.");
			return;
		}

		ComponentName target = buildShareTargetComponent();
		int newState = enabled
				? PackageManager.COMPONENT_ENABLED_STATE_ENABLED
				: PackageManager.COMPONENT_ENABLED_STATE_DISABLED;
		try {
			activity.getPackageManager().setComponentEnabledSetting(
					target, newState, PackageManager.DONT_KILL_APP);
			Log.d(LOG_TAG, "set_share_target: " + (enabled ? "enabled" : "disabled")
					+ " (" + target.flattenToShortString() + ")");
		} catch (IllegalArgumentException e) {
			Log.e(LOG_TAG, "set_share_target: component not found - ensure ShareTargetActivity"
					+ " is present in the exported app's AndroidManifest.xml."
					+ " The export plugin in SharePlugin.gd injects it automatically.", e);
		} catch (Exception e) {
			Log.e(LOG_TAG, "set_share_target: failed to change component state: " + e.getMessage(), e);
		}
	}

	/**
	 * Returns whether this app is currently registered as a share-target.
	 *
	 * @return {@code true} when the {@link ShareTargetActivity} component is explicitly enabled.
	 */
	@UsedByGodot
	public boolean is_share_target() {
		if (activity == null) {
			return false;
		}
		try {
			int state = activity.getPackageManager()
					.getComponentEnabledSetting(buildShareTargetComponent());
			return state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED;
		} catch (Exception e) {
			Log.w(LOG_TAG, "is_share_target: " + e.getMessage());
			return false;
		}
	}

	/**
	 * Consumes and returns the most recently received share payload, or an empty
	 * {@link Dictionary} when no share has been received since the last call.
	 *
	 * <p>Call this in your GDScript {@code _ready()} function to handle shares that arrived
	 * before signal connections were established (i.e. the app was launched directly
	 * by another app's share action).</p>
	 *
	 * <p>Dictionary keys: {@code mime_type}, {@code text}, {@code subject},
	 * {@code file_paths} ({@code String[]}), {@code is_multiple}.</p>
	 */
	@UsedByGodot
	public Dictionary get_received_data() {
		if (lastReceivedData != null) {
			Dictionary data = lastReceivedData;
			lastReceivedData = null;	// consume once
			return data;
		}
		return new Dictionary();
	}

	// =========================================================================
	// Lifecycle
	// =========================================================================

	@Nullable
	@Override
	public View onMainCreate(Activity activity) {
		this.activity = activity;
		this.authority = activity.getPackageName() + FILE_PROVIDER;

		// If the app was launched directly by a share intent, stash it for
		// processing in onMainResume() once the Godot engine is fully ready.
		Intent launchIntent = activity.getIntent();
		if (isShareIntent(launchIntent)) {
			Log.d(LOG_TAG, "onMainCreate(): launch intent is a share intent - deferring to onMainResume.");
			pendingIncomingIntent = launchIntent;
		}

		return super.onMainCreate(activity);
	}

	@Override
	public void onMainResume() {
		super.onMainResume();

		// -- Outgoing share lifecycle detection (unchanged) -------------------
		if (sharedDataInProgress != null) {
			long duration = System.currentTimeMillis() - shareStartTime;
			unregisterChooserReceiverIfAny();

			if (duration > sharedDataInProgress.getThreshold()) {
				Log.d(LOG_TAG, String.format(
						"onMainResume(): detected share completed via lifecycle (duration: %d ms).", duration));
				GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_COMPLETED_SIGNAL, "UnknownActivity");
			} else {
				Log.d(LOG_TAG, String.format(
						"onMainResume(): detected quick chooser dismissal; treating as canceled (duration: %d ms).",
						duration));
				GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_CANCELED_SIGNAL);
			}

			sharedDataInProgress = null;
			shareStartTime = 0L;
		}

		// -- Incoming share detection (new) -----------------------------------
		//
		// Two sources for an incoming share intent:
		//
		//   1. pendingIncomingIntent - set in onMainCreate() when the app was cold-started
		//      by a share action. This path is authoritative for the launch case.
		//
		//   2. activity.getIntent() - Godot's GodotApp activity calls setIntent(intent)
		//      inside its own onNewIntent(), so getIntent() reflects any new intent
		//      delivered while the app was already running (singleTask launch mode).
		//      Object-identity comparison against lastHandledIncomingIntent prevents
		//      reprocessing the same intent on every subsequent onMainResume() call.
		//
		Intent toProcess = pendingIncomingIntent;
		pendingIncomingIntent = null;

		if (toProcess == null && activity != null) {
			Intent current = activity.getIntent();
			if (isShareIntent(current) && current != lastHandledIncomingIntent) {
				toProcess = current;
			}
		}

		if (toProcess != null) {
			lastHandledIncomingIntent = toProcess;
			processIncomingShareIntent(toProcess);
		}
	}

	@Override
	public void onMainDestroy() {
		super.onMainDestroy();
		unregisterChooserReceiverIfAny();
		sharedDataInProgress = null;
		shareStartTime = 0L;
		pendingIncomingIntent = null;
		lastHandledIncomingIntent = null;
		lastReceivedData = null;
	}

	// =========================================================================
	// Private helpers
	// =========================================================================

	private void processIncomingShareIntent(Intent intent) {
		ReceivedSharedData data = ReceivedSharedData.fromIntent(activity, intent);
		if (data != null) {
			Log.d(LOG_TAG, "processIncomingShareIntent(): " + data);
			lastReceivedData = data.toDictionary();
			GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_RECEIVED_SIGNAL, lastReceivedData);
		} else {
			Log.d(LOG_TAG, "processIncomingShareIntent(): intent carried no usable content.");
		}
	}

	private ComponentName buildShareTargetComponent() {
		// First arg  = app's package name (identifies which app owns the component).
		// Second arg = fully-qualified class name inside the plugin's own package.
		return new ComponentName(activity.getPackageName(), SHARE_TARGET_CLASS_NAME);
	}

	private static boolean isShareIntent(@Nullable Intent intent) {
		if (intent == null) {
			return false;
		}
		String action = intent.getAction();
		return Intent.ACTION_SEND.equals(action) || Intent.ACTION_SEND_MULTIPLE.equals(action);
	}

	private void unregisterChooserReceiverIfAny() {
		if (chooserReceiver != null && activity != null) {
			try {
				activity.unregisterReceiver(chooserReceiver);
			} catch (Exception ignored) {
				// ignore
			}
			chooserReceiver = null;
		}
	}
}
