# Release builds shrink code with R8, removing methods that nothing in
# Java or Kotlin calls. Some plugins call their Android side only from Dart
# through JNI, by name, so R8 cannot see those calls. Without these rules
# the app stops on its launch screen with a NoSuchMethodError (seen with
# shared_preferences_android 2.5.0: SharedPreferencesApiRegistrar.getAll).

# shared_preferences: settings, read on every start.
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# path_provider: app folders (receipt photos, backups).
-keep class io.flutter.plugins.pathprovider.** { *; }

# The JNI bridge both of them use.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

# Kotlin classes the JNI bridge looks up by name to call suspend functions
# and read their results (package:jni, lib/src: Continuation, Result, ...).
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.Unit { *; }
