<p align="center">
	<img width="256" height="256" src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/demo/assets/share-android.png">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<img width="256" height="256" src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/demo/assets/share-ios.png">
</p>

---

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="24"> Godot Share Plugin

Share Plugin allows sharing of text and images on Android and iOS platforms.

**Features:**
- Native share dialogs on Android and iOS
- Share content with other installed apps
- Supported share types:
  - Text
  - Images
  - Arbitrary files (with MIME type support)

---

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> Table of Contents

- [Demo](#demo)
- [Installation](#installation)
- [Usage](#usage)
- [Signals](#signals)
- [Methods](#methods)
- [Classes](#classes)
- [Platform-Specific Notes](#platform-specific-notes)
- [Links](#links)
- [All Plugins](#all-plugins)
- [Credits](#credits)
- [Contributing](#contributing)

---

<a name="demo"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> Demo

Try the **demo app** located in the `demo` directory.

<p align="center">
	<img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/docs/assets/demo_screenshot_android_521.gif" width="243">
	<img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/docs/assets/demo_screenshot_ios_521.gif" width="257">
</p>

---

<a name="installation"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> Installation

> **Important:** Uninstall any previous versions of the plugin before installing a new one.
> If you are targeting **both Android and iOS**, make sure the **addon interface version matches** for both platforms.

### Installation Options

#### 1. AssetLib (Recommended)

- Open the Godot **AssetLib** and search for `Share`
- Click **Download** → **Install**
- Install to the **project root** with **Ignore asset root** enabled
- Enable the plugin via **Project → Project Settings → Plugins**
- For **iOS**, also enable the plugin in the **export settings**
- If installing both Android and iOS versions, you may safely ignore file conflict warnings for shared GDScript interface files

#### 2. Manual Installation

- Download the latest release from GitHub
- Extract the archive into your project root
- Enable the plugin via **Project → Project Settings → Plugins**
- For **iOS**, also enable the plugin in the **export settings**

---

<a name="usage"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> Usage
Add a `Share` node to your scene and follow the following steps:
- use one of the following methods of the `Share` node to share text or images:
		- `share_text(title, subject, content)`
		- `share_image(full_path_for_saved_image_file, title, subject, content)`
				- Note that the image you want to share must be saved under the `user://` virtual directory in order to be accessible. The `OS.get_user_data_dir()` method can be used to get the absolute path for the `user://` directory. See the implementation of `share_viewport()` method for sample code.
		- `share_viewport(viewport, title, subject, content)`

---

<a name="signals"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> Signals

- `share_completed`: Emitted when...
  - iOS: the shared item is successfully sent
  - Android: the user selects a share target from the chooser
- `share_canceled`: Emitted when..
  - iOS: the user dismisses the share dialog without sending
  - Android: the user returns to the app without selecting a target within a time threshold (default: 5000 ms)
- `share_failed`: Emitted when an error occurs that prevents sharing.

*Note: On Android, the `share_completed` signal only indicates that a share target was selected. It does not guarantee that the user actually completed the share action.*

---

<a name="methods"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> Methods
- `share_text(a_title: String, a_subject: String, a_content: String)` - Shares plain text.
- `share_image(a_path: String, a_title: String, a_subject: String, a_content: String)` - Shares text along with an image located at the given file path.
- `share_texture(a_texture: Texture2D, a_title: String, a_subject: String, a_content: String)` - Shares text with an image generated from a `Texture2D`.
- `share_viewport(a_viewport: Viewport, a_title: String, a_subject: String, a_content: String, a_flip_y: bool)` - Shares text with an image captured from a `Viewport`.
- `share_file(a_path: String, a_mime_type: String, a_title: String, a_subject: String, a_content: String` - Shares text along with a file at the specified path and MIME type.

---

<a name="classes"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> Classes

### <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-admob/main/addon/src/icon.png" width="16"> SharedData
- Encapsulates data to be shared.
- Properties:
  - `title`: Title that may be shown in the share dialog.
  - `subject`: Subject of the shared content (commonly used by email clients).
  - `content`: Main text content to be shared.
  - `file_path`: Path to the file being shared.
  - `mime_type`: MIME type of the shared file.
  - `custom_threshold`: Time in milliseconds after which the plugin considers the share flow completed (Android only).

---

<a name="platform-specific-notes"></a>

## <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> Platform-Specific Notes

### Android
- **Package name** In your project's Android export settings, remove/replace the `$genname` token from the `package/unique_name`
- **Build:** [Create custom Android gradle build](https://docs.godotengine.org/en/stable/tutorials/export/android_gradle_build.html).
- **Registration:** App must be registered with the Google Play.
- **Troubleshooting:**
  - Logs: `adb logcat | grep 'godot'` (Linux), `adb.exe logcat | select-string "godot"` (Windows)
  - Also check out: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html#troubleshooting

### iOS
- **Troubleshooting:**
	- View XCode logs while running the game for troubleshooting.
	- See [Godot iOS Export Troubleshooting](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html#troubleshooting).
	- **Export settings:** Plugin must be enabled also in the export settings.

---

<a name="links"></a>

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> Links

- [AssetLib Entry Android](https://godotengine.org/asset-library/asset/2542)
- [AssetLib Entry iOS](https://godotengine.org/asset-library/asset/2907)

---

<a name="all-plugins"></a>

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="24"> All Plugins

| Plugin | Android | iOS | Free | Open Source | License |
| :--- | :---: | :---: | :---: | :---: | :---: |
| [Admob](https://github.com/godot-sdk-integrations/godot-admob) | ✅ | ✅ | ✅ | ✅ | MIT |
| [Notification Scheduler](https://github.com/godot-mobile-plugins/godot-notification-scheduler) | ✅ | ✅ | ✅ | ✅ | MIT |
| [Deeplink](https://github.com/godot-mobile-plugins/godot-deeplink) | ✅ | ✅ | ✅ | ✅ | MIT |
| [Share](https://github.com/godot-mobile-plugins/godot-share) | ✅ | ✅ | ✅ | ✅ | MIT |
| [In-App Review](https://github.com/godot-mobile-plugins/godot-inapp-review) | ✅ | ✅ | ✅ | ✅ | MIT |
| [Native Camera](https://github.com/godot-mobile-plugins/godot-native-camera) | ✅ | ✅ | ✅ | ✅ | MIT |
| [Connection State](https://github.com/godot-mobile-plugins/godot-connection-state) | ✅ | ✅ | ✅ | ✅ | MIT |
| [OAuth 2.0](https://github.com/godot-mobile-plugins/godot-oauth2) | ✅ | ✅ | ✅ | ✅ | MIT |
| [QR](https://github.com/godot-mobile-plugins/godot-qr) | ✅ | ✅ | ✅ | ✅ | MIT |

---

<a name="credits"></a>

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="24"> Credits

Developed by [Cengiz](https://github.com/cengiz-pz)

Based on [Godot Mobile Plugin Template](https://github.com/godot-mobile-plugins/godot-plugin-template)

Original repository: [Godot Share Plugin](https://github.com/godot-mobile-plugins/godot-share)
