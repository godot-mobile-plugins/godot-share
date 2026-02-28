<p align="center">
	<img width="128" height="128" src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/demo/assets/share-android.png">
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<img width="128" height="128" src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/demo/assets/share-ios.png">
</p>

---

<div align="center">
	<a href="https://github.com/godot-mobile-plugins/godot-share">
	<img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-share?style=social" />
	</a>
	<img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-share?label=Latest%20Release" />
	<img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-share/latest/total?label=Downloads" />
	<img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-share/total?label=Total%20Downloads" />
</div>

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

### <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="16"> SharedData
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

| | Plugin | Android | iOS | Latest Release | Downloads | Stars |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/godot-sdk-integrations/godot-admob/main/addon/src/icon.png" width="20"> | [Admob](https://github.com/godot-sdk-integrations/godot-admob) | ✅ | ✅ | <a href="https://github.com/godot-sdk-integrations/godot-admob"><img src="https://img.shields.io/github/v/release/godot-sdk-integrations/godot-admob?label=%20" /></a> | <img src="https://img.shields.io/github/downloads/godot-sdk-integrations/godot-admob/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-sdk-integrations/godot-admob/total?label=total" /> | <img src="https://img.shields.io/github/stars/godot-sdk-integrations/godot-admob?style=plastic&label=%20" /> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-connection-state/main/addon/src/icon.png" width="20"> | [Connection State](https://github.com/godot-mobile-plugins/godot-connection-state) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-connection-state"><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-connection-state?label=%20" /></a> | <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-connection-state/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-connection-state/total?label=total" /> | <img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-connection-state?style=plastic&label=%20" /> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-deeplink/main/addon/src/icon.png" width="20"> | [Deeplink](https://github.com/godot-mobile-plugins/godot-deeplink) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-deeplink"><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-deeplink?label=%20" /></a> | <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-deeplink/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-deeplink/total?label=total" /> | <img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-deeplink?style=plastic&label=%20" /> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-firebase/main/addon/src/icon.png" width="20"> | [Firebase](https://github.com/godot-mobile-plugins/godot-firebase) | ✅ | ✅ | <!-- <a href="https://github.com/godot-mobile-plugins/godot-firebase"><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-firebase?label=%20" /></a> --> | <!-- <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-firebase/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-firebase/total?label=%20" /> --> | <img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-firebase?style=plastic&label=%20" /> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-inapp-review/main/addon/src/icon.png" width="20"> | [In-App Review](https://github.com/godot-mobile-plugins/godot-inapp-review) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-inapp-review"><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-inapp-review?label=%20" /></a> | <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-inapp-review/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-inapp-review/total?label=total" /> | <img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-inapp-review?style=plastic&label=%20" /> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-native-camera/main/addon/src/icon.png" width="20"> | [Native Camera](https://github.com/godot-mobile-plugins/godot-native-camera) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-native-camera"><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-native-camera?label=%20" /></a> | <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-native-camera/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-native-camera/total?label=total" /> | <img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-native-camera?style=plastic&label=%20" /> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-notification-scheduler/main/addon/src/icon.png" width="20"> | [Notification Scheduler](https://github.com/godot-mobile-plugins/godot-notification-scheduler) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-notification-scheduler"><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-notification-scheduler?label=%20" /></a> | <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-notification-scheduler/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-notification-scheduler/total?label=total" /> | <img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-notification-scheduler?style=plastic&label=%20" /> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-oauth2/main/addon/src/icon.png" width="20"> | [OAuth 2.0](https://github.com/godot-mobile-plugins/godot-oauth2) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-oauth2"><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-oauth2?label=%20" /></a> | <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-oauth2/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-oauth2/total?label=total" /> | <img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-oauth2?style=plastic&label=%20" /> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-qr/main/addon/src/icon.png" width="20"> | [QR](https://github.com/godot-mobile-plugins/godot-qr) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-qr"><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-qr?label=%20" /></a> | <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-qr/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-qr/total?label=total" /> | <img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-qr?style=plastic&label=%20" /> |
| <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="20"> | [Share](https://github.com/godot-mobile-plugins/godot-share) | ✅ | ✅ | <a href="https://github.com/godot-mobile-plugins/godot-share"><img src="https://img.shields.io/github/v/release/godot-mobile-plugins/godot-share?label=%20" /></a> | <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-share/latest/total?label=latest" /> <img src="https://img.shields.io/github/downloads/godot-mobile-plugins/godot-share/total?label=total" /> | <img src="https://img.shields.io/github/stars/godot-mobile-plugins/godot-share?style=plastic&label=%20" /> |

---

<a name="credits"></a>

# <img src="https://raw.githubusercontent.com/godot-mobile-plugins/godot-share/main/addon/src/icon.png" width="24"> Credits

Developed by [Cengiz](https://github.com/cengiz-pz)

Based on [Godot Mobile Plugin Template](https://github.com/godot-mobile-plugins/godot-plugin-template)

Original repository: [Godot Share Plugin](https://github.com/godot-mobile-plugins/godot-share)

---

# 💖 Support the Project

If this plugin has helped you, consider supporting its development! Every bit of support helps keep the plugin updated and bug-free.

| | Ways to Help | How to do it |
| :--- | :--- | :--- |
|✨⭐| **Spread the Word** | [Star this repo](https://github.com/godot-mobile-plugins/godot-share/stargazers) to help others find it. |
|💡✨| **Give Feedback** | [Open an issue](https://github.com/godot-mobile-plugins/godot-share/issues) or [suggest a feature](https://github.com/godot-mobile-plugins/godot-share/issues/new). |
|🧩| **Contribute** | [Submit a PR](https://github.com/godot-mobile-plugins/godot-share?tab=contributing-ov-file) to help improve the codebase. |
|❤️| **Buy a Coffee** | Support the maintainers on GitHub Sponsors or other platforms. |

## ⭐ Star History
[![Star History Chart](https://api.star-history.com/svg?repos=godot-mobile-plugins/godot-share&type=Date)](https://star-history.com/#godot-mobile-plugins/godot-share&Date)
