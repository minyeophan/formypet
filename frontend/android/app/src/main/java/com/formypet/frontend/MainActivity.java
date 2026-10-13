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
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "com.formypet/pet_log_video_export")
                .setMethodCallHandler((call, result) -> {
                    if ("cancel".equals(call.method)) {
                        String requestId = call.argument("requestId");
                        if (requestId != null) {
                            exportCancellations.computeIfAbsent(requestId, ignored -> new AtomicBoolean()).set(true);
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
                            encodePetLogVideo(paths, output, cancellation);
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

    private void encodePetLogVideo(List<String> paths, String output, AtomicBoolean cancellation) throws Exception {
        Bitmap first = BitmapFactory.decodeFile(paths.get(0));
        if (first == null) throw new IllegalArgumentException("A photo could not be decoded");
        int[] frameSize = PetLogVideoFrameSize.fromSource(first.getWidth(), first.getHeight());
        int width = frameSize[0];
        int height = frameSize[1];
        first.recycle();
        final int fps = 10;
        MediaFormat format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height);
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible);
        format.setInteger(MediaFormat.KEY_BIT_RATE, 4_000_000);
        format.setInteger(MediaFormat.KEY_FRAME_RATE, fps);
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2);
        MediaCodec codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC);
        MediaMuxer muxer = null;
        boolean muxerStarted = false; int track = -1; long pts = 0;
        try {
            muxer = new MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE); codec.start();
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            for (String path : paths) {
                if (cancellation.get()) throw new CancellationException("Video export cancelled");
                Bitmap bitmap = BitmapFactory.decodeFile(path);
                if (bitmap == null) throw new IllegalArgumentException("A photo could not be decoded");
                Bitmap frame = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                Canvas canvas = new Canvas(frame); canvas.drawColor(Color.BLACK);
                float scale = Math.min((float) width / bitmap.getWidth(), (float) height / bitmap.getHeight());
                float w = bitmap.getWidth() * scale, h = bitmap.getHeight() * scale;
                canvas.drawBitmap(bitmap, null, new android.graphics.RectF((width-w)/2, (height-h)/2, (width+w)/2, (height+h)/2), new Paint(Paint.FILTER_BITMAP_FLAG));
                bitmap.recycle();
                int[] pixels = new int[width * height]; frame.getPixels(pixels, 0, width, 0, 0, width, height); frame.recycle();
                for (int f=0; f<fps*3; f++) {
                    if (cancellation.get()) throw new CancellationException("Video export cancelled");
                    int input = codec.dequeueInputBuffer(10000);
                    if (input < 0) throw new IllegalStateException("Video encoder stalled");
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
                    codec.queueInputBuffer(input, 0, width * height * 3 / 2, pts, 0); pts += 1_000_000L / fps;
                    while (true) {
                        int out = codec.dequeueOutputBuffer(info, 0);
                        if (out == MediaCodec.INFO_TRY_AGAIN_LATER) break;
                        if (out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) { track = muxer.addTrack(codec.getOutputFormat()); muxer.start(); muxerStarted = true; }
                        else if (out >= 0) { ByteBuffer encoded = codec.getOutputBuffer(out); if (info.size > 0 && muxerStarted) { encoded.position(info.offset); encoded.limit(info.offset + info.size); muxer.writeSampleData(track, encoded, info); } codec.releaseOutputBuffer(out, false); }
                    }
                }
            }
            int input = codec.dequeueInputBuffer(10000); if (input < 0) throw new IllegalStateException("Video encoder stalled");
            codec.queueInputBuffer(input, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
            boolean done = false; while (!done) { int out=codec.dequeueOutputBuffer(info,10000); if (out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) { track=muxer.addTrack(codec.getOutputFormat()); muxer.start(); muxerStarted=true; } else if (out>=0) { ByteBuffer encoded=codec.getOutputBuffer(out); if (info.size>0 && muxerStarted) { encoded.position(info.offset); encoded.limit(info.offset+info.size); muxer.writeSampleData(track,encoded,info); } done=(info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM)!=0; codec.releaseOutputBuffer(out,false); } }
        } finally {
            try { codec.stop(); } catch(Exception ignored) {}
            codec.release();
            if (muxer != null) {
                if (muxerStarted) { try { muxer.stop(); } catch(Exception ignored) {} }
                muxer.release();
            }
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
