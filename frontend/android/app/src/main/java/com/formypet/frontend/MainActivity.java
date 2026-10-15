package com.formypet.frontend;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.media.Image;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Surface;
import java.io.File;
import java.nio.ByteBuffer;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.CancellationException;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.List;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private final ExecutorService exportExecutor = Executors.newSingleThreadExecutor();
    private final ConcurrentHashMap<String, AtomicBoolean> exportCancellations = new ConcurrentHashMap<>();
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        final MethodChannel exportChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "com.formypet/pet_log_video_export");
        exportChannel
                .setMethodCallHandler((call, result) -> {
                    if ("openAppSettings".equals(call.method)) {
                        try {
                            startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:" + getPackageName())));
                            result.success(null);
                        } catch (ActivityNotFoundException | SecurityException e) {
                            result.error("settings_unavailable", "App settings are unavailable", null);
                        }
                        return;
                    }
                    if ("cancel".equals(call.method)) {
                        String requestId = call.argument("requestId");
                        if (requestId != null) {
                            AtomicBoolean active = exportCancellations.get(requestId);
                            if (active != null) active.set(true);
                        }
                        result.success(null);
                        return;
                    }
                    if (!"create".equals(call.method)) { result.notImplemented(); return; }
                    List<String> paths = call.argument("imagePaths");
                    String output = call.argument("outputPath");
                    String requestId = call.argument("requestId");
                    if (paths == null || paths.isEmpty() || output == null || requestId == null) { result.error("invalid_args", "Photos, output path, and request ID are required", null); return; }
                    AtomicBoolean cancellation = exportCancellations.computeIfAbsent(requestId, ignored -> new AtomicBoolean());
                    exportExecutor.execute(() -> {
                        try {
                            encodePetLogVideo(paths, output, cancellation, (completed, total) -> {
                                java.util.Map<String, Object> event = new java.util.HashMap<>();
                                event.put("requestId", requestId);
                                event.put("completedFrames", completed);
                                event.put("totalFrames", total);
                                runOnUiThread(() -> {
                                    if (!cancellation.get()) exportChannel.invokeMethod("progress", event);
                                });
                            });
                            runOnUiThread(() -> {
                                result.success(output);
                                exportCancellations.remove(requestId, cancellation);
                            });
                        } catch (Exception e) {
                            new File(output).delete();
                            runOnUiThread(() -> {
                                result.error("encode_failed", e.getMessage(), null);
                                exportCancellations.remove(requestId, cancellation);
                            });
                        }
                    });
                });
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "com.formypet/public_web")
                .setMethodCallHandler((call, result) -> {
                    if (!"open".equals(call.method) || !(call.arguments instanceof String)) {
                        result.notImplemented();
                        return;
                    }
                    Uri uri = Uri.parse((String) call.arguments);
                    if (!"https".equals(uri.getScheme()) || uri.getHost() == null) {
                        result.success(false);
                        return;
                    }
                    try {
                        startActivity(new Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE));
                        result.success(true);
                    } catch (ActivityNotFoundException | SecurityException ignored) { result.success(false); }
                });
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

    private interface ExportProgress { void report(int completed, int total); }

    private static final class WrittenFrames {
        final int total;
        int completed = 0;
        int percent = -1;
        final ExportProgress progress;
        WrittenFrames(int total, ExportProgress progress) { this.total = total; this.progress = progress; }
        void wrote() {
            completed++;
            int next = Math.min(99, completed * 100 / total);
            if (next != percent) { percent = next; progress.report(completed, total); }
        }
    }

    private void encodePetLogVideo(List<String> paths, String output, AtomicBoolean cancellation, ExportProgress progress) throws Exception {
        Bitmap first = BitmapFactory.decodeFile(paths.get(0));
        if (first == null) throw new IllegalArgumentException("A photo could not be decoded");
        int[] frameSize = PetLogVideoFrameSize.fromSource(first.getWidth(), first.getHeight());
        int width = frameSize[0];
        int height = frameSize[1];
        first.recycle();
        final int fps = 10;
        final WrittenFrames written = new WrittenFrames(paths.size() * fps * 3, progress);
        MediaFormat format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height);
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible);
        format.setInteger(MediaFormat.KEY_BIT_RATE, 4_000_000);
        format.setInteger(MediaFormat.KEY_FRAME_RATE, fps);
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2);
        MediaCodec codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
        MuxerOutput outputState = null;
        try {
            outputState = new MuxerOutput(output, written);
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
            codec.start();
            long pts = 0;
            for (String path : paths) {
                if (cancellation.get()) throw new CancellationException("Video export cancelled");
                Bitmap bitmap = BitmapFactory.decodeFile(path);
                if (bitmap == null) throw new IllegalArgumentException("A photo could not be decoded");
                Bitmap frame = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                Canvas canvas = new Canvas(frame);
                canvas.drawColor(Color.BLACK);
                float scale = Math.min((float) width / bitmap.getWidth(), (float) height / bitmap.getHeight());
                float w = bitmap.getWidth() * scale, h = bitmap.getHeight() * scale;
                canvas.drawBitmap(bitmap, null,
                        new android.graphics.RectF((width-w)/2, (height-h)/2, (width+w)/2, (height+h)/2),
                        new Paint(Paint.FILTER_BITMAP_FLAG));
                bitmap.recycle();
                int[] pixels = new int[width * height];
                frame.getPixels(pixels, 0, width, 0, 0, width, height);
                frame.recycle();
                for (int f = 0; f < fps * 3; f++) {
                    int input = awaitInput(codec, outputState, cancellation);
                    Image inputImage = codec.getInputImage(input);
                    if (inputImage == null) throw new IllegalStateException("Video encoder did not provide a YUV input image");
                    try {
                        Image.Plane[] planes = inputImage.getPlanes();
                        Yuv420PlaneWriter.write(
                                pixels, width, height,
                                planes[0].getBuffer(), planes[0].getRowStride(), planes[0].getPixelStride(),
                                planes[1].getBuffer(), planes[1].getRowStride(), planes[1].getPixelStride(),
                                planes[2].getBuffer(), planes[2].getRowStride(), planes[2].getPixelStride());
                    } finally {
                        inputImage.close();
                    }
                    codec.queueInputBuffer(input, 0, width * height * 3 / 2, pts, 0);
                    pts += 1_000_000L / fps;
                    outputState.drain(codec, 0);
                }
            }
            int input = awaitInput(codec, outputState, cancellation);
            codec.queueInputBuffer(input, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
            long deadline = android.os.SystemClock.elapsedRealtime() + 30000;
            while (!outputState.ended) {
                if (cancellation.get()) throw new CancellationException("Video export cancelled");
                if (android.os.SystemClock.elapsedRealtime() > deadline) throw new IllegalStateException("Encoder did not finish");
                outputState.drain(codec, 10000);
            }
            if (cancellation.get()) throw new CancellationException("Video export cancelled");
            if (!outputState.started || written.completed != written.total) throw new IllegalStateException("Video is incomplete");
            // Finalization is part of success; do not swallow stop failures here.
            outputState.muxer.stop();
            outputState.started = false;
            if (new File(output).length() == 0) throw new IllegalStateException("Video file is empty");
        } finally {
            try { codec.stop(); } catch (Exception ignored) {}
            try { codec.release(); }
            finally { if (outputState != null) outputState.release(); }
        }
    }

    private int awaitInput(MediaCodec codec, MuxerOutput output, AtomicBoolean cancellation) {
        long deadline = android.os.SystemClock.elapsedRealtime() + 30000;
        while (true) {
            if (cancellation.get()) throw new CancellationException("Video export cancelled");
            int input = codec.dequeueInputBuffer(10000);
            if (input >= 0) return input;
            // Backpressure is normal: free output buffers before waiting for more input.
            output.drain(codec, 10000);
            if (android.os.SystemClock.elapsedRealtime() > deadline) throw new IllegalStateException("Video encoder stalled");
        }
    }

    private static final class MuxerOutput {
        final MediaMuxer muxer;
        final WrittenFrames written;
        final MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
        int track = -1;
        boolean started;
        boolean ended;

        MuxerOutput(String path, WrittenFrames written) throws java.io.IOException {
            muxer = new MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            this.written = written;
        }

        void drain(MediaCodec codec, long timeoutUs) {
            while (!ended) {
                int index = codec.dequeueOutputBuffer(info, timeoutUs);
                if (index == MediaCodec.INFO_TRY_AGAIN_LATER) return;
                if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    if (started) throw new IllegalStateException("Encoder format changed twice");
                    track = muxer.addTrack(codec.getOutputFormat());
                    muxer.start();
                    started = true;
                } else if (index >= 0) {
                    try {
                        if (info.size > 0 && (info.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                            if (!started) throw new IllegalStateException("Encoder produced data before format");
                            ByteBuffer encoded = codec.getOutputBuffer(index);
                            if (encoded == null) throw new IllegalStateException("Missing encoded frame");
                            encoded.position(info.offset);
                            encoded.limit(info.offset + info.size);
                            muxer.writeSampleData(track, encoded, info);
                            written.wrote();
                        }
                        ended = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
                    } finally {
                        codec.releaseOutputBuffer(index, false);
                    }
                }
                timeoutUs = 0;
            }
        }

        void release() {
            if (started) { try { muxer.stop(); } catch (Exception ignored) {} }
            muxer.release();
        }
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
