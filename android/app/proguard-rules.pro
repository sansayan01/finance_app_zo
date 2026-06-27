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
