# Same rules as Tapirscan's AAR, whose JAR is used directly.
-keepclasseswithmembernames class org.tapirscan.android.** { native <methods>; }
-keep class org.tapirscan.android.Barcode { <init>(...); }
-keep class org.tapirscan.android.ScannerException { <init>(...); }
