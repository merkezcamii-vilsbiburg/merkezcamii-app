#!/usr/bin/env python3
"""Passt die von `flutter create` erzeugten Plattform-Dateien an (läuft in CI).
Aufruf aus dem Ordner flutter/:  python3 tool/patch_platform.py android|ios
"""
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # flutter/
NATIVE = os.path.join(os.path.dirname(ROOT), "app", "src", "main", "res")  # alte native App-Ressourcen
APP_ID = "de.merkezcamii.vilsbiburg"


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)


def must_sub(pattern, repl, s, what, flags=0):
    new, n = re.subn(pattern, repl, s, count=1, flags=flags)
    if n == 0:
        print("PATCH FEHLGESCHLAGEN:", what)
        print(s)
        sys.exit(1)
    return new


def android():
    a = os.path.join(ROOT, "android", "app")
    gradle = os.path.join(a, "build.gradle.kts")
    if not os.path.exists(gradle):
        print("build.gradle.kts nicht gefunden:", os.listdir(a))
        sys.exit(1)
    g = read(gradle)
    g = must_sub(r'applicationId\s*=\s*"[^"]*"', f'applicationId = "{APP_ID}"', g, "applicationId")
    g = must_sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 26", g, "minSdk")
    g = must_sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, "compileOptions")
    # Signatur wie die bisherige App (damit Updates über die alte App installiert werden können)
    g = must_sub(
        r"buildTypes\s*\{",
        """signingConfigs {
        create("demo") {
            storeFile = file("demo.keystore")
            storePassword = "merkezcamii"
            keyAlias = "demo"
            keyPassword = "merkezcamii"
        }
    }

    buildTypes {""",
        g,
        "buildTypes",
    )
    g = must_sub(
        r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = signingConfigs.getByName("demo")\n            isMinifyEnabled = false\n            isShrinkResources = false',
        g,
        "release signing",
    )
    g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    write(gradle, g)
    shutil.copy(os.path.join(os.path.dirname(ROOT), "app", "demo.keystore"), os.path.join(a, "demo.keystore"))

    # Lint-Prüfung der Plugins im Release abschalten (stürzt bei einigen Plugins ab)
    root_gradle = os.path.join(ROOT, "android", "build.gradle.kts")
    rg = read(root_gradle)
    rg += '\nsubprojects {\n    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }\n}\n'
    write(root_gradle, rg)

    # Manifest
    mf = os.path.join(a, "src", "main", "AndroidManifest.xml")
    m = read(mf)
    perms = """
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
"""
    m = must_sub(r"(<manifest[^>]*>)", r"\1" + perms, m, "manifest perms")
    m = must_sub(r'android:label="[^"]*"', 'android:label="Merkez Camii"', m, "label")
    m = re.sub(r'\s*android:roundIcon="[^"]*"', "", m)
    m = must_sub(r'(android:icon="@mipmap/ic_launcher")', r'\1\n        android:roundIcon="@mipmap/ic_launcher_round"', m, "icon")
    receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        <receiver android:exported="false" android:name=".EzanAlarmReceiver" />
        <receiver android:exported="false" android:name=".EzanBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            </intent-filter>
        </receiver>
        <service android:exported="false" android:name=".EzanService" android:foregroundServiceType="mediaPlayback" />
    </application>"""
    m = must_sub(r"\s*</application>", receivers, m, "receivers")
    m = re.sub(r'android:screenOrientation="[^"]*"', "", m)
    if "android.intent.action.DIAL" not in m:
        q = """
    <queries>
        <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="https" /></intent>
        <intent><action android:name="android.intent.action.DIAL" /><data android:scheme="tel" /></intent>
        <intent><action android:name="android.intent.action.SENDTO" /><data android:scheme="mailto" /></intent>
    </queries>
</manifest>"""
        m = re.sub(r"</manifest>\s*$", q, m)
    write(mf, m)

    # Eigener Kotlin-Code: Ezan im Lautlos-Modus (Alarm-Ton)
    kt_dir = None
    for dp, _, fs in os.walk(os.path.join(a, "src", "main", "kotlin")):
        if "MainActivity.kt" in fs:
            kt_dir = dp
    if kt_dir is None:
        print("MainActivity.kt nicht gefunden")
        sys.exit(1)
    for f in os.listdir(os.path.join(ROOT, "native_android")):
        shutil.copy(os.path.join(ROOT, "native_android", f), os.path.join(kt_dir, f))

    # Ressourcen aus der bisherigen App
    res = os.path.join(a, "src", "main", "res")
    for d in ["mipmap-anydpi-v26", "mipmap-xxxhdpi", "drawable-xxxhdpi"]:
        src = os.path.join(NATIVE, d)
        for f in os.listdir(src):
            os.makedirs(os.path.join(res, d), exist_ok=True)
            shutil.copy(os.path.join(src, f), os.path.join(res, d, f))
    for f in ["notif_cami.png", "notif_lokal.png"]:
        os.makedirs(os.path.join(res, "drawable-nodpi"), exist_ok=True)
        shutil.copy(os.path.join(NATIVE, "drawable-nodpi", f), os.path.join(res, "drawable-nodpi", f))
    write(os.path.join(res, "values", "colors.xml"),
          '<resources>\n    <color name="bg">#FF06140F</color>\n    <color name="ic_bg">#FF06140F</color>\n</resources>\n')
    lb = '<?xml version="1.0" encoding="utf-8"?>\n<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n    <item android:drawable="@color/bg" />\n</layer-list>\n'
    for d in ["drawable", "drawable-v21"]:
        p = os.path.join(res, d, "launch_background.xml")
        if os.path.exists(p) or d == "drawable":
            write(p, lb)
    write(os.path.join(res, "values-v31", "styles.xml"), """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowSplashScreenBackground">@color/bg</item>
        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher_foreground</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@color/bg</item>
    </style>
</resources>
""")
    # Eigener Ezan (öğle–yatsı) als Benachrichtigungston
    os.makedirs(os.path.join(res, "raw"), exist_ok=True)
    shutil.copy(os.path.join(ROOT, "assets", "audio", "ezan.mp3"), os.path.join(res, "raw", "ezan.mp3"))
    shutil.copy(os.path.join(ROOT, "assets", "audio", "ezan_sabah.mp3"), os.path.join(res, "raw", "ezan_sabah.mp3"))
    # Ressourcen, die nur per Name aus Dart benutzt werden, nicht entfernen
    write(os.path.join(res, "raw", "keep.xml"),
          '<?xml version="1.0" encoding="utf-8"?>\n<resources xmlns:tools="http://schemas.android.com/tools" '
          'tools:keep="@raw/*,@drawable/ic_stat_*,@drawable/notif_*" />\n')
    print("Android angepasst.")


def ios():
    pbx = os.path.join(ROOT, "ios", "Runner.xcodeproj", "project.pbxproj")
    s = read(pbx)
    s = s.replace("de.merkezcamii.merkezcamii", APP_ID)
    s = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 13.0;", s)
    write(pbx, s)
    plist = os.path.join(ROOT, "ios", "Runner", "Info.plist")
    p = read(plist)
    p = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", r"\1Merkez Camii\2", p)
    if "NSLocationWhenInUseUsageDescription" not in p:
        p = p.replace("<dict>", "<dict>\n\t<key>NSLocationWhenInUseUsageDescription</key>\n\t<string>Kıble yönü için ve yöneticilere lokale geldiklerinde lokali açmayı önermek için kullanılır. Konum telefondan dışarı gönderilmez.</string>", 1)
    if "LSApplicationQueriesSchemes" not in p:
        p = p.replace("<dict>", "<dict>\n\t<key>LSApplicationQueriesSchemes</key>\n\t<array>\n\t\t<string>tel</string>\n\t\t<string>mailto</string>\n\t\t<string>https</string>\n\t</array>", 1)
    if "UIBackgroundModes" not in p:
        p = p.replace("<dict>", "<dict>\n\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>remote-notification</string>\n\t</array>", 1)
    write(plist, p)
    podfile = os.path.join(ROOT, "ios", "Podfile")
    if os.path.exists(podfile):
        pf = read(podfile)
        pf = re.sub(r"#?\s*platform :ios, '[0-9.]+'", "platform :ios, '13.0'", pf)
        write(podfile, pf)
    print("iOS angepasst.")


if __name__ == "__main__":
    {"android": android, "ios": ios}[sys.argv[1]]()
