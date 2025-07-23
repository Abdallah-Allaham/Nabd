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
import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.io.DataOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

import ai.picovoice.eagle.Eagle;
import ai.picovoice.eagle.EagleException;
import ai.picovoice.eagle.EagleProfile;
import ai.picovoice.eagle.EagleProfiler;
import ai.picovoice.eagle.EagleProfilerEnrollResult;
import io.flutter.plugin.common.MethodChannel;

public class VoiceIdService {
    private static final String TAG = "VoiceIdService";
    private static final String ACCESS_KEY = "";
    private static final int SAMPLE_RATE = 16000;
    private static final int CHANNELS = AudioFormat.CHANNEL_IN_MONO;
    private static final int ENCODING = AudioFormat.ENCODING_PCM_16BIT;
    private static final int BUFFER_SIZE = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNELS, ENCODING);
    private static final int FRAME_LENGTH = 512;
    private static final String PROFILE_FILE = "voice_profile.bin";
    private static final String AUDIO_FILE = "enroll_audio.wav";
    private static final int RECORD_DURATION_SECONDS = 7;

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
            Log.e(TAG, "Microphone permission not granted");
            result.error("PERMISSION_ERROR", "Microphone permission not granted", null);
            return;
        }

        File profileFile = new File(context.getFilesDir(), PROFILE_FILE);
        if (profileFile.exists()) {
            Log.d(TAG, "Voice profile already exists");
            result.success("Voice already enrolled");
            return;
        }

        try {
            Log.d(TAG, "Initializing EagleProfiler...");
            eagleProfiler = new EagleProfiler.Builder()
                    .setAccessKey(ACCESS_KEY)
                    .build(context);
            Log.d(TAG, "EagleProfiler initialized successfully");

            Log.d(TAG, "Starting audio recording...");
            audioRecord = new AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, CHANNELS, ENCODING, BUFFER_SIZE);
            if (audioRecord.getState() != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "Failed to initialize AudioRecord");
                result.error("AUDIO_INIT_ERROR", "Failed to initialize audio recording", null);
                stopRecording();
                return;
            }
            audioRecord.startRecording();
            isRecording = true;
            Log.d(TAG, "Audio recording started");

            new Thread(() -> {
                try {
                    int totalSamples = SAMPLE_RATE * RECORD_DURATION_SECONDS;
                    short[] enrollBuffer = new short[totalSamples];
                    int totalSamplesRead = 0;

                    // تسجيل الصوت
                    Log.d(TAG, "Recording audio for " + RECORD_DURATION_SECONDS + " seconds...");
                    while (isRecording && totalSamplesRead < totalSamples) {
                        short[] frameBuffer = new short[FRAME_LENGTH];
                        int numRead = audioRecord.read(frameBuffer, 0, frameBuffer.length);
                        if (numRead <= 0) {
                            Log.e(TAG, "Failed to read audio data: " + numRead);
                            runOnUiThread(() -> result.error("AUDIO_READ_ERROR", "Failed to read audio data", null));
                            return;
                        }
                        int samplesToCopy = Math.min(numRead, totalSamples - totalSamplesRead);
                        System.arraycopy(frameBuffer, 0, enrollBuffer, totalSamplesRead, samplesToCopy);
                        totalSamplesRead += samplesToCopy;
                    }
                    Log.d(TAG, "Finished recording audio, total samples read: " + totalSamplesRead);

                    // مضاعفة البيانات لتصير 28 ثانية (4 مرات)
                    int multiplier = 4;
                    int multipliedSamples = totalSamples * multiplier;
                    short[] multipliedEnrollBuffer = new short[multipliedSamples];
                    for (int i = 0; i < multiplier; i++) {
                        System.arraycopy(enrollBuffer, 0, multipliedEnrollBuffer, i * totalSamples, totalSamples);
                    }
                    Log.d(TAG, "Multiplied audio buffer to " + multipliedSamples + " samples (" + (multipliedSamples / SAMPLE_RATE) + " seconds)");


                    Log.d(TAG, "Saving audio to WAV file...");
                    try {
                        saveAudioToWav(context, multipliedEnrollBuffer);
                        Log.d(TAG, "Audio saved successfully as " + AUDIO_FILE);
                    } catch (Exception e) {
                        Log.e(TAG, "Failed to save audio file: " + e.getMessage(), e);
                        runOnUiThread(() -> result.error("SAVE_ERROR", "Failed to save audio file: " + e.getMessage(), null));
                        return;
                    }

                   
                    Log.d(TAG, "Starting voice enrollment...");
                    try {
                        if (eagleProfiler == null) {
                            Log.e(TAG, "EagleProfiler is null before enrollment");
                            runOnUiThread(() -> result.error("ENROLL_ERROR", "EagleProfiler is null", null));
                            return;
                        }
                        float percentage = 0;
                        while (percentage < 85) {
                            EagleProfilerEnrollResult feedbackResult = eagleProfiler.enroll(multipliedEnrollBuffer);
                            percentage = feedbackResult.getPercentage();
                            Log.d(TAG, "Enrollment percentage: " + percentage);
                            if (percentage >= 85) break;
                            Thread.sleep(100);
                        }
                        speakerProfile = eagleProfiler.export();
                        saveProfile(context, speakerProfile);
                        eagle = new Eagle.Builder()
                                .setAccessKey(ACCESS_KEY)
                                .setSpeakerProfiles(new EagleProfile[]{speakerProfile})
                                .build(context);
                        Log.d(TAG, "Voice enrolled successfully");
                        runOnUiThread(() -> result.success("Voice enrolled successfully"));
                    } catch (EagleException e) {
                        Log.e(TAG, "Enrollment error: " + e.getMessage(), e);
                        runOnUiThread(() -> result.error("ENROLL_ERROR", e.getMessage(), null));
                    } catch (InterruptedException e) {
                        Log.e(TAG, "Thread interrupted: " + e.getMessage(), e);
                        runOnUiThread(() -> result.error("THREAD_ERROR", "Thread interrupted", null));
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Unexpected error during enrollment: " + e.getMessage(), e);
                    runOnUiThread(() -> result.error("UNEXPECTED_ERROR", "An unexpected error occurred: " + e.getMessage(), null));
                } finally {
                    Log.d(TAG, "Stopping recording...");
                    stopRecording();
                    Log.d(TAG, "Recording stopped");
                }
            }).start();
        } catch (EagleException e) {
            Log.e(TAG, "Failed to initialize EagleProfiler: " + e.getMessage(), e);
            result.error("ENROLL_INIT_ERROR", e.getMessage(), null);
        } catch (Exception e) {
            Log.e(TAG, "Unexpected error during setup: " + e.getMessage(), e);
            result.error("SETUP_ERROR", "Unexpected error during setup: " + e.getMessage(), null);
        }
    }

    private void saveAudioToWav(Context context, short[] audioData) throws Exception {
        File audioFile = new File(context.getFilesDir(), AUDIO_FILE);
        Log.d(TAG, "Saving WAV file to: " + audioFile.getAbsolutePath());
        try (FileOutputStream fos = new FileOutputStream(audioFile);
             DataOutputStream dos = new DataOutputStream(fos)) {
            int byteRate = SAMPLE_RATE * 2;
            int dataSize = audioData.length * 2;

            dos.writeBytes("RIFF");
            dos.writeInt(Integer.reverseBytes(36 + dataSize));
            dos.writeBytes("WAVE");
            dos.writeBytes("fmt ");
            dos.writeInt(Integer.reverseBytes(16));
            dos.writeShort(Short.reverseBytes((short) 1));
            dos.writeShort(Short.reverseBytes((short) 1));
            dos.writeInt(Integer.reverseBytes(SAMPLE_RATE));
            dos.writeInt(Integer.reverseBytes(byteRate));
            dos.writeShort(Short.reverseBytes((short) 2));
            dos.writeShort(Short.reverseBytes((short) 16));
            dos.writeBytes("data");
            dos.writeInt(Integer.reverseBytes(dataSize));

            ByteBuffer buffer = ByteBuffer.allocate(dataSize).order(ByteOrder.LITTLE_ENDIAN);
            for (short sample : audioData) {
                buffer.putShort(sample);
            }
            dos.write(buffer.array());
        }
    }

    public boolean verifyVoice(Context context, short[] audioBuffer, MethodChannel.Result result) {
        if (speakerProfile == null) {
            Log.e(TAG, "No voice profile enrolled");
            result.error("NO_PROFILE", "No voice profile enrolled", null);
            return false;
        }

        if (audioBuffer == null || audioBuffer.length == 0) {
            Log.e(TAG, "Audio buffer is empty or null");
            result.error("INVALID_BUFFER", "Audio buffer is empty or null", null);
            return false;
        }

        try {
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

            Log.d(TAG, "Voice verification score: " + highestScore);
            if (highestScore > 0.6) {
                Log.d(TAG, "Voice matched");
                result.success("Voice matched");
                return true;
            } else {
                Log.d(TAG, "Voice not matched");
                result.success("Voice not matched");
                return false;
            }
        } catch (EagleException e) {
            Log.e(TAG, "Verification error: " + e.getMessage(), e);
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
            File audioFile = new File(context.getFilesDir(), AUDIO_FILE);
            if (audioFile.exists()) {
                audioFile.delete();
            }
            speakerProfile = null;
            if (eagle != null) {
                eagle.delete();
                eagle = null;
            }
            Log.d(TAG, "Enrollment reset successfully");
            result.success("Enrollment reset successfully");
        } catch (Exception e) {
            Log.e(TAG, "Failed to reset enrollment: " + e.getMessage(), e);
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
            Log.d(TAG, "Voice profile saved successfully");
        } catch (Exception e) {
            Log.e(TAG, "Failed to save voice profile: " + e.getMessage(), e);
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
                Log.d(TAG, "Speaker profile loaded successfully");
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to load speaker profile: " + e.getMessage(), e);
        }
    }

    private void stopRecording() {
        isRecording = false;
        if (audioRecord != null) {
            try {
                audioRecord.stop();
                audioRecord.release();
            } catch (Exception e) {
                Log.e(TAG, "Error stopping AudioRecord: " + e.getMessage(), e);
            } finally {
                audioRecord = null;
            }
        }
        if (eagleProfiler != null) {
            try {
                eagleProfiler.delete();
            } catch (Exception e) {
                Log.e(TAG, "Error deleting EagleProfiler: " + e.getMessage(), e);
            } finally {
                eagleProfiler = null;
            }
        }
    }

    private void runOnUiThread(Runnable runnable) {
        new Handler(Looper.getMainLooper()).post(runnable);
    }
}
