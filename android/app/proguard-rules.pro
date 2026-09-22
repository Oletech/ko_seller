# R8 is enabled for release builds. Flutter and the Firebase SDKs ship their own
# consumer rules, so this file only covers what reflection in this app needs.

# Firebase / Google Play services keep their own rules, but model classes read
# back out of Firestore are constructed reflectively.
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault

# uCrop (image_cropper) is referenced from the manifest, not from code.
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }

# Play Core is referenced by Flutter's deferred components support, which this
# app does not use; ignore the missing classes rather than failing the build.
-dontwarn com.google.android.play.core.**
