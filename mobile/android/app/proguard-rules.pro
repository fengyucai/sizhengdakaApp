# AMap location SDK references optional provider classes that are not packaged
# in the mobile app. They are guarded at runtime by the SDK, but R8 requires
# explicit dontwarn rules for release builds.
-dontwarn com.amap.ams.gnss.GnssSoftLocator
-dontwarn net.jafama.FastMath
