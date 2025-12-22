# 1. Keep Generic Flutter/Dart Hooks
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. CRITICAL: Fixes "dev.flutter.pigeon" errors (Firebase & Shared Prefs)
-keep class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }
-keep class * extends dev.flutter.pigeon.** { *; }

# 3. CRITICAL: Fixes Share Handler (MissingPluginException)
-keep class com.shoutsocial.share_handler.** { *; }

# 4. CRITICAL: Fixes In-App Update
-keep class de.ffuf.in_app_update.** { *; }

# 5. Fixes Firebase
-keep class com.google.firebase.** { *; }