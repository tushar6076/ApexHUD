[app]

# (str) Title of your application
title = ApexHUD

# (str) Package name
package.name = apexhud

# (str) Package domain (needed for android/ios packaging)
package.domain = dev.hacksmiths

# (str) Source code where the main.py lives
source.dir = .

# (list) Source files to include (includes your sounds, Orbitron font, Lottie JSON, and HUD assets)
source.include_exts = py,kv,png,jpg,jpeg,atlas,json,ttf,otf,wav

# (list) Directory to exclude
source.exclude_dirs = .git,.buildozer,bin,compiled,_COMPILED,_DOCS,__pycache__,venv,.venv

# (list) Exclusions using pattern matching
source.exclude_patterns = __pycache__/*, *.pyc, *.pyo, *.md

# (str) Application versioning
version = 0.1

# (list) Application requirements
# Pinned Kivy 2.3.1 with KivyMD master branch (M3), dynamic color, async utils, and native hardware bridging
requirements = python3, kivy==2.3.1, https://github.com/kivymd/KivyMD/archive/master.zip, materialyoucolor, pillow, asynckivy, asyncgui, pyjnius, android

# (str) Supported orientation (Landscape HUD)
orientation = landscape

# (bool) Indicate if the application should be fullscreen or not
fullscreen = 1

# (str) Icon of the application
icon.filename = %(source.dir)s/app/assets/icons/icon.png

# (string) Presplash background color
android.presplash_color = #FFFFFF

# (string) Presplash animation using Lottie format
android.presplash_lottie = %(source.dir)s/app/assets/lottie/loading.json


# =======================================================
# Android specific
# =======================================================

# (list) Permissions: UDP sockets, audio streaming, Wi-Fi inspection & location fallback
android.permissions = INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_STATE, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS

# (int) Target Android API
android.api = 33

# (int) Minimum API your APK will support
android.minapi = 21

# (str) Android NDK version to use
android.ndk = 25b

# (int) Android NDK API level
android.ndk_api = 21

# (list) The Android archs to build for
android.archs = arm64-v8a, armeabi-v7a

# (str) Android entry point
android.entrypoint = org.kivy.android.PythonActivity

# (bool) Use --private data storage (True)
android.private_storage = True

# (bool) Enable AndroidX support
android.enable_androidx = True

# (bool) Enable auto backup feature
android.allow_backup = True

# (list) Gradle dependencies required for native Lottie splash animation and AndroidX core
android.gradle_dependencies = com.airbnb.android:lottie:3.4.0, androidx.core:core:1.13.1

# (list) Packaging options to prevent duplicate Kotlin metadata collisions
android.add_packaging_options = "exclude 'META-INF/kotlin-stdlib.kotlin_module'", "exclude 'META-INF/kotlin-stdlib-jdk8.kotlin_module'", "exclude 'META-INF/kotlin-stdlib-jdk7.kotlin_module'"

# (str) Android logcat filters to isolate Python and Kivy output
android.logcat_filters = *:S python:D

# (str) Packaging artifacts
android.debug_artifact = apk
android.release_artifact = apk

# (bool) Automatically accept SDK license agreements
android.accept_sdk_license = True

# (str) Bootstrap to use for android builds
p4a.bootstrap = sdl2


[buildozer]

# (int) Log level (0 = error only, 1 = info, 2 = debug)
log_level = 2

# (int) Display warning if buildozer is run as root
warn_on_root = 1