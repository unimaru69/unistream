# R8 / ProGuard keep rules.
#
# Everything here exists for ONE reason: native code resolves these Java
# classes by their exact name (JNI `FindClass`), which R8 cannot see. It
# happily renames them (AWindow$NativeLock -> AWindow$a) and the library
# then dies at load time.
#
# Symptom this fixed (Philips Android 8 TV, release build only):
#   E VLC/JNI/VLCObject: FindClass(org/videolan/libvlc/interfaces/IMedia$Slave) failed
#   E VLC/LibVLC: Can't load vlcjni library: UnsatisfiedLinkError:
#     JNI_ERR returned from JNI_OnLoad in libvlcjni.so
# …followed by an immediate process death when opening any stream.
# Debug builds were fine because R8 doesn't run there.

# ── libVLC (flutter_vlc_player) ──
# libvlcjni.so's JNI_OnLoad looks up these classes/fields by name.
-keep class org.videolan.** { *; }
-keepclassmembers class org.videolan.** { *; }

# ── media_kit Android helper ──
# libmpv's Android glue reaches this class from native code the same way.
# Unused on Android TV (we route to libVLC there) but still the backend
# on Android phones/tablets.
-keep class com.alexmercerind.mediakitandroidhelper.** { *; }
-keep class com.alexmercerind.media_kit_libs_android_video.** { *; }
-keep class com.alexmercerind.media_kit_libs_android_audio.** { *; }
