# ============================================================================
# ProGuard Rules for Baust Event - Play Protect Compliant
# ============================================================================
# These rules ensure the app works correctly after obfuscation and passes
# Google Play Protect security checks.

# ============================================================================
# FLUTTER CORE
# ============================================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Flutter embedding
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ============================================================================
# FIREBASE & GOOGLE SERVICES
# ============================================================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Authentication
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.auth.internal.** { *; }

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keepclassmembers class com.google.firebase.firestore.** { *; }

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Firebase Messaging (FCM)
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# ============================================================================
# GOOGLE PLAY SERVICES & PLAY CORE
# ============================================================================
-dontwarn com.google.android.play.core.**
-dontnote com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ============================================================================
# KOTLIN & COROUTINES
# ============================================================================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# ============================================================================
# GSON & JSON SERIALIZATION
# ============================================================================
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent stripping of generic type information
-keepattributes Signature

# ============================================================================
# ANDROID COMPONENTS
# ============================================================================
# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep View constructors
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# ============================================================================
# QR CODE SCANNING (mobile_scanner)
# ============================================================================
-keep class com.journeyapps.barcodescanner.** { *; }
-keep class com.google.zxing.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.zxing.**

# ============================================================================
# IMAGE PROCESSING (image_picker, cached_network_image)
# ============================================================================
-keep class com.github.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# OkHttp (used by cached_network_image)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ============================================================================
# CHARTS (fl_chart)
# ============================================================================
-keep class fl_chart.** { *; }

# ============================================================================
# NOTIFICATIONS (flutter_local_notifications)
# ============================================================================
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }

# ============================================================================
# SHARED PREFERENCES
# ============================================================================
-keep class androidx.preference.** { *; }

# ============================================================================
# URL LAUNCHER & SHARE
# ============================================================================
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

# ============================================================================
# PAYMENT (flutter_bkash)
# ============================================================================
-keep class com.bkash.** { *; }
-dontwarn com.bkash.**

# ============================================================================
# CUSTOM APP CLASSES
# ============================================================================
# Keep all model classes to prevent serialization issues
-keep class com.baust.eventmanager.models.** { *; }
-keep class com.baust.eventmanager.services.** { *; }

# ============================================================================
# SECURITY & OPTIMIZATION
# ============================================================================
# Remove logging in release builds (security best practice)
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Keep crash reporting information
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep annotations for reflection
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes RuntimeInvisibleParameterAnnotations
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ============================================================================
# R8 OPTIMIZATION SETTINGS
# ============================================================================
# Don't warn about missing classes that are optional
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Keep generic signatures for better debugging
-keepattributes Signature
-keepattributes Exceptions

# ============================================================================
# MULTIDEX
# ============================================================================
-keep class androidx.multidex.** { *; }
-dontwarn androidx.multidex.**

