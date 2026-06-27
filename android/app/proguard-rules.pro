# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase
-keep class com.supabase.** { *; }

# Hive
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Sentry
-keep class io.sentry.** { *; }

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Keep annotation
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Google Play Core (split-install / deferred components) - referenced by
# Flutter embedding even when not actually used. Keep signatures so R8
# does not fail with "Missing class".
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

