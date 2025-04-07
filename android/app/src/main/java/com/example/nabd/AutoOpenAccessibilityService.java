package com.example.nabd;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;

public class AutoOpenAccessibilityService extends AccessibilityService {

    private static AutoOpenAccessibilityService instance;

    public static AutoOpenAccessibilityService getInstance() {
        return instance;
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {}

    @Override
    public void onInterrupt() {}

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        instance = this;
        Log.d("AccessibilityService", "Service connected");
    }

    public static void launchApp(AutoOpenAccessibilityService service) {
        if (service != null) {
            Intent intent = new Intent(service, MainActivity.class);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            service.startActivity(intent);
        }
    }
}
