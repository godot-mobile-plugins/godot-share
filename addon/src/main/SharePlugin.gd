#
# © 2024-present https://github.com/cengiz-pz
#

@tool
extends EditorPlugin

const PLUGIN_NAME: String = "@pluginName@"
const PLUGIN_PACKAGE: String = "@pluginPackage@"
const ANDROID_DEPENDENCIES: Array = [ @androidDependencies@ ]
const IOS_PLATFORM_VERSION: String = "@iosPlatformVersion@"
const IOS_FRAMEWORKS: Array = [ @iosFrameworks@ ]
const IOS_EMBEDDED_FRAMEWORKS: Array = [ @iosEmbeddedFrameworks@ ]
const IOS_LINKER_FLAGS: Array = [ @iosLinkerFlags@ ]
const IOS_BUNDLE_FILES: Array = [ @iosBundleFiles@ ]
const SPM_DEPENDENCIES: Array = [ @spmDependencies@ ]

# ---------------------------------------------------------------------------
# Android manifest additions
# ---------------------------------------------------------------------------

## FileProvider for outgoing file shares (existing).
## Substitution: [PLUGIN_PACKAGE, package/unique_name]
const PROVIDER_TAG = """
<provider android:name="%s.ShareFileProvider"
		android:exported="false"
		android:authorities="%s.sharefileprovider"
		android:grantUriPermissions="true">
	<meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/file_provider_paths"/>
</provider>
"""

## Declares {@code ShareTargetActivity} in the app manifest (incoming share – new).
##
## A real [code]<activity>[/code] is used instead of [code]<activity-alias>[/code]
## because Android's PackageParser validates alias targets against activities already
## parsed in the same XML pass. Godot inserts manifest additions before the main
## [code]<activity>[/code], so an alias always fails with
## [code]INSTALL_PARSE_FAILED_MANIFEST_MALFORMED (parsedActivities = [])[/code].
## A standalone activity declaration has no such ordering constraint.
##
## The activity is [b]disabled by default[/b] ([code]android:enabled="false"[/code]).
## Call [method Share.set_share_target](true) at runtime to make the app appear in
## Android's share sheet. Persist the preference across launches and restore on startup.
##
## Substitution: [PLUGIN_PACKAGE]
const SHARE_TARGET_ACTIVITY_TAG = """
<activity
		android:name="%s.ShareTargetActivity"
		android:enabled="false"
		android:exported="true"
		android:noHistory="true"
		android:excludeFromRecents="true"
		android:theme="@android:style/Theme.NoDisplay">
	<!-- Single-item text -->
	<intent-filter>
		<action android:name="android.intent.action.SEND" />
		<category android:name="android.intent.category.DEFAULT" />
		<data android:mimeType="text/plain" />
	</intent-filter>
	<!-- Single-item image -->
	<intent-filter>
		<action android:name="android.intent.action.SEND" />
		<category android:name="android.intent.category.DEFAULT" />
		<data android:mimeType="image/*" />
	</intent-filter>
	<!-- Single-item video -->
	<intent-filter>
		<action android:name="android.intent.action.SEND" />
		<category android:name="android.intent.category.DEFAULT" />
		<data android:mimeType="video/*" />
	</intent-filter>
	<!-- Single-item audio -->
	<intent-filter>
		<action android:name="android.intent.action.SEND" />
		<category android:name="android.intent.category.DEFAULT" />
		<data android:mimeType="audio/*" />
	</intent-filter>
	<!-- Single-item generic file (PDF, ZIP, etc.) -->
	<intent-filter>
		<action android:name="android.intent.action.SEND" />
		<category android:name="android.intent.category.DEFAULT" />
		<data android:mimeType="application/*" />
	</intent-filter>
	<!-- Multiple images -->
	<intent-filter>
		<action android:name="android.intent.action.SEND_MULTIPLE" />
		<category android:name="android.intent.category.DEFAULT" />
		<data android:mimeType="image/*" />
	</intent-filter>
	<!-- Multiple videos -->
	<intent-filter>
		<action android:name="android.intent.action.SEND_MULTIPLE" />
		<category android:name="android.intent.category.DEFAULT" />
		<data android:mimeType="video/*" />
	</intent-filter>
	<!-- Multiple mixed files -->
	<intent-filter>
		<action android:name="android.intent.action.SEND_MULTIPLE" />
		<category android:name="android.intent.category.DEFAULT" />
		<data android:mimeType="*/*" />
	</intent-filter>
</activity>
"""

var android_export_plugin: AndroidExportPlugin
var ios_export_plugin: IosExportPlugin


func _enter_tree() -> void:
	android_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(android_export_plugin)
	ios_export_plugin = IosExportPlugin.new()
	add_export_plugin(ios_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(android_export_plugin)
	android_export_plugin = null
	remove_export_plugin(ios_export_plugin)
	ios_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["%s/bin/debug/%s-debug.aar" % [PLUGIN_NAME, PLUGIN_NAME]])
		else:
			return PackedStringArray(["%s/bin/release/%s-release.aar" % [PLUGIN_NAME, PLUGIN_NAME]])


	func _get_name() -> String:
		return PLUGIN_NAME


	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(ANDROID_DEPENDENCIES)


	## Injects two manifest additions into the [code]<application>[/code] element:
	## 1. The [code]ShareFileProvider[/code] [code]<provider>[/code] (outgoing share, existing).
	## 2. The [code]ShareTargetActivity[/code] [code]<activity>[/code] (incoming share).
	##
	## The activity is disabled by default and toggled at runtime via [method Share.set_share_target].
	func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		var __package_name: String = get_option("package/unique_name")
		return (
			(PROVIDER_TAG % [PLUGIN_PACKAGE, __package_name])
			+ (SHARE_TARGET_ACTIVITY_TAG % [PLUGIN_PACKAGE])
		)


## Info.plist document-type registration injected when the iOS share-target export
## option is enabled.  These entries make the Godot app appear in iOS's "Open With"
## picker — the closest single-plugin-bundle equivalent to Android's share-target feature.
##
## Note: appearing as a primary share-sheet recipient (alongside Messages, Mail, etc.)
## requires a separate Share Extension target, which is outside the scope of this plugin.
const IOS_SHARE_TARGET_PLIST_TAG: String = """
<key>LSSupportsOpeningDocumentsInPlace</key>
<false/>
<key>CFBundleDocumentTypes</key>
<array>
	<dict>
		<key>CFBundleTypeName</key>
		<string>Images</string>
		<key>CFBundleTypeRole</key>
		<string>Viewer</string>
		<key>LSHandlerRank</key>
		<string>Alternate</string>
		<key>LSItemContentTypes</key>
		<array>
			<!-- Parent type covers all images; specific sub-types listed below are
				needed so iOS matches HEIC (iPhone native) and JPEG before falling back
				to the parent.  Both must be present for Photos-app sharing to work. -->
			<string>public.image</string>
			<string>public.jpeg</string>
			<string>public.png</string>
			<string>public.heif</string>
			<string>public.heic</string>
			<string>com.apple.heic</string>
			<string>public.tiff</string>
			<string>com.compuserve.gif</string>
			<string>public.webp</string>
		</array>
	</dict>
	<dict>
		<key>CFBundleTypeName</key>
		<string>Video</string>
		<key>CFBundleTypeRole</key>
		<string>Viewer</string>
		<key>LSHandlerRank</key>
		<string>Alternate</string>
		<key>LSItemContentTypes</key>
		<array>
			<string>public.movie</string>
			<string>public.video</string>
			<string>public.mpeg-4</string>
			<string>com.apple.quicktime-movie</string>
		</array>
	</dict>
	<dict>
		<key>CFBundleTypeName</key>
		<string>Audio</string>
		<key>CFBundleTypeRole</key>
		<string>Viewer</string>
		<key>LSHandlerRank</key>
		<string>Alternate</string>
		<key>LSItemContentTypes</key>
		<array>
			<string>public.audio</string>
			<string>public.mp3</string>
			<string>com.apple.m4a-audio</string>
		</array>
	</dict>
	<dict>
		<key>CFBundleTypeName</key>
		<string>Text</string>
		<key>CFBundleTypeRole</key>
		<string>Viewer</string>
		<key>LSHandlerRank</key>
		<string>Alternate</string>
		<key>LSItemContentTypes</key>
		<array>
			<string>public.plain-text</string>
			<string>public.text</string>
			<string>public.utf8-plain-text</string>
		</array>
	</dict>
	<dict>
		<key>CFBundleTypeName</key>
		<string>Files</string>
		<key>CFBundleTypeRole</key>
		<string>Viewer</string>
		<key>LSHandlerRank</key>
		<string>Alternate</string>
		<key>LSItemContentTypes</key>
		<array>
			<string>public.data</string>
			<string>public.content</string>
		</array>
	</dict>
</array>
"""


class IosExportPlugin extends EditorExportPlugin:
	var _spm_dependencies = []


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformIOS


	func _get_name() -> String:
		return PLUGIN_NAME


	## Export option shown in Project → Export → iOS presets.
	## When enabled, CFBundleDocumentTypes entries are injected into Info.plist
	## so the app appears in the iOS "Open With" picker for common file types.
	func _get_export_options(platform: EditorExportPlatform) -> Array[Dictionary]:
		if not _supports_platform(platform):
			return []
		return [
			{
				"option": {
					"name": "share_target/enable_share_target",
					"type": TYPE_BOOL,
				},
				"default_value": false,
			}
		]


	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if _supports_platform(get_export_platform()):
			# Diagnostic: log whether the share-target plist option is active.
			var __enabled: bool = get_option("share_target/enable_share_target")
			GmpLogger.log_info("[SharePlugin] iOS export – share_target/enable_share_target = %s"
					% str(__enabled))

			if __enabled:
				add_apple_embedded_platform_plist_content(IOS_SHARE_TARGET_PLIST_TAG)

			for __framework in IOS_FRAMEWORKS:
				add_apple_embedded_platform_framework(__framework)

			for __framework in IOS_EMBEDDED_FRAMEWORKS:
				add_apple_embedded_platform_embedded_framework(__framework)

			for __flag in IOS_LINKER_FLAGS:
				add_apple_embedded_platform_linker_flags(__flag)

			for __bundle_file in IOS_BUNDLE_FILES:
				add_apple_embedded_platform_bundle_file(__bundle_file)

			for __spm_dep in SPM_DEPENDENCIES:
				_spm_dependencies.append(SpmDependency.new(__spm_dep))


	func _end_generate_apple_embedded_project(path: String, will_build_archive: bool) -> void:
		GmpLogger.log_info("Apple export project generated at: %s. Will build archive: %s"
				% [path, str(will_build_archive)])

		if _supports_platform(get_export_platform()):
			_spm_dependencies.append_array(_get_extra_dependencies())

			if _spm_dependencies.is_empty():
				GmpLogger.log_info("No SPM dependencies to install. Skipping.")
			else:
				GmpLogger.log_info("Installing %d SPM dependencies." % _spm_dependencies.size())
				_install_dependencies(path.get_base_dir(), path.get_file().get_basename())


	func _get_extra_dependencies() -> Array[SpmDependency]:
		var __extra_dependencies:= [] as Array[SpmDependency]

		# Add any extra SPM dependencies here.

		return __extra_dependencies


	func _install_dependencies(a_base_dir: String, a_project_name: String) -> void:
		var __project_file_name:= "%s.xcodeproj" % a_project_name
		var __project_file_path:= a_base_dir.path_join(__project_file_name)
		if not DirAccess.dir_exists_absolute(__project_file_path):
			GmpLogger.log_error("Xcode project '%s' does not exist! Can't install SPM dependencies."
					% __project_file_path)
			return

		var __script_name = "add_dependency.rb"
		var __add_dependency_script_path = a_base_dir.path_join(__script_name)
		var __result = _generate_add_dependency_script(__add_dependency_script_path)
		if __result != Error.OK:
			GmpLogger.log_error("Failed to generate '%s' script with error %d!" % [__script_name, __result])
			return

		GmpLogger.log_info("Adding SPM dependencies to %s..." % __project_file_path)

		for __spm_dep: SpmDependency in _spm_dependencies:
			for __spm_dep_product: String in __spm_dep.get_products():
				var exec_output: Array = []
				var exec_code = OS.execute("ruby", [
							__add_dependency_script_path,
							__project_file_path,
							__spm_dep.get_url(),
							__spm_dep.get_version(),
							__spm_dep_product,
						], exec_output, true, false)

				if exec_code == 0:
					GmpLogger.log_info("Product %s for SPM dependency %s added successfully!"
							% [__spm_dep_product, __spm_dep.format_to_string()])
					for line in exec_output:
						GmpLogger.log_info("SPM: %s" % line)
				else:
					GmpLogger.log_info("Failed to add product %s for SPM dependency %s !"
							% [__spm_dep_product, __spm_dep.format_to_string()])
					for line in exec_output:
						GmpLogger.log_error("SPM: %s" % line)

		GmpLogger.log_info("Resolving SPM dependencies...")

		__script_name = "resolve_dependencies.sh"
		var __resolve_dependencies_script_path = a_base_dir.path_join(__script_name)
		__result = _generate_resolve_dependencies_script(__resolve_dependencies_script_path, a_base_dir, a_project_name)
		if __result != Error.OK:
			GmpLogger.log_error("Failed to generate '%s' script with error %d!" % [__script_name, __result])
			return

		var exec_output: Array = []
		var exec_code = OS.execute(__resolve_dependencies_script_path, [], exec_output, true, false)

		if exec_code == 0:
			for line in exec_output:
				GmpLogger.log_info("SPM: %s" % line)
			GmpLogger.log_info("Resolved dependencies successfully!")
		else:
			for line in exec_output:
				GmpLogger.log_error("SPM: %s" % line)
			GmpLogger.log_info("Failed to resolve dependencies! Try manually in Xcode.")


	const ADD_DEPENDENCY_RUBY_SCRIPT = """
require 'xcodeproj'

project_path = ARGV[0]
url          = ARGV[1].strip
version      = ARGV[2].strip
product_name = ARGV[3].strip

unless File.exist?(project_path)
	puts "Error: Xcode project not found at #{project_path}"
	exit 1
end

if url.empty? || version.empty? || product_name.empty?
	puts "Error: url, version, and product_name must all be non-empty."
	exit 1
end

begin
	project = Xcodeproj::Project.open(project_path)
	target = project.targets.first

	if target.nil?
		puts "Error: No targets found in the Xcode project."
		exit 1
	end

	existing_dep = target.package_product_dependencies.find do |dep|
		dep.product_name == product_name
	end

	if existing_dep
		puts "Warning: Product dependency '#{product_name}' already exists in the project. Skipping add.\n\n"
	else
		# Reuse an existing package reference for the same URL, or create a new one
		pkg = project.root_object.package_references.find do |p|
			p.repositoryURL == url
		end

		if pkg
			puts "Reusing existing package reference for '#{url}'."
		else
			pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
			pkg.repositoryURL = url
			pkg.requirement = {
				'kind' => 'upToNextMajorVersion',
				'minimumVersion' => version
			}
			project.root_object.package_references << pkg
		end

		# Create the product dependency and link it to the shared package reference
		ref = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
		ref.product_name = product_name
		ref.package = pkg
		target.package_product_dependencies << ref

		puts "Successfully added SPM dependency '#{product_name}' " \
				"(#{url} @ #{version}) to #{File.basename(project_path)}\n\n"
	end

	project.save

rescue => e
	puts "An error occurred: #{e.message}\n\n"
	exit 1
end
"""
	func _generate_add_dependency_script(a_script_path: String) -> Error:
		var __result = Error.OK

		var __script_content = ADD_DEPENDENCY_RUBY_SCRIPT

		__result = _create_script(a_script_path, __script_content)

		return __result


	const RESOLVE_DEPENDENCIES_BASH_SCRIPT = """
#!/bin/bash
set -e	# Exit on error

xcodebuild -resolvePackageDependencies \
			-project "%s.xcodeproj" \
			-scheme "%s"
"""
	func _generate_resolve_dependencies_script(a_script_path: String, a_base_dir: String,
			a_project_name: String) -> Error:
		var __result: Error = Error.OK

		var __script_content = RESOLVE_DEPENDENCIES_BASH_SCRIPT \
				% [ ProjectSettings.globalize_path(a_base_dir.path_join(a_project_name)), a_project_name ]

		__result = _create_script(a_script_path, __script_content)

		return __result


	func _create_script(a_script_path: String, a_script_content: String) -> Error:
		var __result: Error = Error.OK

		var __script_file = FileAccess.open(a_script_path, FileAccess.WRITE)
		if __script_file:
			__script_file.store_string(a_script_content)
			__script_file.close()
		else:
			__result = Error.ERR_FILE_CANT_WRITE

		var chmod_output: Array = []
		var chmod_code = OS.execute("chmod", ["+x", a_script_path], chmod_output, true, false)
		if chmod_code != 0:
			GmpLogger.log_error("Failed to chmod %s script: %s"
					% [a_script_path, (chmod_output if chmod_output.size() > 0 else "Unknown error")])
			__result = Error.ERR_FILE_NO_PERMISSION

		return __result
