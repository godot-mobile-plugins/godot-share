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
import org.godotengine.plugin.share.model.SharedData;

import java.io.File;
import java.util.HashSet;
import java.util.Set;

/**
 * SharePlugin
 *
 *  - Uses chooser callback (PendingIntent broadcast) when available to learn chosen target.
 *  - Uses lifecycle detection (onResume) as a fallback.
 *
 * Notes:
 *  - This never guarantees the receiving app actually completed sending; Android doesn't provide that.
 */
public class SharePlugin extends GodotPlugin {
	private static final String CLASS_NAME = SharePlugin.class.getSimpleName();
	private static final String LOG_TAG = "godot::" + CLASS_NAME;
	private static final String FILE_PROVIDER = ".sharefileprovider";
	private static final String MIME_TYPE_TEXT = "text/plain";

	// Signals
	private static final SignalInfo SHARE_COMPLETED_SIGNAL = new SignalInfo("share_completed", String.class);
	private static final SignalInfo SHARE_CANCELED_SIGNAL = new SignalInfo("share_canceled");
	private static final SignalInfo SHARE_FAILED_SIGNAL = new SignalInfo("share_failed", String.class);

	private Activity activity;
	private String authority;

	// Receiver state
	private BroadcastReceiver chooserReceiver;
	private String chooserAction;

	// Share lifecycle flags
	private SharedData sharedDataInProgress;
	private long shareStartTime;

	public SharePlugin(Godot godot) {
		super(godot);
	}

	@NonNull
	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(SHARE_COMPLETED_SIGNAL);
		signals.add(SHARE_CANCELED_SIGNAL);
		signals.add(SHARE_FAILED_SIGNAL);
		return signals;
	}

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

		String mime_type = sharedDataInProgress.getMimeType();
		if (mime_type == null) {
			mime_type = MIME_TYPE_TEXT;
		}
		shareIntent.setType(mime_type);

		// Prepare unique action for chooser callback
		chooserAction = activity.getPackageName() + ".CHOOSER_TARGET_SELECTED." + System.currentTimeMillis();

		Intent callbackIntent = new Intent(chooserAction);
		// Set package to make intent explicit (required for FLAG_MUTABLE on Android 14+)
		callbackIntent.setPackage(activity.getPackageName());

		int flags = PendingIntent.FLAG_UPDATE_CURRENT;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {  // API 31+ requires explicit mutability
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

		// Prepare state & receiver
		shareStartTime = System.currentTimeMillis();

		unregisterChooserReceiverIfAny();

		chooserReceiver = new BroadcastReceiver() {
			private boolean handled = false;

			@Override
			public void onReceive(Context context, Intent intent) {
				if (handled) return;
				handled = true;

				unregisterChooserReceiverIfAny();

				// Mark share finished
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
					// Chosen component not available; still treat as completed
					Log.d(LOG_TAG, "Chooser invoked but chosen component was null. Emitting share_completed with 'UnknownActivity'.");
					GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_COMPLETED_SIGNAL, "UnknownActivity");
				}
			}
		};

		try {
			IntentFilter filter = new IntentFilter(chooserAction);
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
				// Android 14+ requires explicit receiver export flag
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
			// We rely on chooserReceiver or lifecycle to emit signals.
		} catch (Exception e) {
			shareStartTime = 0L;
			unregisterChooserReceiverIfAny();
			sharedDataInProgress = null;
			String errorMessage = "Failed to start share activity: " + e.getMessage();
			Log.e(LOG_TAG, errorMessage, e);
			GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_FAILED_SIGNAL, errorMessage);
		}
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

	@NonNull
	@Override
	public String getPluginName() {
		return CLASS_NAME;
	}

	@Nullable
	@Override
	public View onMainCreate(Activity activity) {
		this.activity = activity;
		this.authority = activity.getPackageName() + FILE_PROVIDER;
		return super.onMainCreate(activity);
	}

	@Override
	public void onMainResume() {
		super.onMainResume();

		if (sharedDataInProgress != null) {
			long duration = System.currentTimeMillis() - shareStartTime;
			unregisterChooserReceiverIfAny();

			if (duration > sharedDataInProgress.getThreshold()) {
				Log.d(LOG_TAG, String.format("onMainResume(): detected share completed via lifecycle (duration: %d ms).", duration));
				GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_COMPLETED_SIGNAL, "UnknownActivity");
			} else {
				Log.d(LOG_TAG, String.format("onMainResume(): detected quick chooser dismissal; treating as canceled (duration: %d ms).", duration));
				GodotPlugin.emitSignal(getGodot(), getPluginName(), SHARE_CANCELED_SIGNAL);
			}

			sharedDataInProgress = null;
			shareStartTime = 0L;
		}
	}

	@Override
	public void onMainDestroy() {
		super.onMainDestroy();
		unregisterChooserReceiverIfAny();
		sharedDataInProgress = null;
		shareStartTime = 0L;
	}
}
