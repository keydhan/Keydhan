#!/usr/bin/env bash
set -euo pipefail

APP="android/app"
PKG="$APP/src/main/java/com/keydhan/app"
mkdir -p "$PKG"

# CameraX + location dependencies
python3 - <<'PY'
from pathlib import Path
p=Path("android/app/build.gradle")
s=p.read_text()
needle="dependencies {"
if needle not in s:
    raise SystemExit("Could not find app dependencies block")
deps='''dependencies {
    implementation "androidx.activity:activity:1.10.1"\n    implementation "androidx.camera:camera-core:1.4.2"
    implementation "androidx.camera:camera-camera2:1.4.2"
    implementation "androidx.camera:camera-lifecycle:1.4.2"
    implementation "androidx.camera:camera-view:1.4.2"
    implementation "com.google.android.gms:play-services-location:21.3.0"
'''
s=s.replace(needle,deps,1)
p.write_text(s)
PY

cat > "$APP/src/main/AndroidManifest.xml.tmp" <<'EOF'
EOF
python3 - <<'PY'
from pathlib import Path
p=Path("android/app/src/main/AndroidManifest.xml")
s=p.read_text()
marker="<application"
perms='''    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
'''
if "android.permission.CAMERA" not in s:
    s=s.replace(marker,perms+marker,1)
activity='''        <activity
            android:name="com.keydhan.app.GpsCameraActivity"
            android:exported="false"
            android:screenOrientation="portrait"
            android:theme="@android:style/Theme.Material.Light.NoActionBar" />
'''
if "GpsCameraActivity" not in s:
    s=s.replace("</application>",activity+"</application>")
p.write_text(s)
PY
rm -f "$APP/src/main/AndroidManifest.xml.tmp"

cat > "$PKG/MainActivity.java" <<'EOF'
package com.keydhan.app;

import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        TextView gpsButton = new TextView(this);
        gpsButton.setText("⌖  GPS Camera");
        gpsButton.setTextColor(Color.WHITE);
        gpsButton.setTextSize(14);
        gpsButton.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        gpsButton.setGravity(Gravity.CENTER);
        gpsButton.setPadding(22, 14, 22, 14);
        gpsButton.setBackgroundColor(Color.rgb(10, 40, 88));
        gpsButton.setElevation(12f);
        gpsButton.setOnClickListener(v ->
            startActivity(new Intent(MainActivity.this, GpsCameraActivity.class))
        );
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM | Gravity.END
        );
        params.setMargins(0, 0, 18, 96);
        addContentView(gpsButton, params);
    }
}
EOF

cat > "$PKG/GpsCameraActivity.java" <<'EOF'
package com.keydhan.app;

import android.Manifest;
import androidx.activity.ComponentActivity;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.drawable.GradientDrawable;
import androidx.core.view.WindowCompat;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.net.Uri;
import android.os.Bundle;
import android.os.Looper;
import android.provider.MediaStore;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationCallback;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.google.common.util.concurrent.ListenableFuture;
import java.io.File;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class GpsCameraActivity extends ComponentActivity {
    private static final int REQUEST_PERMISSIONS = 410;
    private static final int NAVY = 0xFF071228;
    private static final int GOLD = 0xFFD2A952;
    private PreviewView previewView;
    private TextView status;
    private ImageCapture imageCapture;
    private FusedLocationProviderClient locationClient;
    private Location latestLocation;
    private LocationCallback locationCallback;
    private Button captureButton, rearButton, frontButton, flashButton;
    private ProcessCameraProvider cameraProvider;
    private Camera activeCamera;
    private Preview cameraPreview;
    private boolean useFrontCamera = false, flashOn = false;
    private File pendingPhoto;
    private Uri lastSavedUri;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(NAVY);
        getWindow().setNavigationBarColor(NAVY);
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        locationClient = LocationServices.getFusedLocationProviderClient(this);
        buildCameraUi();
        if (hasPermissions()) startCameraAndLocation();
        else ActivityCompat.requestPermissions(this,
            new String[]{Manifest.permission.CAMERA, Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION}, REQUEST_PERMISSIONS);
    }

    private TextView text(String value, int size, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(value); t.setTextSize(size); t.setTextColor(color);
        if (bold) t.setTypeface(null, android.graphics.Typeface.BOLD);
        return t;
    }
    private GradientDrawable shape(int color, int strokeColor, int radius) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color); d.setCornerRadius(radius * getResources().getDisplayMetrics().density);
        if (strokeColor != 0) d.setStroke((int)(1.2f * getResources().getDisplayMetrics().density), strokeColor);
        return d;
    }
    private Button button(String value) {
        Button b = new Button(this); b.setText(value); b.setTextColor(Color.WHITE);
        b.setAllCaps(false); b.setTextSize(13); b.setElevation(0);
        b.setBackground(shape(0xCC172640, GOLD, 18));
        b.setPadding(12, 4, 12, 4);
        return b;
    }
    private TextView iconControl(String label, String description) {
        TextView v = text(label, 21, Color.WHITE, true);
        v.setGravity(Gravity.CENTER);
        v.setContentDescription(description);
        v.setBackground(shape(0xAA172640, GOLD, 28));
        return v;
    }
    private TextView cameraModeLabel;
    private TextView zoomLabel;
    private float zoomRatio = 1.0f;
    private String currentAddress = "Getting address…";

    private void buildCameraUi() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        previewView = new PreviewView(this);
        previewView.setScaleType(PreviewView.ScaleType.FILL_CENTER);
        root.addView(previewView, new FrameLayout.LayoutParams(-1, -1));

        // Premium compact header. Window insets are applied below so controls never sit under system icons.
        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(14, 8, 14, 8);
        header.setBackground(shape(0xE8071228, GOLD, 22));
        TextView exit = iconControl("‹", "Exit GPS Camera");
        exit.setTextSize(34);
        exit.setOnClickListener(v -> finish());
        header.addView(exit, new LinearLayout.LayoutParams(46, 46));

        LinearLayout brand = new LinearLayout(this);
        brand.setOrientation(LinearLayout.VERTICAL);
        brand.setGravity(Gravity.CENTER);
        TextView title = text("KeyDhan™", 22, Color.WHITE, true);
        title.setGravity(Gravity.CENTER);
        TextView subtitle = text("⌖  GPS CAMERA", 11, GOLD, true);
        subtitle.setGravity(Gravity.CENTER);
        brand.addView(title);
        brand.addView(subtitle);
        header.addView(brand, new LinearLayout.LayoutParams(0, -2, 1));

        flashButton = button("⚡");
        flashButton.setTextSize(19);
        flashButton.setContentDescription("Toggle flash");
        flashButton.setOnClickListener(v -> toggleFlash());
        header.addView(flashButton, new LinearLayout.LayoutParams(48, 46));
        TextView settings = iconControl("⚙", "Camera settings");
        settings.setTextSize(20);
        settings.setOnClickListener(v -> new android.app.AlertDialog.Builder(this)
            .setTitle("GPS Camera Settings")
            .setItems(new String[]{"Flash: " + (flashOn ? "On" : "Off"), "Photo quality: High", "GPS watermark: On"},
                (dialog, which) -> {
                    if (which == 0) toggleFlash();
                    else Toast.makeText(this, which == 1 ? "High photo quality is enabled." : "GPS watermark is enabled.", Toast.LENGTH_SHORT).show();
                }).show());
        LinearLayout.LayoutParams settingsLp = new LinearLayout.LayoutParams(46, 46);
        settingsLp.leftMargin = 7;
        header.addView(settings, settingsLp);
        FrameLayout.LayoutParams headerParams = new FrameLayout.LayoutParams(-1, -2, Gravity.TOP);
        headerParams.leftMargin = 10; headerParams.rightMargin = 10;
        root.addView(header, headerParams);

        // Right floating camera rail: one circular flip control, zoom controls beneath it.
        LinearLayout rail = new LinearLayout(this);
        rail.setOrientation(LinearLayout.VERTICAL);
        rail.setGravity(Gravity.CENTER);
        rail.setPadding(7, 10, 7, 10);
        rail.setBackground(shape(0xD9071228, GOLD, 28));
        TextView flip = iconControl("⟳", "Switch front and rear camera");
        flip.setTextSize(31);
        flip.setOnClickListener(v -> selectCamera(!useFrontCamera));
        rail.addView(flip, new LinearLayout.LayoutParams(58, 58));
        cameraModeLabel = text("REAR", 9, GOLD, true);
        cameraModeLabel.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams modeLp = new LinearLayout.LayoutParams(-1, 22);
        modeLp.topMargin = 2; modeLp.bottomMargin = 7;
        rail.addView(cameraModeLabel, modeLp);
        Button zoomIn = button("+"); zoomIn.setTextSize(22);
        Button zoomOut = button("−"); zoomOut.setTextSize(22);
        zoomLabel = text("1.0×", 12, NAVY, true);
        zoomLabel.setGravity(Gravity.CENTER);
        zoomLabel.setBackground(shape(GOLD, 0, 16));
        rail.addView(zoomIn, new LinearLayout.LayoutParams(48, 44));
        LinearLayout.LayoutParams zlp = new LinearLayout.LayoutParams(48, 28);
        zlp.topMargin = 3; zlp.bottomMargin = 3;
        rail.addView(zoomLabel, zlp);
        rail.addView(zoomOut, new LinearLayout.LayoutParams(48, 44));
        zoomIn.setOnClickListener(v -> changeZoom(0.5f));
        zoomOut.setOnClickListener(v -> changeZoom(-0.5f));
        FrameLayout.LayoutParams railParams = new FrameLayout.LayoutParams(-2, -2, Gravity.END | Gravity.CENTER_VERTICAL);
        railParams.rightMargin = 9;
        root.addView(rail, railParams);

        // GPS information card, address is shown on a second line when available.
        LinearLayout gpsCard = new LinearLayout(this);
        gpsCard.setOrientation(LinearLayout.VERTICAL);
        gpsCard.setPadding(14, 10, 14, 10);
        gpsCard.setBackground(shape(0xF0071228, GOLD, 22));
        status = text("●  GPS SEARCHING…", 12, 0xFF55E69A, true);
        gpsCard.addView(status);
        TextView addressLine = text(currentAddress, 10, Color.WHITE, false);
        addressLine.setTag("gps_address");
        LinearLayout.LayoutParams addrLp = new LinearLayout.LayoutParams(-1, -2);
        addrLp.topMargin = 5;
        gpsCard.addView(addressLine, addrLp);
        FrameLayout.LayoutParams gpsParams = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
        gpsParams.leftMargin = 14; gpsParams.rightMargin = 14;
        gpsParams.bottomMargin = 174;
        root.addView(gpsCard, gpsParams);

        // Bottom dock: Gallery, one large shutter, GPS Photo. No duplicate front/rear selectors.
        LinearLayout bottom = new LinearLayout(this);
        bottom.setGravity(Gravity.CENTER_VERTICAL);
        bottom.setPadding(18, 12, 18, 12);
        bottom.setBackground(shape(0xF5071228, GOLD, 30));

        TextView gallery = text("▣\nGALLERY", 11, GOLD, true);
        gallery.setGravity(Gravity.CENTER);
        gallery.setOnClickListener(v -> openGallery());
        bottom.addView(gallery, new LinearLayout.LayoutParams(0, 68, 1));

        captureButton = new Button(this);
        captureButton.setText("●");
        captureButton.setTextSize(30);
        captureButton.setTextColor(NAVY);
        captureButton.setGravity(Gravity.CENTER);
        captureButton.setAllCaps(false);
        captureButton.setContentDescription("Capture GPS photo");
        GradientDrawable shutter = new GradientDrawable();
        shutter.setShape(GradientDrawable.OVAL);
        shutter.setColor(0xFFFFD76A);
        shutter.setStroke((int)(5 * getResources().getDisplayMetrics().density), Color.WHITE);
        captureButton.setBackground(shutter);
        captureButton.setElevation(8);
        bottom.addView(captureButton, new LinearLayout.LayoutParams(82, 82));

        TextView gpsPhoto = text("⌖\nGPS PHOTO", 11, GOLD, true);
        gpsPhoto.setGravity(Gravity.CENTER);
        gpsPhoto.setOnClickListener(v -> openGallery());
        bottom.addView(gpsPhoto, new LinearLayout.LayoutParams(0, 68, 1));
        captureButton.setOnClickListener(v -> capturePhoto());
        captureButton.setEnabled(false);

        FrameLayout.LayoutParams bottomParams = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
        bottomParams.leftMargin = 10; bottomParams.rightMargin = 10;
        bottomParams.bottomMargin = 8;
        root.addView(bottom, bottomParams);

        ViewCompat.setOnApplyWindowInsetsListener(root, (view, windowInsets) -> {
            androidx.core.graphics.Insets bars = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars());
            headerParams.topMargin = bars.top + (int)(8 * getResources().getDisplayMetrics().density);
            bottomParams.bottomMargin = bars.bottom + (int)(8 * getResources().getDisplayMetrics().density);
            header.setLayoutParams(headerParams);
            bottom.setLayoutParams(bottomParams);
            gpsParams.bottomMargin = bars.bottom + (int)(174 * getResources().getDisplayMetrics().density);
            gpsCard.setLayoutParams(gpsParams);
            return windowInsets;
        });
        setContentView(root);
        ViewCompat.requestApplyInsets(root);
    }

    private void openGallery() {
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setType("image/*");
            intent.setData(MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
            startActivity(intent);
        } catch (Exception e) {
            Toast.makeText(this, "Gallery is not available.", Toast.LENGTH_SHORT).show();
        }
    }

    private void changeZoom(float delta) {
        if (activeCamera == null) return;
        try {
            androidx.camera.core.ZoomState state = activeCamera.getCameraInfo().getZoomState().getValue();
            if (state == null) return;
            zoomRatio = Math.max(state.getMinZoomRatio(), Math.min(state.getMaxZoomRatio(), zoomRatio + delta));
            activeCamera.getCameraControl().setZoomRatio(zoomRatio);
            if (zoomLabel != null) zoomLabel.setText(String.format(Locale.US, "%.1f×", zoomRatio));
        } catch (Exception e) {
            Toast.makeText(this, "Zoom is not supported by this camera.", Toast.LENGTH_SHORT).show();
        }
    }

    private void updateCameraChoice() {
        if (cameraModeLabel != null) cameraModeLabel.setText(useFrontCamera ? "FRONT" : "REAR");
        zoomRatio = 1.0f;
        if (zoomLabel != null) zoomLabel.setText("1.0×");
    }

    private boolean hasPermissions() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
            && ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }
    @Override public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] results) {
        super.onRequestPermissionsResult(requestCode, permissions, results);
        if (requestCode == REQUEST_PERMISSIONS) {
            if (hasPermissions()) startCameraAndLocation();
            else { Toast.makeText(this, "Camera and precise location permissions are required.", Toast.LENGTH_LONG).show(); finish(); }
        }
    }
    private void startCameraAndLocation() {
        ListenableFuture<ProcessCameraProvider> future = ProcessCameraProvider.getInstance(this);
        future.addListener(() -> {
            try {
                cameraProvider = future.get();
                cameraPreview = new Preview.Builder().build();
                cameraPreview.setSurfaceProvider(previewView.getSurfaceProvider());
                imageCapture = new ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build();
                bindSelectedCamera();
            } catch (Exception e) { Toast.makeText(this, "Unable to start camera: " + e.getMessage(), Toast.LENGTH_LONG).show(); }
        }, ContextCompat.getMainExecutor(this));
        LocationRequest request = new LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1500)
            .setMinUpdateIntervalMillis(1000).build();
        locationCallback = new LocationCallback() {
            @Override public void onLocationResult(@NonNull LocationResult result) {
                if (result.getLastLocation() != null) setGps(result.getLastLocation());
            }
        };
        try {
            locationClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper());
            locationClient.getLastLocation().addOnSuccessListener(location -> { if (location != null) setGps(location); });
        } catch (SecurityException e) { status.setText("Enable precise location permission."); }
    }
    private void setGps(Location location) {
        latestLocation = location;
        float accuracy = location.hasAccuracy() ? location.getAccuracy() : -1;
        status.setText(String.format(Locale.US, "● GPS READY  •  %.6f, %.6f  •  ±%.0fm",
            location.getLatitude(), location.getLongitude(), Math.max(0, accuracy)));
        captureButton.setEnabled(imageCapture != null);
        new Thread(() -> {
            String address = getAddress(location);
            runOnUiThread(() -> {
                currentAddress = address;
                View root = findViewById(android.R.id.content);
                if (root != null) {
                    TextView addressView = root.findViewWithTag("gps_address");
                    if (addressView != null) addressView.setText("⌖  " + address);
                }
            });
        }).start();
    }
    private void bindSelectedCamera() {
        if (cameraProvider == null || cameraPreview == null || imageCapture == null) return;
        CameraSelector selector = useFrontCamera ? CameraSelector.DEFAULT_FRONT_CAMERA : CameraSelector.DEFAULT_BACK_CAMERA;
        try {
            if (!cameraProvider.hasCamera(selector)) {
                Toast.makeText(this, "Selected camera is not available on this phone.", Toast.LENGTH_SHORT).show();
                useFrontCamera = !useFrontCamera; updateCameraChoice(); return;
            }
            cameraProvider.unbindAll();
            activeCamera = cameraProvider.bindToLifecycle(this, selector, cameraPreview, imageCapture);
            syncFlashControl();
            updateCameraChoice();
        } catch (Exception e) { Toast.makeText(this, "Camera switch failed: " + e.getMessage(), Toast.LENGTH_LONG).show(); }
    }
    private void selectCamera(boolean front) {
        if (useFrontCamera == front) return;
        useFrontCamera = front;
        flashOn = false;
        zoomRatio = 1.0f;
        bindSelectedCamera();
    }
    private void syncFlashControl() {
        boolean available = activeCamera != null && activeCamera.getCameraInfo().hasFlashUnit() && !useFrontCamera;
        flashButton.setEnabled(true);
        flashButton.setAlpha(1f);
        flashButton.setText(available ? (flashOn ? "⚡" : "⚡") : "⚡");
        if (!available) flashOn = false;
        if (available) activeCamera.getCameraControl().enableTorch(flashOn);
    }
    private void toggleFlash() {
        if (activeCamera == null) {
            Toast.makeText(this, "Camera is still starting. Please wait.", Toast.LENGTH_SHORT).show();
            return;
        }
        if (useFrontCamera || !activeCamera.getCameraInfo().hasFlashUnit()) {
            flashOn = false;
            syncFlashControl();
            Toast.makeText(this, "Flash is available only on the rear camera on this phone.", Toast.LENGTH_SHORT).show();
            return;
        }
        final boolean requested = !flashOn;
        flashButton.setEnabled(false);
        activeCamera.getCameraControl().enableTorch(requested).addListener(() -> runOnUiThread(() -> {
            flashOn = requested;
            syncFlashControl();
        }), ContextCompat.getMainExecutor(this));
    }
    private void capturePhoto() {
        if (imageCapture == null || latestLocation == null) {
            Toast.makeText(this, "Waiting for GPS fix. Please try again in an open area.", Toast.LENGTH_LONG).show(); return;
        }
        captureButton.setEnabled(false);
        File raw = new File(getCacheDir(), "gps-raw-" + System.currentTimeMillis() + ".jpg");
        ImageCapture.OutputFileOptions options = new ImageCapture.OutputFileOptions.Builder(raw).build();
        imageCapture.takePicture(options, ContextCompat.getMainExecutor(this), new ImageCapture.OnImageSavedCallback() {
            @Override public void onImageSaved(@NonNull ImageCapture.OutputFileResults result) {
                Location captured = new Location(latestLocation);
                new Thread(() -> createPreviewImage(raw, captured)).start();
            }
            @Override public void onError(@NonNull ImageCaptureException error) {
                captureButton.setEnabled(true);
                Toast.makeText(GpsCameraActivity.this, "Photo failed: " + error.getMessage(), Toast.LENGTH_LONG).show();
            }
        });
    }
    private void createPreviewImage(File raw, Location loc) {
        Bitmap original = BitmapFactory.decodeFile(raw.getAbsolutePath());
        if (original == null) { runOnUiThread(() -> captureButton.setEnabled(true)); return; }
        Bitmap marked = original.copy(Bitmap.Config.ARGB_8888, true); original.recycle();
        String address = getAddress(loc);
        String date = new SimpleDateFormat("dd MMM yyyy, hh:mm a", Locale.getDefault()).format(new Date());
        Canvas canvas = new Canvas(marked);
        float scale = Math.max(1f, marked.getWidth() / 1080f), pad = 24f * scale, line = 34f * scale;
        float boxHeight = pad * 2.25f + line * 4.25f, top = marked.getHeight() - boxHeight - pad;
        Paint bg = new Paint(Paint.ANTI_ALIAS_FLAG); bg.setColor(0xE6101D33);
        canvas.drawRoundRect(pad, top, marked.getWidth()-pad, marked.getHeight()-pad, 22f*scale, 22f*scale, bg);
        Paint gold = new Paint(Paint.ANTI_ALIAS_FLAG); gold.setColor(GOLD);
        canvas.drawRoundRect(pad, top, pad+7f*scale, marked.getHeight()-pad, 4f*scale, 4f*scale, gold);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG); p.setColor(Color.WHITE); p.setTextSize(25f*scale); p.setFakeBoldText(true);
        float x=pad*1.8f, y=top+pad*1.25f+line*0.55f;
        canvas.drawText("KEYDHAN™  GPS PHOTO",x,y,p);
        p.setColor(0xFFE7C270); p.setTextSize(16f*scale); y+=line*0.72f;
        canvas.drawText("LIVE LOCATION  •  GPS ACCURACY",x,y,p);
        p.setColor(Color.WHITE); p.setFakeBoldText(false); p.setTextSize(19f*scale); y+=line*1.05f;
        canvas.drawText(String.format(Locale.US,"LAT  %.6f     LONG  %.6f",loc.getLatitude(),loc.getLongitude()),x,y,p);
        y+=line; canvas.drawText(trim(address,72),x,y,p);
        y+=line; p.setColor(0xFFE1E7F0); canvas.drawText(date,x,y,p);
        pendingPhoto = new File(getCacheDir(),"keydhan-preview-"+System.currentTimeMillis()+".jpg");
        try (OutputStream out = new java.io.FileOutputStream(pendingPhoto)) {
            marked.compress(Bitmap.CompressFormat.JPEG,94,out);
        } catch (Exception e) { pendingPhoto = null; }
        marked.recycle(); raw.delete();
        runOnUiThread(() -> {
            captureButton.setEnabled(true);
            if (pendingPhoto != null) showPhotoPreview();
            else Toast.makeText(this,"Could not prepare photo preview.",Toast.LENGTH_LONG).show();
        });
    }
    private void showPhotoPreview() {
        if (pendingPhoto == null || !pendingPhoto.exists()) return;
        FrameLayout root = new FrameLayout(this); root.setBackgroundColor(Color.BLACK);
        ImageView image = new ImageView(this); image.setImageURI(Uri.fromFile(pendingPhoto));
        image.setScaleType(ImageView.ScaleType.FIT_CENTER);
        root.addView(image,new FrameLayout.LayoutParams(-1,-1));
        LinearLayout panel = new LinearLayout(this); panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(14,12,14,14); panel.setBackgroundColor(0xEE071228);
        panel.addView(text("✓  PHOTO PREVIEW",16,GOLD,true));
        panel.addView(text("Check your GPS watermark before saving.",12,Color.WHITE,false));
        LinearLayout actions = new LinearLayout(this); actions.setGravity(Gravity.CENTER);
        Button retake = button("↻  Retake"), save = button("✓  Save"), share = button("↗  Share");
        retake.setTextSize(12); save.setTextSize(12); share.setTextSize(12);
        actions.addView(retake,new LinearLayout.LayoutParams(0,-2,1));
        actions.addView(save,new LinearLayout.LayoutParams(0,-2,1));
        actions.addView(share,new LinearLayout.LayoutParams(0,-2,1));
        panel.addView(actions);
        root.addView(panel,new FrameLayout.LayoutParams(-1,-2,Gravity.BOTTOM));
        setContentView(root);
        retake.setOnClickListener(v -> {
            if (pendingPhoto != null) pendingPhoto.delete();
            pendingPhoto = null; buildCameraUi();
            if (cameraProvider != null) bindSelectedCamera();
        });
        save.setOnClickListener(v -> savePendingPhoto(false));
        share.setOnClickListener(v -> savePendingPhoto(true));
    }
    private void savePendingPhoto(boolean shareAfter) {
        if (pendingPhoto == null || !pendingPhoto.exists()) return;
        try {
            String name="KeyDhan_GPS_"+new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date())+".jpg";
            ContentValues values=new ContentValues();
            values.put(MediaStore.Images.Media.DISPLAY_NAME,name);
            values.put(MediaStore.Images.Media.MIME_TYPE,"image/jpeg");
            values.put(MediaStore.Images.Media.RELATIVE_PATH,"Pictures/KeyDhan GPS Camera");
            values.put(MediaStore.Images.Media.IS_PENDING,1);
            Uri uri=getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,values);
            if(uri==null) throw new Exception("Could not create gallery photo");
            try(OutputStream out=getContentResolver().openOutputStream(uri);
                java.io.FileInputStream in=new java.io.FileInputStream(pendingPhoto)) {
                byte[] buffer=new byte[8192]; int n;
                while((n=in.read(buffer))>0) out.write(buffer,0,n);
            }
            values.clear(); values.put(MediaStore.Images.Media.IS_PENDING,0);
            getContentResolver().update(uri,values,null,null);
            pendingPhoto.delete(); pendingPhoto=null;
            if(shareAfter) {
                Intent send=new Intent(Intent.ACTION_SEND); send.setType("image/jpeg");
                send.putExtra(Intent.EXTRA_STREAM,uri); send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                startActivity(Intent.createChooser(send,"Share KeyDhan GPS Photo"));
            } else Toast.makeText(this,"Saved to Pictures/KeyDhan GPS Camera",Toast.LENGTH_LONG).show();
            buildCameraUi();
            if(cameraProvider!=null) bindSelectedCamera();
        } catch(Exception e) { Toast.makeText(this,"Save failed: "+e.getMessage(),Toast.LENGTH_LONG).show(); }
    }
    private String getAddress(Location loc) {
        try {
            if(Geocoder.isPresent()) {
                Geocoder geocoder=new Geocoder(this,Locale.getDefault());
                List<Address> list=geocoder.getFromLocation(loc.getLatitude(),loc.getLongitude(),1);
                if(list!=null&&!list.isEmpty()&&list.get(0).getAddressLine(0)!=null) return list.get(0).getAddressLine(0);
            }
        } catch(Exception ignored) {}
        return "Address unavailable";
    }
    private String trim(String s,int max) { if(s==null)return ""; return s.length()<=max?s:s.substring(0,max-1)+"…"; }
    @Override protected void onDestroy() {
        super.onDestroy();
        if(locationClient!=null&&locationCallback!=null) locationClient.removeLocationUpdates(locationCallback);
        if(pendingPhoto!=null&&pendingPhoto.exists()) pendingPhoto.delete();
    }
}
EOF

# Premium KeyDhan black-and-royal-gold camera layout with safe status-bar spacing and circular shutter.
