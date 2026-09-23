package com.formypet.frontend;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.List;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                "com.formypet/notification_settings"
        ).setMethodCallHandler((call, result) -> {
            if (!"openSettings".equals(call.method)) {
                result.notImplemented();
                return;
            }
            result.success(openNotificationSettings(Boolean.TRUE.equals(call.arguments)));
        });
    }

    private boolean openNotificationSettings(boolean channel) {
        List<Intent> intents = new ArrayList<>();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (channel) {
                intents.add(new Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName())
                        .putExtra(Settings.EXTRA_CHANNEL_ID, "formypet_reminders"));
            }
            intents.add(new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName()));
        }
        intents.add(new Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:" + getPackageName())
        ));
        for (Intent intent : intents) {
            try {
                startActivity(intent);
                return true;
            } catch (ActivityNotFoundException | SecurityException ignored) {
                // Try the next, more general settings page on unsupported devices.
            }
        }
        return false;
    }
}
