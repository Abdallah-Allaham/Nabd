package com.example.nabd;

import android.content.Context;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import androidx.core.app.ActivityCompat;
import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;

import java.io.File;
import java.io.FileOutputStream;
import java.io.FileInputStream;

import ai.picovoice.eagle.Eagle;
import ai.picovoice.eagle.EagleException;
import ai.picovoice.eagle.EagleProfile;
import ai.picovoice.eagle.EagleProfiler;
import ai.picovoice.eagle.EagleProfilerEnrollResult;
import io.flutter.plugin.common.MethodChannel;

public class VoiceIdService {
    private static final String ACCESS_KEY = "acaklMqZ8HYXIatuuJRKKYj4p07vzsefUnJxzlRpX20qJDqF+KUv4w==";
    private static final int SAMPLE_RATE = 16000;
    private static final int CHANNELS = AudioFormat.CHANNEL_IN_MONO;
    private static final int ENCODING = AudioFormat.ENCODING_PCM_16BIT;
    private static final int BUFFER_SIZE = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNELS, ENCODING);
    private static final int FRAME_LENGTH = 512;
    private static final String PROFILE_FILE = "voice_profile.bin";

    private Eagle eagle;
    private EagleProfiler eagleProfiler;
    private AudioRecord audioRecord;
    private EagleProfile speakerProfile;
    private boolean isRecording = false;

    public VoiceIdService(Context context) {
        loadSpeakerProfile(context);
    }

    public void enrollVoice(Context context, MethodChannel.Result result) {
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_ERROR", "Microphone permission not granted", null);
            return;
        }

        File profileFile = new File(context.getFilesDir(), PROFILE_FILE);
        if (profileFile.exists()) {
            result.success("Voice already enrolled");
            return;
        }

        try {
            eagleProfiler = new EagleProfiler.Builder()
                    .setAccessKey(ACCESS_KEY)
                    .build(context);

            audioRecord = new AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, CHANNELS, ENCODING, BUFFER_SIZE);
            audioRecord.startRecording();
            isRecording = true;

            new Thread(() -> {
                float percentage = 0;
                long startTime = System.currentTimeMillis();
                long timeoutMillis = 15000;

                int minEnrollSamples = eagleProfiler.getMinEnrollSamples();
                int numFramesPerEnroll = minEnrollSamples / FRAME_LENGTH;

                while (isRecording && percentage < 100 && (System.currentTimeMillis() - startTime) < timeoutMillis) {
                    short[] enrollBuffer = new short[numFramesPerEnroll * FRAME_LENGTH];
                    int totalSamplesRead = 0;

                    for (int i = 0; i < numFramesPerEnroll; i++) {
                        short[] frameBuffer = new short[FRAME_LENGTH];
                        int numRead = audioRecord.read(frameBuffer, 0, frameBuffer.length);
                        if (numRead <= 0) {
                            runOnUiThread(() -> result.error("AUDIO_READ_ERROR", "Failed to read audio data", null));
                            return;
                        }
                        System.arraycopy(frameBuffer, 0, enrollBuffer, i * FRAME_LENGTH, numRead);
                        totalSamplesRead += numRead;
                    }

                    try {
                        EagleProfilerEnrollResult feedbackResult = eagleProfiler.enroll(enrollBuffer);
                        percentage = feedbackResult.getPercentage();
                        if (percentage >= 100) {
                            speakerProfile = eagleProfiler.export();
                            saveProfile(context, speakerProfile);
                            eagle = new Eagle.Builder()
                                    .setAccessKey(ACCESS_KEY)
                                    .setSpeakerProfiles(new EagleProfile[]{speakerProfile})
                                    .build(context);
                            runOnUiThread(() -> result.success("Voice enrolled successfully"));
                            stopRecording();
                            return;
                        }
                    } catch (EagleException e) {
                        runOnUiThread(() -> result.error("ENROLL_ERROR", e.getMessage(), null));
                        stopRecording();
                        return;
                    }
                }

                runOnUiThread(() -> result.error("ENROLL_TIMEOUT", "Enrollment timed out, please try again", null));
                stopRecording();
            }).start();
        } catch (EagleException e) {
            result.error("ENROLL_INIT_ERROR", e.getMessage(), null);
        }
    }

    public boolean verifyVoice(Context context, short[] audioBuffer, MethodChannel.Result result) {
        if (speakerProfile == null) {
            result.error("NO_PROFILE", "No voice profile enrolled", null);
            return false;
        }

        if (audioBuffer == null || audioBuffer.length == 0) {
            result.error("INVALID_BUFFER", "Audio buffer is empty or null", null);
            return false;
        }

        try {
            // معالجة الصوت من الـ Buffer مباشرة
            int numFrames = audioBuffer.length / FRAME_LENGTH;
            float highestScore = 0;

            for (int i = 0; i < numFrames; i++) {
                short[] frame = new short[FRAME_LENGTH];
                System.arraycopy(audioBuffer, i * FRAME_LENGTH, frame, 0, FRAME_LENGTH);
                float[] scores = eagle.process(frame);
                if (scores.length > 0 && scores[0] > highestScore) {
                    highestScore = scores[0];
                }
            }

            if (highestScore > 0.7) {
                result.success("Voice matched");
                return true;
            } else {
                result.success("Voice not matched");
                return false;
            }
        } catch (EagleException e) {
            result.error("VERIFY_ERROR", e.getMessage(), null);
            return false;
        }
    }

    public void resetEnrollment(Context context, MethodChannel.Result result) {
        try {
            File file = new File(context.getFilesDir(), PROFILE_FILE);
            if (file.exists()) {
                file.delete();
            }
            speakerProfile = null;
            if (eagle != null) {
                eagle.delete();
                eagle = null;
            }
            result.success("Enrollment reset successfully");
        } catch (Exception e) {
            result.error("RESET_ERROR", "Failed to reset enrollment: " + e.getMessage(), null);
        }
    }

    public boolean isProfileEnrolled(Context context) {
        File profileFile = new File(context.getFilesDir(), PROFILE_FILE);
        return profileFile.exists();
    }

    private void saveProfile(Context context, EagleProfile profile) {
        try {
            File file = new File(context.getFilesDir(), PROFILE_FILE);
            FileOutputStream fos = new FileOutputStream(file);
            fos.write(profile.getBytes());
            fos.close();
        } catch (Exception e) {
            // تجاهل الأخطاء عند الحفظ
        }
    }

    private void loadSpeakerProfile(Context context) {
        try {
            File file = new File(context.getFilesDir(), PROFILE_FILE);
            if (file.exists()) {
                FileInputStream fis = new FileInputStream(file);
                byte[] data = new byte[(int) file.length()];
                fis.read(data);
                fis.close();
                speakerProfile = new EagleProfile(data);
                eagle = new Eagle.Builder()
                        .setAccessKey(ACCESS_KEY)
                        .setSpeakerProfiles(new EagleProfile[]{speakerProfile})
                        .build(context);
            }
        } catch (Exception e) {
            // تجاهل الأخطاء عند التحميل
        }
    }

    private void stopRecording() {
        isRecording = false;
        if (audioRecord != null) {
            audioRecord.stop();
            audioRecord.release();
            audioRecord = null;
        }
        if (eagleProfiler != null) {
            eagleProfiler.delete();
            eagleProfiler = null;
        }
    }

    private void runOnUiThread(Runnable runnable) {
        new Handler(Looper.getMainLooper()).post(runnable);
    }
}