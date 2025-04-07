package com.example.nabd;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import ai.picovoice.porcupine.PorcupineManager;
import ai.picovoice.porcupine.PorcupineException;
import ai.picovoice.porcupine.PorcupineManagerCallback;

public class PorcupainService extends Service {
    private static final String TAG = "PorcupainService";
    private static final String CHANNEL_ID = "WakeWordChannel";
    private static final int NOTIFICATION_ID = 1;
    private PorcupineManager porcupineManager;
    private boolean isRunning = false;
    private NotificationManager notificationManager;

    String apiKey = "acaklMqZ8HYXIatuuJRKKYj4p07vzsefUnJxzlRpX20qJDqF+KUv4w==";

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "Service Created");
        notificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        createNotificationChannel();

        try {
            porcupineManager = new PorcupineManager.Builder()
                    .setAccessKey(apiKey)
                    .setKeywordPath("nabd.ppn")
                    .setSensitivity(0.7f)
                    .build(this, new PorcupineManagerCallback() {
                        @Override
                        public void invoke(int keywordIndex) {
                            if (keywordIndex == 0) {
                                Log.d(TAG, "Keyword 'نبض' detected!");
                                openApp();
                            }
                        }
                    });
            Log.d(TAG, "PorcupineManager initialized successfully");
        } catch (PorcupineException e) {
            Log.e(TAG, "Failed to initialize PorcupineManager: " + e.getMessage());
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (!isRunning) {
            isRunning = true;
            Notification notification = createNotification();
            startForeground(NOTIFICATION_ID, notification);
            Log.d(TAG, "Foreground service started with notification");
            startListening();
        }
        return START_STICKY;
    }

    private void startListening() {
        try {
            porcupineManager.start();
            Log.d(TAG, "PorcupineManager started listening");
        } catch (PorcupineException e) {
            Log.e(TAG, "Failed to start PorcupineManager: " + e.getMessage());
            stopSelf();
        }
    }

    private void openApp() {
        Log.d(TAG, "Trying to open app using AccessibilityService...");

        if (AutoOpenAccessibilityService.getInstance() != null) {
            AutoOpenAccessibilityService.launchApp(AutoOpenAccessibilityService.getInstance());
            Log.d(TAG, "App launched using AccessibilityService");
            return;
        }

        // ✅ الحل الأفضل: استخدم getLaunchIntentForPackage
        Intent launchIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            startActivity(launchIntent);
            Log.d(TAG, "App launched via getLaunchIntentForPackage");
        } else {
            Log.e(TAG, "Launch intent is null.");
        }
    }


    private Notification createNotification() {
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_btn_speak_now) // رمز مايكروفون
                .setContentTitle("Voice Detection Active")
                .setContentText("Listening for the wake word...")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true);
        return builder.build();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "Wake Word Channel",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Used for wake word detection");
            notificationManager.createNotificationChannel(channel);
        }
    }

    @Override
    public void onDestroy() {
        isRunning = false;
        if (porcupineManager != null) {
            try {
                porcupineManager.stop();
                porcupineManager.delete();
                Log.d(TAG, "PorcupineManager stopped and deleted");
            } catch (PorcupineException e) {
                Log.e(TAG, "Error stopping PorcupineManager: " + e.getMessage());
            }
        }
        super.onDestroy();
        Log.d(TAG, "Service Destroyed");
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
