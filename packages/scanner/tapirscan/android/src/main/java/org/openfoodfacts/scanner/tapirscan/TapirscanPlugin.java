package org.openfoodfacts.scanner.tapirscan;

import android.os.Handler;
import android.os.Looper;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import java.util.EnumSet;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.tapirscan.android.Format;
import org.tapirscan.android.Mode;
import org.tapirscan.android.Scanner;
import org.tapirscan.android.ScannerOptions;

/** Decodes camera frames with Tapirscan. One serial executor owns all native scanners. */
public final class TapirscanPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private ExecutorService executor;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Map<Integer, Scanner> scanners = new HashMap<>();
    private int nextId = 1;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        executor = Executors.newSingleThreadExecutor();
        channel = new MethodChannel(binding.getBinaryMessenger(), "org.openfoodfacts/tapirscan");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        executor.execute(() -> {
            try {
                Object response;
                switch (call.method) {
                    case "create":
                        response = create();
                        break;
                    case "scan":
                        response = scan(call);
                        break;
                    case "dispose":
                        dispose(call);
                        response = null;
                        break;
                    default:
                        main.post(result::notImplemented);
                        return;
                }
                main.post(() -> result.success(response));
            } catch (Exception | LinkageError failure) {
                String message = failure.getMessage() != null ? failure.getMessage() : failure.toString();
                main.post(() -> result.error("tapirscan", message, null));
            }
        });
    }

    /** Same formats as the ML Kit and ZXing scanners. */
    private int create() {
        Scanner scanner = new Scanner(ScannerOptions.defaults()
            .withMode(Mode.MEDIUM)
            .withFormats(EnumSet.of(
                Format.EAN13, Format.EAN8, Format.UPCA, Format.UPCE,
                Format.CODE39, Format.CODE93, Format.CODE128, Format.ITF,
                Format.QR_CODE, Format.DATA_MATRIX)));
        int id = nextId++;
        scanners.put(id, scanner);
        return id;
    }

    /** Reads a grayscale frame; {@code stride} is bytes per row, 0 for packed rows. */
    private Object scan(MethodCall call) {
        Number id = call.argument("id");
        Number width = call.argument("width");
        Number height = call.argument("height");
        Number stride = call.argument("stride");
        byte[] bytes = call.argument("bytes");
        if (id == null || width == null || height == null || stride == null || bytes == null) {
            throw new IllegalArgumentException("Missing frame arguments");
        }
        Scanner scanner = scanners.get(id.intValue());
        if (scanner == null) {
            throw new IllegalStateException("Scanner is disposed");
        }
        return scanner.scan(bytes, width.intValue(), height.intValue(), 1, stride.intValue()).values();
    }

    private void dispose(MethodCall call) {
        Number id = call.argument("id");
        if (id == null) {
            throw new IllegalArgumentException("Missing scanner id");
        }
        Scanner scanner = scanners.remove(id.intValue());
        if (scanner != null) {
            scanner.close();
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        executor.execute(() -> {
            for (Scanner scanner : scanners.values()) {
                scanner.close();
            }
            scanners.clear();
        });
        executor.shutdown();
    }
}
