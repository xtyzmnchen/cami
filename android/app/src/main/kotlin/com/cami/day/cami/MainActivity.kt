package com.cami.day.cami

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setLocale") {
                    val code = call.arguments as? String ?: "zh"
                    setLauncherLocale(code == "en")
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun setLauncherLocale(useEn: Boolean) {
        val pm = packageManager
        val zh = ComponentName(this, "$packageName.LauncherZh")
        val en = ComponentName(this, "$packageName.LauncherEn")
        // 先启用目标别名，再关掉另一个，避免桌面图标短暂消失
        pm.setComponentEnabledSetting(
            if (useEn) en else zh,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        pm.setComponentEnabledSetting(
            if (useEn) zh else en,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }

    companion object {
        private const val CHANNEL = "com.cami.day.cami/app_label"
    }
}
