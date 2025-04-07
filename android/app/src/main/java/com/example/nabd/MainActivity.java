package com.example.nabd;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.PowerManager;
import android.provider.Settings;
import android.text.TextUtils;
import android.os.Build;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import android.util.Log;


import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "nabd/foreground";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);

        // ✅ أوقف الخدمة عند تشغيل التطبيق
        Intent stopIntent = new Intent(this, PorcupainService.class);
        stopService(stopIntent);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "startService":
                            Intent startServiceIntent = new Intent(this, PorcupainService.class);
                            startService(startServiceIntent);
                            result.success("Service Started");
                            break;

                        case "stopService":
                            Intent stopServiceIntent = new Intent(this, PorcupainService.class);
                            stopService(stopServiceIntent);
                            result.success("Service Stopped");
                            break;

                        case "requestIgnoreBatteryOptimizations":
                            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
                            String packageName = getPackageName();
                            if (pm != null && !pm.isIgnoringBatteryOptimizations(packageName)) {
                                Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                                intent.setData(Uri.parse("package:" + packageName));
                                startActivity(intent);
                            }
                            result.success(null);
                            break;

                        case "requestOverlayPermission":
                            if (!Settings.canDrawOverlays(this)) {
                                Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                        Uri.parse("package:" + getPackageName()));
                                startActivity(intent);
                            } else {
                                Log.d("OverlayPermission", "Already granted.");
                            }
                            result.success(null);
                            break;

                        case "isAccessibilityEnabled":
                            boolean enabled = isAccessibilityServiceEnabled(this, AutoOpenAccessibilityService.class);
                            result.success(enabled);
                            break;

                        case "isOverlayEnabled":
                            boolean canDraw = Settings.canDrawOverlays(this);
                            result.success(canDraw);
                            break;


                        default:
                            result.notImplemented();
                            break;
                    }
                });
    }

    // ✅ دالة التحقق إذا إذن إمكانية الوصول مفعّل
    private boolean isAccessibilityServiceEnabled(Context context, Class<?> accessibilityService) {
        String expectedComponentName = context.getPackageName() + "/" + accessibilityService.getName();
        String enabledServices = Settings.Secure.getString(
                context.getContentResolver(),
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        );

        if (enabledServices == null) return false;

        TextUtils.SimpleStringSplitter colonSplitter = new TextUtils.SimpleStringSplitter(':');
        colonSplitter.setString(enabledServices);

        while (colonSplitter.hasNext()) {
            String componentName = colonSplitter.next();
            if (componentName.equalsIgnoreCase(expectedComponentName)) {
                return true;
            }
        }

        return false;
    }
}
