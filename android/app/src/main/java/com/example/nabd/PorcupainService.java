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
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;

public class PorcupainService extends Service {
    private static final String TAG = "PorcupainService";
    private static final String CHANNEL_ID = "WakeWordChannel";
    private static final int NOTIFICATION_ID = 1;
    private PorcupineManager porcupineManager;
    private boolean isRunning = false;
    private NotificationManager notificationManager;
    private VoiceIdService voiceIdService;

    private static final int SAMPLE_RATE = 16000;
    private static final int CHANNELS = AudioFormat.CHANNEL_IN_MONO;
    private static final int ENCODING = AudioFormat.ENCODING_PCM_16BIT;
    private static final int FRAME_LENGTH = 512;
    private static final int BUFFER_SIZE = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNELS, ENCODING);
    private AudioRecord audioRecord;
    private short[] audioBuffer;
    private int bufferIndex = 0;
    private boolean isRecording = false;

    String apiKey = "acaklMqZ8HYXIatuuJRKKYj4p07vzsefUnJxzlRpX20qJDqF+KUv4w==";

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "Service Created");
        notificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        createNotificationChannel();

        voiceIdService = new VoiceIdService(this);

        // تخصيص Buffer لتخزين الصوت (2 ثانية من الصوت)
        int bufferSizeInFrames = SAMPLE_RATE * 2 / FRAME_LENGTH; // 2 ثانية
        audioBuffer = new short[bufferSizeInFrames * FRAME_LENGTH];

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
                                verifyAndOpenApp(audioBuffer);
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
            startRecording();
        }
        return START_STICKY;
    }

    private void startRecording() {
        audioRecord = new AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, CHANNELS, ENCODING, BUFFER_SIZE);
        audioRecord.startRecording();
        isRecording = true;

        new Thread(() -> {
            while (isRecording) {
                short[] frameBuffer = new short[FRAME_LENGTH];
                int numRead = audioRecord.read(frameBuffer, 0, frameBuffer.length);
                if (numRead > 0) {
                    synchronized (audioBuffer) {
                        System.arraycopy(frameBuffer, 0, audioBuffer, bufferIndex * FRAME_LENGTH, numRead);
                        bufferIndex = (bufferIndex + 1) % (audioBuffer.length / FRAME_LENGTH);
                    }
                }
            }
        }).start();
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

    private void verifyAndOpenApp(short[] audioBuffer) {
        io.flutter.plugin.common.MethodChannel.Result callback = new io.flutter.plugin.common.MethodChannel.Result() {
            @Override
            public void success(Object result) {
                if ("Voice matched".equals(result)) {
                    Log.d(TAG, "Voice verified, opening app...");
                    openApp();
                } else {
                    Log.d(TAG, "Voice not matched, ignoring...");
                }
            }

            @Override
            public void error(String errorCode, String errorMessage, Object errorDetails) {
                Log.e(TAG, "Voice verification error: " + errorMessage);
            }

            @Override
            public void notImplemented() {
                Log.w(TAG, "Method not implemented");
            }
        };

        voiceIdService.verifyVoice(this, audioBuffer, callback);
    }

    private void openApp() {
        Log.d(TAG, "Trying to open app using AccessibilityService...");

        if (AutoOpenAccessibilityService.getInstance() != null) {
            AutoOpenAccessibilityService.launchApp(AutoOpenAccessibilityService.getInstance());
            Log.d(TAG, "App launched using AccessibilityService");
            return;
        }

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
                .setSmallIcon(android.R.drawable.ic_btn_speak_now)
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
        isRecording = false;
        if (audioRecord != null) {
            audioRecord.stop();
            audioRecord.release();
            audioRecord = null;
        }
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