package com.example.molls_app

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /// Shared with `lib/core/localization/platform_locale.dart`.
    private val localeChannel = "wafferapp/locale"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Installs the Theme.SplashScreen-backed splash so the OS-driven
        // launcher-icon splash and the Flutter `LaunchTheme` splash collapse
        // into a single, branded splash that we control end-to-end.
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, localeChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Pushes the in-app language pick into Android's per-app
                    // locale store. On Android 13+ this updates system
                    // surfaces (notifications, recents, the per-app language
                    // picker in Settings). The launcher-icon label itself is
                    // hard-coded to "وفر" via `@string/app_name`, so we no
                    // longer try to flip it dynamically — that was the
                    // approach that crashed the process on Samsung Android 12
                    // and produced a duplicate "Waffer" / "وفر" pair on
                    // first launch.
                    "setApplicationLocale" -> {
                        val tag = call.argument<String>("languageTag")
                        if (tag.isNullOrBlank()) {
                            result.error(
                                "INVALID_ARG",
                                "languageTag is required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            AppCompatDelegate.setApplicationLocales(
                                LocaleListCompat.forLanguageTags(tag),
                            )
                            result.success(null)
                        } catch (e: Throwable) {
                            Log.w(TAG, "setApplicationLocale failed", e)
                            result.error(
                                "SET_LOCALE_FAILED",
                                e.message,
                                null,
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val TAG = "WafferMainActivity"
    }
}
