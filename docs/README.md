<div align="center">

![](https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/demo/assets/share-android.png) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp; ![](https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/demo/assets/share-ios.png)

</div>

<div align="center">
	<a href="https://github.com/godot-mobile-plugins/godot-share"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-share?label=Stars&style=plastic" height="40"/></a>
	<img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-share?label=Latest%20Release&style=plastic" height="40"/>
	<img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-share/latest/total?label=Downloads&style=plastic" height="40"/>
	<img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-share/total?label=Total%20Downloads&style=plastic" height="40"/>
</div>

<br>

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="24"> Godot Share Plugin

Share Plugin allows sharing of text and images on Android and iOS platforms.

**Features:**
- Native share dialogs on Android and iOS
- Share content with other installed apps
- **Share-target mode**: receive content shared by other apps
- Supported share types (outgoing and incoming):
	- Text
	- Images
	- Video
	- Audio
	- Arbitrary files (with MIME type support)

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Table of Contents

- [Demo](#demo)
- [Installation](#installation)
- [Usage](#usage)
- [Share-Target Mode](#share-target-mode)
- [Signals](#signals)
- [Methods](#methods)
- [Classes](#classes)
- [Platform-Specific Notes](#platform-specific-notes)
- [Links](#links)
- [All Plugins](#all-plugins)
- [Credits](#credits)
- [Contributing](#contributing)

<a name="demo"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Demo

Try the **demo app** located in the `demo` directory.

<p align="center">
	<img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/docs/assets/demo_screenshot_android_521.gif" width="243">
	<img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/docs/assets/demo_screenshot_ios_521.gif" width="257">
</p>

<a name="installation"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Installation

> **Important:** Uninstall any previous versions of the plugin before installing a new one.
> If you are targeting **both Android and iOS**, make sure the **addon interface version matches** for both platforms.

### Installation Options

There are 3 ways to install the `Share` plugin into your project:
- Through the GMP Menu (recommended)
- Through the Godot Editor's AssetLib
- Manually by downloading archives from Github

#### 1. Installing via GMP Menu (recommended)

- install [GMP Menu](https://github.com/godot-mobile-plugins/gmp-menu/releases) if not installed
- enable `GMP Menu` via the `Plugins` tab of `Godot Editor`'s `Project->Project Settings...` menu if not enabled
- select `Share Plugin` from `Godot Editor`'s `GMP` menu
- select desired plugin version and platform
- click `Download` button
- once the download has completed, click `Install` button
- enable `Share` via the `Plugins` tab of `Project->Project Settings...` menu, in the Godot Editor

#### 2. AssetLib

- Open the Godot **AssetLib** and search for `Share`
- Click **Download** → **Install**
- Install to the **project root** with **Ignore asset root** enabled
- Enable the plugin via **Project → Project Settings → Plugins**
- For **iOS**, also enable the plugin in the **export settings**
- If installing both Android and iOS versions, you may safely ignore file conflict warnings for shared GDScript interface files

#### 3. Manual Installation

- Download the latest release from GitHub
- Extract the archive into your project root
- Enable the plugin via **Project → Project Settings → Plugins**
- For **iOS**, also enable the plugin in the **export settings**

<a name="usage"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Usage
Add a `Share` node to your scene and follow the following steps:
- use one of the following methods of the `Share` node to share text or images:
		- `share_text(title, subject, content)`
		- `share_image(full_path_for_saved_image_file, title, subject, content)`
				- Note that the image you want to share must be saved under the `user://` virtual directory in order to be accessible. The `OS.get_user_data_dir()` method can be used to get the absolute path for the `user://` directory. See the implementation of `share_viewport()` method for sample code.
		- `share_viewport(viewport, title, subject, content)`

<a name="share-target-mode"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Share-Target Mode

Share-target mode lets other apps share content **to** your Godot game, so your app appears as a destination in the system share sheet or "Open With" picker alongside WhatsApp, Mail, etc.

### Enabling Share-Target Mode

Call `set_share_target(true)` at startup (persist this preference in your save system so it survives restarts):

```gdscript
func _ready() -> void:
    $Share.set_share_target(load_setting("share_target_enabled", false))

func _on_share_target_toggled(enabled: bool) -> void:
    save_setting("share_target_enabled", enabled)
    $Share.set_share_target(enabled)
```

### Handling Received Data

Connect to the `share_received` signal — the `Share` node handles cold-start timing automatically, so no extra `_ready()` boilerplate is needed:

```gdscript
func _ready() -> void:
    $Share.share_received.connect(_on_share_received)
    $Share.set_share_target(true)

func _on_share_received(data: ReceivedSharedData) -> void:
    if data.has_text():
        print("Received text: ", data.get_text())
    if data.has_files():
        for path in data.get_file_paths():
            print("Received file: ", path)
            # path is a plain filesystem path — use FileAccess, Image.load_from_file(), etc.
```

### Platform Differences

| | Android | iOS |
|---|---|---|
| **Share sheet integration** | App appears directly in Android's share sheet alongside WhatsApp, Gmail, etc. | App appears in the "Open With" row of the iOS share sheet (secondary position) |
| **Toggle at runtime** | `set_share_target(true/false)` enables/disables the app in the share sheet immediately | Document types are always registered; the toggle controls whether received files are processed |
| **Export configuration** | Automatic — no extra export settings needed | Enable **share_target/enable_share_target** in the iOS export preset to inject the required `CFBundleDocumentTypes` into Info.plist |
| **Full share-sheet integration** | ✅ Supported out of the box | ⚠️ Requires a separate Share Extension target (outside this plugin's scope) |
| **Received files location** | `getCacheDir()/share_received/` | `<Caches>/share_received/` |

### iOS Setup

1. In Godot Editor, open **Project → Export** and select your iOS export preset.
2. In the **Options** tab, locate **Share Target** and enable **Enable Share Target**.
3. Export your project — the plugin will automatically add the `CFBundleDocumentTypes` entries to `Info.plist`.

> **Note:** With these plist entries, your app appears in the "Open With" picker for text, images, video, audio, and generic files. For full share-sheet integration (primary row alongside system apps), you would need to implement a separate iOS Share Extension.

### Android Setup

No extra export configuration is needed. When `set_share_target(true)` is called, the plugin enables the `ShareTargetActivity` component (which is always included in the APK but disabled by default), making the app appear in Android's share sheet immediately.

<a name="signals"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Signals

**Outgoing share signals:**

- `share_completed(activity_type: String)`: Emitted when...
	- iOS: the shared item is successfully sent
	- Android: the user selects a share target from the chooser
- `share_canceled`: Emitted when...
	- iOS: the user dismisses the share dialog without sending
	- Android: the user returns to the app without selecting a target within a time threshold (default: 5000 ms)
- `share_failed(error_message: String)`: Emitted when an error occurs that prevents sharing.

*Note: On Android, the `share_completed` signal only indicates that a share target was selected. It does not guarantee that the user actually completed the share action.*

**Incoming share signal (share-target mode):**

- `share_received(received_data: ReceivedSharedData)`: Emitted when another app shares content to this app.
	- Android: fired when the user selects this app from Android's share sheet.
	- iOS: fired when the user selects "Open With → [Your App]" in the iOS share sheet.
	- Cold-start timing (app launched by the share action) is handled automatically — no extra `_ready()` code needed.

<a name="methods"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Methods
- `share_text(a_title: String, a_subject: String, a_content: String)` - Shares plain text.
- `share_image(a_path: String, a_title: String, a_subject: String, a_content: String)` - Shares text along with an image located at the given file path.
- `share_texture(a_texture: Texture2D, a_title: String, a_subject: String, a_content: String)` - Shares text with an image generated from a `Texture2D`.
- `share_viewport(a_viewport: Viewport, a_title: String, a_subject: String, a_content: String, a_flip_y: bool)` - Shares text with an image captured from a `Viewport`.
- `share_file(a_path: String, a_mime_type: String, a_title: String, a_subject: String, a_content: String)` - Shares text along with a file at the specified path and MIME type.

**Share-target methods:**

- `set_share_target(a_enabled: bool)` - Enables or disables the app as a share-target. On Android this immediately toggles the app's visibility in the share sheet. On iOS it controls whether received files are processed (document types are always registered).
- `is_share_target() -> bool` - Returns `true` when share-target mode is currently active.
- `get_received_data() -> ReceivedSharedData` - Consumes and returns the pending received-share payload, or `null` when nothing is pending. Called automatically by the `Share` node; you do not normally need to call this directly.

<a name="classes"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Classes

### <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="16"> SharedData
- Encapsulates data to be shared.
- Properties:
	- `title`: Title that may be shown in the share dialog.
	- `subject`: Subject of the shared content (commonly used by email clients).
	- `content`: Main text content to be shared.
	- `file_path`: Path to the file being shared.
	- `mime_type`: MIME type of the shared file.
	- `custom_threshold`: Time in milliseconds after which the plugin considers the share flow completed (Android only).

### <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="16"> ReceivedSharedData
- Wraps the data received when another app shares to this app (share-target mode).
- Methods:
	- `get_mime_type() -> String`: MIME type reported by the sender (e.g. `"image/jpeg"`).
	- `get_text() -> String`: Plain-text payload (`EXTRA_TEXT` on Android).
	- `get_subject() -> String`: Subject line, if any.
	- `get_file_paths() -> PackedStringArray`: Absolute paths of received files copied to the app's cache directory. Use `FileAccess`, `Image.load_from_file()`, etc. to read them.
	- `is_multiple() -> bool`: `true` when multiple files were shared in one action.
	- `has_text() -> bool`: Convenience — `true` when `get_text()` is non-empty.
	- `has_files() -> bool`: Convenience — `true` when `get_file_paths()` is non-empty.
	- `get_raw_data() -> Dictionary`: Returns the underlying Dictionary for advanced use.

<a name="platform-specific-notes"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Platform-Specific Notes

### Android
- **Package name:** In your project's Android export settings, remove/replace the `$genname` token from the `package/unique_name`.
- **Build:** [Create custom Android gradle build](https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html).
- **Registration:** App must be registered with Google Play.
- **Share-target mode:** Call `set_share_target(true)` to make the app appear in Android's share sheet. The `ShareTargetActivity` component is always bundled but disabled by default; the call enables it at runtime without reinstalling.
- **Received files:** Copied to `getCacheDir()/share_received/`. Android clears this automatically when storage is low.
- **Troubleshooting:**
	- Logs: `adb logcat | grep 'godot'` (Linux), `adb.exe logcat | select-string "godot"` (Windows)
	- Also check out: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html#troubleshooting

### iOS
- **Export settings:** The plugin must be enabled in the iOS export settings. For share-target mode, also enable **share_target/enable_share_target** in the export preset's Options tab.
- **Share-target mode:** The app appears in the "Open With" row of the iOS share sheet for registered file types (text, images, video, audio, generic files). This is the maximum achievable within a single plugin bundle; full primary-row presence requires a separate Share Extension target.
- **Received files:** Copied to `<Caches>/share_received/`. iOS clears this automatically when storage is low.
- **Troubleshooting:**
	- View Xcode logs while running the app for troubleshooting.
	- See [Godot iOS Export Troubleshooting](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html#troubleshooting).

<br>

<a name="links"></a>

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> Links

- [AssetLib Entry Android](https://godotengine.org/asset-library/asset/2542)
- [AssetLib Entry iOS](https://godotengine.org/asset-library/asset/2907)

<br>

<a name="all-plugins"></a>

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="24"> All Plugins

| ✦ | Plugin | Android | iOS | Latest Release | Downloads | Stars |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/godot-sdk-integrations/godot-admob/main/addon/src/main/icon.png" width="20"> | [Admob](https://github.com/godot-sdk-integrations/godot-admob) | ✅ | ✅ | <a href="https://github.com/godot-sdk-integrations/godot-admob/releases"><img src="https://img.shields.io/github/release-date/godot-sdk-integrations/godot-admob?label=%20" /><img src="https://img.shields.io/github/v/release/godot-sdk-integrations/godot-admob?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-sdk-integrations/godot-admob/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-sdk-integrations/godot-admob/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-sdk-integrations/godot-admob/stargazers"><img src="https://img.shields.io/github/stars/godot-sdk-integrations/godot-admob?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-connection-state/main/addon/src/main/icon.png" width="20"> | [Connection State](https://github.com/godot-mobile-plugins/godot-connection-state) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-connection-state/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-connection-state?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-connection-state?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-connection-state/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-connection-state/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-connection-state/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-connection-state?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-deeplink/main/addon/src/main/icon.png" width="20"> | [Deeplink](https://github.com/godot-mobile-plugins/godot-deeplink) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-deeplink/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-deeplink?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-deeplink?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-deeplink/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-deeplink/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-deeplink/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-deeplink?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-firebase/main/addon/src/main/icon.png" width="20"> | [Firebase](https://github.com/godot-mobile-plugins/godot-firebase) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-firebase/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-firebase?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-firebase?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-firebase/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-firebase/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-firebase/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-firebase?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-inapp-review/main/addon/src/main/icon.png" width="20"> | [In-App Review](https://github.com/godot-mobile-plugins/godot-inapp-review) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-inapp-review/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-inapp-review?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-inapp-review?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-inapp-review/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-inapp-review/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-inapp-review/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-inapp-review?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-native-camera/main/addon/src/main/icon.png" width="20"> | [Native Camera](https://github.com/godot-mobile-plugins/godot-native-camera) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-native-camera/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-native-camera?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-native-camera?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-native-camera/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-native-camera/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-native-camera/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-native-camera?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-notification-scheduler/main/addon/src/main/icon.png" width="20"> | [Notification Scheduler](https://github.com/godot-mobile-plugins/godot-notification-scheduler) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-notification-scheduler/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-notification-scheduler?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-notification-scheduler?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-notification-scheduler/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-notification-scheduler/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-notification-scheduler/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-notification-scheduler?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-oauth2/main/addon/src/main/icon.png" width="20"> | [OAuth 2.0](https://github.com/godot-mobile-plugins/godot-oauth2) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-oauth2/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-oauth2?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-oauth2?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-oauth2/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-oauth2/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-oauth2/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-oauth2?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-qr/main/addon/src/main/icon.png" width="20"> | [QR](https://github.com/godot-mobile-plugins/godot-qr) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-qr/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-qr?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-qr?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-qr/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-qr/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-qr/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-qr?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="20"> | [Share](https://github.com/godot-mobile-plugins/godot-share) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-share/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-share?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-share?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-share/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-share/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-share/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-share?style=plastic&label=%20" /></a> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-vision/main/addon/src/main/icon.png" width="20"> | [Vision](https://github.com/godot-mobile-plugins/godot-vision) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-vision/releases"><img src="https://img.shields.io/github/release-date/godot-mobile-plugins/godot-vision?label=%20" /><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-vision?label=%20" hspace="4" /></a> | <a href="#"><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-vision/latest/total?label=latest" /><img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-vision/total?label=total" hspace="4" /></a> | <a href="https://github.com/godot-mobile-plugins/godot-vision/stargazers"><img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-vision?style=plastic&label=%20" /></a> |

<br>

<a name="credits"></a>

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="24"> Credits

Developed by [Cengiz](https://github.com/cengiz-pz)

Based on [Godot Mobile Plugin Template v7](https://github.com/godot-mobile-plugins/godot-plugin-template/tree/v7)

Original repository: [Godot Share Plugin](https://github.com/godot-mobile-plugins/godot-share)

<br>

<a name="contributing"></a>

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/main/icon.png" width="24"> Contributing

Contributions are welcome. Please see the [contributing guide](https://github.com/godot-mobile-plugins/godot-share?tab=contributing-ov-file) in the repository for details.

<br>

# 💖 Support the Project

If this plugin has helped you, consider supporting its development! Every bit of support helps keep the plugin updated and bug-free.

| ✦ | Ways to Help | How to do it |
| :--- | :--- | :--- |
|✨⭐| **Spread the Word** | [Star this repo](https://github.com/godot-mobile-plugins/godot-share/stargazers) to help others find it. |
|💡✨| **Give Feedback** | [Open an issue](https://github.com/godot-mobile-plugins/godot-share/issues) or [suggest a feature](https://github.com/godot-mobile-plugins/godot-share/issues/new). |
|🧩| **Contribute** | [Submit a PR](https://github.com/godot-mobile-plugins/godot-share?tab=contributing-ov-file) to help improve the codebase. |
|❤️| **Buy a Coffee** | Support the maintainers on GitHub Sponsors or other platforms. |

<br>

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=godot-mobile-plugins/godot-share&type=date&theme=dark&legend=top-left)](https://www.star-history.com/?repos=godot-mobile-plugins%2Fgodot-share&type=date&theme=dark&legend=top-left)
