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
    implementation "com.google.zxing:core:3.5.3"
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
    <uses-permission android:name="android.permission.INTERNET" />
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
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Paint;
import android.graphics.Typeface;
// GPS photo watermark: KeyDhan brand, per-photo map QR, Made in India, optional public IP.
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
import android.graphics.Typeface;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
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
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;
import java.util.HashMap;
import java.util.Map;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.common.BitMatrix;

public class GpsCameraActivity extends ComponentActivity {
    private static final int REQUEST_PERMISSIONS = 410;
    private static final int NAVY = 0xFF071228;
    private static final int GOLD = 0xFFD2A952;
    private static final String PREFS = "keydhan_gps_camera";
    private static final String PREF_SHOW_IP = "show_public_ip";
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
    private boolean photoPreviewVisible = false;

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
        photoPreviewVisible = false;
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        previewView = new PreviewView(this);
        previewView.setScaleType(PreviewView.ScaleType.FILL_CENTER);
        root.addView(previewView, new FrameLayout.LayoutParams(-1, -1));

        // Premium compact header. Window insets are applied below so controls never sit under system icons.
        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(18, 14, 18, 14);
        header.setBackground(shape(0xE8071228, GOLD, 22));
        View exit = new View(this) {
            private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            @Override protected void onDraw(Canvas canvas) {
                super.onDraw(canvas);
                float d = getResources().getDisplayMetrics().density;
                float cx = getWidth()/2f, cy = getHeight()/2f;
                p.setColor(Color.WHITE); p.setStyle(Paint.Style.STROKE);
                p.setStrokeWidth(2.4f*d); p.setStrokeCap(Paint.Cap.ROUND); p.setStrokeJoin(Paint.Join.ROUND);
                Path a = new Path();
                a.moveTo(cx+9*d,cy); a.lineTo(cx-9*d,cy);
                a.moveTo(cx-9*d,cy); a.lineTo(cx-1*d,cy-7*d);
                a.moveTo(cx-9*d,cy); a.lineTo(cx-1*d,cy+7*d);
                canvas.drawPath(a,p);
            }
        };
        exit.setBackground(shape(0xAA172640, GOLD, 28));
        exit.setContentDescription("Back");
        exit.setOnClickListener(v -> finish());
        header.addView(exit, new LinearLayout.LayoutParams(68, 68));

        LinearLayout brand = new LinearLayout(this);
        brand.setOrientation(LinearLayout.VERTICAL);
        brand.setGravity(Gravity.CENTER);
        TextView title = text("KeyDhan™", 30, Color.WHITE, true);
        title.setGravity(Gravity.CENTER);
        TextView subtitle = text("⌖  GPS CAMERA", 16, GOLD, true);
        subtitle.setGravity(Gravity.CENTER);
        brand.addView(title);
        brand.addView(subtitle);
        header.addView(brand, new LinearLayout.LayoutParams(0, -2, 1));

        flashButton = button("⚡");
        flashButton.setTextSize(19);
        flashButton.setContentDescription("Toggle flash");
        flashButton.setOnClickListener(v -> toggleFlash());
        header.addView(flashButton, new LinearLayout.LayoutParams(62, 62));
        TextView settings = iconControl("⚙", "Camera settings");
        settings.setTextSize(20);
        settings.setOnClickListener(v -> new android.app.AlertDialog.Builder(this)
            .setTitle("GPS Camera Settings")
            .setItems(new String[]{"Flash: " + (flashOn ? "On" : "Off"), "Photo quality: High", "GPS watermark: On", "Show public IP on photo: " + (getPreferences(MODE_PRIVATE).getBoolean(PREF_SHOW_IP, false) ? "On" : "Off")},
                (dialog, which) -> {
                    if (which == 0) toggleFlash();
                    else if (which == 1) Toast.makeText(this, "High photo quality is enabled.", Toast.LENGTH_SHORT).show();
                    else if (which == 2) Toast.makeText(this, "GPS watermark is enabled.", Toast.LENGTH_SHORT).show();
                    else {
                        boolean enabled = !getPreferences(MODE_PRIVATE).getBoolean(PREF_SHOW_IP, false);
                        getPreferences(MODE_PRIVATE).edit().putBoolean(PREF_SHOW_IP, enabled).apply();
                        Toast.makeText(this, "Public IP on photo: " + (enabled ? "On" : "Off"), Toast.LENGTH_SHORT).show();
                    }
                }).show());
        LinearLayout.LayoutParams settingsLp = new LinearLayout.LayoutParams(62, 62);
        settingsLp.leftMargin = 7;
        header.addView(settings, settingsLp);
        FrameLayout.LayoutParams headerParams = new FrameLayout.LayoutParams(-1, -2, Gravity.TOP);
        headerParams.leftMargin = 10; headerParams.rightMargin = 10;
        root.addView(header, headerParams);

        // Right floating camera rail: one circular flip control, zoom controls beneath it.
        LinearLayout rail = new LinearLayout(this);
        rail.setOrientation(LinearLayout.VERTICAL);
        rail.setGravity(Gravity.CENTER);
        rail.setPadding(7, 13, 7, 13);
        rail.setBackground(shape(0xD9071228, GOLD, 28));
        View flip = new View(this) {
            private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            @Override protected void onDraw(Canvas canvas) {
                super.onDraw(canvas);
                float d = getResources().getDisplayMetrics().density;
                float cx = getWidth()/2f, cy = getHeight()/2f;
                p.setColor(Color.WHITE); p.setStyle(Paint.Style.STROKE);
                p.setStrokeWidth(2.3f*d); p.setStrokeCap(Paint.Cap.ROUND); p.setStrokeJoin(Paint.Join.ROUND);
                // Two opposing curved arrows make the camera-switch action unmistakable.
                RectF upper = new RectF(cx-19*d,cy-19*d,cx+19*d,cy+19*d);
                canvas.drawArc(upper,205,125,false,p);
                Path upperTip = new Path();
                upperTip.moveTo(cx-18*d,cy-13*d); upperTip.lineTo(cx-7*d,cy-17*d); upperTip.lineTo(cx-12*d,cy-5*d); upperTip.close();
                p.setStyle(Paint.Style.FILL); canvas.drawPath(upperTip,p);
                p.setStyle(Paint.Style.STROKE);
                canvas.drawArc(upper,25,125,false,p);
                Path lowerTip = new Path();
                lowerTip.moveTo(cx+18*d,cy+13*d); lowerTip.lineTo(cx+7*d,cy+17*d); lowerTip.lineTo(cx+12*d,cy+5*d); lowerTip.close();
                p.setStyle(Paint.Style.FILL); canvas.drawPath(lowerTip,p);
                // Small camera body in the center.
                p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(2.5f*d);
                canvas.drawRoundRect(cx-10*d,cy-7*d,cx+10*d,cy+7*d,2.5f*d,2.5f*d,p);
                canvas.drawCircle(cx,cy,3.2f*d,p);
            }
        };
        flip.setBackground(shape(0xAA172640, GOLD, 28));
        flip.setContentDescription("Switch front and rear camera");
        flip.setOnClickListener(v -> selectCamera(!useFrontCamera));
        rail.addView(flip, new LinearLayout.LayoutParams(74, 74));
        cameraModeLabel = text("REAR", 11, NAVY, true);
        cameraModeLabel.setGravity(Gravity.CENTER);
        cameraModeLabel.setBackground(shape(GOLD, 0, 14));
        LinearLayout.LayoutParams modeLp = new LinearLayout.LayoutParams(76, 32);
        modeLp.topMargin = 8; modeLp.bottomMargin = 9;
        rail.addView(cameraModeLabel, modeLp);
        Button zoomIn = button("+"); zoomIn.setTextSize(24);
        Button zoomOut = button("−"); zoomOut.setTextSize(24);
        zoomLabel = text("1.0×", 12, NAVY, true);
        zoomLabel.setGravity(Gravity.CENTER);
        zoomLabel.setBackground(shape(GOLD, 0, 16));
        rail.addView(zoomIn, new LinearLayout.LayoutParams(76, 60));
        LinearLayout.LayoutParams zlp = new LinearLayout.LayoutParams(76, 40);
        zlp.topMargin = 3; zlp.bottomMargin = 3;
        rail.addView(zoomLabel, zlp);
        rail.addView(zoomOut, new LinearLayout.LayoutParams(76, 60));
        zoomIn.setOnClickListener(v -> changeZoom(0.5f));
        zoomOut.setOnClickListener(v -> changeZoom(-0.5f));
        FrameLayout.LayoutParams railParams = new FrameLayout.LayoutParams(-2, -2, Gravity.END | Gravity.CENTER_VERTICAL);
        railParams.rightMargin = 9;
        root.addView(rail, railParams);

        // GPS information card, address is shown on a second line when available.
        LinearLayout gpsCard = new LinearLayout(this);
        gpsCard.setOrientation(LinearLayout.VERTICAL);
        gpsCard.setPadding(20, 16, 20, 16);
        gpsCard.setBackground(shape(0xF0071228, GOLD, 22));
        status = text("●  GPS READY   |   28.285810, 77.297514   |   ±15 m", 15, 0xFF55E69A, true);
        gpsCard.addView(status);
        TextView addressLine = text("📍  " + currentAddress, 14, Color.WHITE, false);
        addressLine.setTag("gps_address");
        LinearLayout.LayoutParams addrLp = new LinearLayout.LayoutParams(-1, -2);
        addrLp.topMargin = 9;
        gpsCard.addView(addressLine, addrLp);
        FrameLayout.LayoutParams gpsParams = new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM);
        gpsParams.leftMargin = 14; gpsParams.rightMargin = 14;
        gpsParams.bottomMargin = (int)(128 * getResources().getDisplayMetrics().density);
        root.addView(gpsCard, gpsParams);

        // Bottom dock mirrors the approved reference: wide navy/gold tray with a raised central shutter.
        FrameLayout dock = new FrameLayout(this);
        dock.setBackground(shape(0xF5071228, GOLD, 30));
        LinearLayout bottom = new LinearLayout(this);
        bottom.setGravity(Gravity.CENTER_VERTICAL);
        bottom.setPadding(18, 4, 18, 4);
        bottom.setBackground(shape(0xF5071228, GOLD, 30));

        LinearLayout galleryGroup = new LinearLayout(this);
        galleryGroup.setOrientation(LinearLayout.VERTICAL);
        galleryGroup.setGravity(Gravity.CENTER);
        View galleryIcon = new View(this) {
            private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            @Override protected void onDraw(Canvas canvas) {
                super.onDraw(canvas);
                float d = getResources().getDisplayMetrics().density;
                float cx = getWidth()/2f, cy = getHeight()/2f;
                p.setColor(GOLD); p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(2.4f*d);
                canvas.drawRoundRect(cx-14*d,cy-11*d,cx+14*d,cy+11*d,3*d,3*d,p);
                canvas.drawCircle(cx+7*d,cy-5*d,2.2f*d,p);
                Path mountain = new Path();
                mountain.moveTo(cx-10*d,cy+7*d); mountain.lineTo(cx-3*d,cy-1*d);
                mountain.lineTo(cx+2*d,cy+4*d); mountain.lineTo(cx+6*d,cy+1*d);
                mountain.lineTo(cx+11*d,cy+7*d);
                canvas.drawPath(mountain,p);
            }
        };
        galleryGroup.addView(galleryIcon, new LinearLayout.LayoutParams(40, 34));
        TextView galleryLabel = text("GALLERY", 14, Color.WHITE, true);
        galleryGroup.addView(galleryLabel);
        galleryGroup.setOnClickListener(v -> openGallery());
        bottom.addView(galleryGroup, new LinearLayout.LayoutParams(0, -1, 1));

        // Raised shutter opening in the middle of the dock.
        View centerGap = new View(this);
        bottom.addView(centerGap, new LinearLayout.LayoutParams(112, -1));

        LinearLayout gpsPhotoGroup = new LinearLayout(this);
        gpsPhotoGroup.setOrientation(LinearLayout.VERTICAL);
        gpsPhotoGroup.setGravity(Gravity.CENTER);
        View gpsPhotoIcon = new View(this) {
            private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            @Override protected void onDraw(Canvas canvas) {
                super.onDraw(canvas);
                float d = getResources().getDisplayMetrics().density;
                float cx = getWidth()/2f, cy = getHeight()/2f;
                p.setColor(GOLD); p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(2.4f*d);
                RectF pin = new RectF(cx-12*d,cy-15*d,cx+12*d,cy+9*d);
                canvas.drawArc(pin,205,310,false,p);
                Path tail = new Path(); tail.moveTo(cx-8*d,cy+5*d);
                tail.lineTo(cx,cy+17*d); tail.lineTo(cx+8*d,cy+5*d);
                canvas.drawPath(tail,p);
                canvas.drawCircle(cx,cy-4*d,3.6f*d,p);
                // Camera badge overlaps the lower-right edge of the location pin.
                p.setStyle(Paint.Style.FILL);
                canvas.drawRoundRect(cx+4*d,cy+1*d,cx+19*d,cy+12*d,2.5f*d,2.5f*d,p);
                p.setColor(NAVY); canvas.drawCircle(cx+11.5f*d,cy+6.5f*d,2.8f*d,p);
                p.setColor(GOLD); p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(1.5f*d);
                canvas.drawCircle(cx+11.5f*d,cy+6.5f*d,4*d,p);
            }
        };
        gpsPhotoGroup.addView(gpsPhotoIcon, new LinearLayout.LayoutParams(40, 34));
        TextView gpsPhotoLabel = text("GPS PHOTO", 14, Color.WHITE, true);
        gpsPhotoGroup.addView(gpsPhotoLabel);
        gpsPhotoGroup.setOnClickListener(v -> openGallery());
        bottom.addView(gpsPhotoGroup, new LinearLayout.LayoutParams(0, -1, 1));
        dock.addView(bottom, new FrameLayout.LayoutParams(-1, -1));

        // Fine royal-gold outer halo around the raised shutter.
        View shutterHalo = new View(this);
        GradientDrawable halo = new GradientDrawable();
        halo.setShape(GradientDrawable.OVAL);
        halo.setColor(0x00000000);
        halo.setStroke((int)(2 * getResources().getDisplayMetrics().density), GOLD);
        shutterHalo.setBackground(halo);
        FrameLayout.LayoutParams haloLp = new FrameLayout.LayoutParams(120, 120, Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        haloLp.topMargin = 22;
        dock.addView(shutterHalo, haloLp);

        captureButton = new Button(this);
        captureButton.setText("");
        captureButton.setTextSize(1);
        captureButton.setTextColor(NAVY);
        captureButton.setBackgroundTintList(null);
        captureButton.setStateListAnimator(null);
        captureButton.setPadding(0, 0, 0, 0);
        captureButton.setMinWidth(0); captureButton.setMinHeight(0);
        captureButton.setGravity(Gravity.CENTER);
        captureButton.setAllCaps(false);
        captureButton.setContentDescription("Capture GPS photo");
        GradientDrawable shutter = new GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            new int[]{0xFFFFF0A8, 0xFFFFC83D, 0xFFE7A91F});
        shutter.setShape(GradientDrawable.OVAL);
        shutter.setStroke((int)(5 * getResources().getDisplayMetrics().density), 0xFFFFFFFF);
        captureButton.setBackground(shutter);
        captureButton.setElevation(12);
        FrameLayout.LayoutParams shutterLp = new FrameLayout.LayoutParams(112, 112, Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        shutterLp.topMargin = 26;
        dock.addView(captureButton, shutterLp);
        // Draw a crisp monochrome camera glyph over the gold shutter (avoid platform emoji rendering).
        View cameraGlyph = new View(this) {
            private final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            @Override protected void onDraw(Canvas canvas) {
                super.onDraw(canvas);
                float d = getResources().getDisplayMetrics().density;
                float cx = getWidth() / 2f, cy = getHeight() / 2f;
                p.setColor(NAVY); p.setStyle(Paint.Style.FILL);
                canvas.drawRoundRect(cx - 20*d, cy - 12*d, cx + 20*d, cy + 13*d, 5*d, 5*d, p);
                canvas.drawRoundRect(cx - 10*d, cy - 17*d, cx + 5*d, cy - 12*d, 2*d, 2*d, p);
                p.setColor(0xFFFFE27A); p.setStyle(Paint.Style.STROKE); p.setStrokeWidth(2.6f*d);
                canvas.drawCircle(cx, cy, 7.5f*d, p);
                p.setStyle(Paint.Style.FILL);
            }
        };
        cameraGlyph.setClickable(false);
        cameraGlyph.setElevation(14);
        FrameLayout.LayoutParams glyphLp = new FrameLayout.LayoutParams(64, 64, Gravity.TOP | Gravity.CENTER_HORIZONTAL);
        glyphLp.topMargin = 50;
        dock.addView(cameraGlyph, glyphLp);
        captureButton.setOnClickListener(v -> capturePhoto());
        captureButton.setEnabled(false);

        FrameLayout.LayoutParams bottomParams = new FrameLayout.LayoutParams(-1, 164, Gravity.BOTTOM);
        bottomParams.leftMargin = 10; bottomParams.rightMargin = 10;
        bottomParams.bottomMargin = 8;
        root.addView(dock, bottomParams);

        ViewCompat.setOnApplyWindowInsetsListener(root, (view, windowInsets) -> {
            androidx.core.graphics.Insets bars = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars());
            headerParams.topMargin = bars.top + (int)(8 * getResources().getDisplayMetrics().density);
            bottomParams.bottomMargin = bars.bottom + (int)(8 * getResources().getDisplayMetrics().density);
            header.setLayoutParams(headerParams);
            dock.setLayoutParams(bottomParams);
            gpsParams.bottomMargin = bars.bottom + (int)(128 * getResources().getDisplayMetrics().density);
            gpsCard.setLayoutParams(gpsParams);
            return windowInsets;
        });
        setContentView(root);
        ViewCompat.requestApplyInsets(root);
        if (cameraPreview != null) cameraPreview.setSurfaceProvider(previewView.getSurfaceProvider());
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
        if (cameraProvider == null || cameraPreview == null || imageCapture == null || previewView == null || photoPreviewVisible) return;
        // Reattach CameraX preview to the newly created PreviewView after returning from photo preview/save.
        cameraPreview.setSurfaceProvider(previewView.getSurfaceProvider());
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
        boolean showIp = getPreferences(MODE_PRIVATE).getBoolean(PREF_SHOW_IP, false);
        String publicIp = showIp ? fetchPublicIp() : null;
        String date = new SimpleDateFormat("dd MMM yyyy, hh:mm a", Locale.getDefault()).format(new Date());
        Canvas canvas = new Canvas(marked);
        float scale = Math.max(1f, marked.getWidth() / 1080f), pad = 24f * scale, line = 34f * scale;
        int qrSize = Math.round(184f * scale);
        float boxHeight = pad * 2.45f + line * (showIp ? 6.15f : 5.15f), top = marked.getHeight() - boxHeight - pad;
        Paint bg = new Paint(Paint.ANTI_ALIAS_FLAG); bg.setColor(0xE6101D33);
        canvas.drawRoundRect(pad, top, marked.getWidth()-pad, marked.getHeight()-pad, 22f*scale, 22f*scale, bg);
        Paint gold = new Paint(Paint.ANTI_ALIAS_FLAG); gold.setColor(GOLD);
        canvas.drawRoundRect(pad, top, pad+7f*scale, marked.getHeight()-pad, 4f*scale, 4f*scale, gold);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG); p.setColor(Color.WHITE); p.setTextSize(25f*scale); p.setFakeBoldText(true);
        float x=pad*1.8f, y=top+pad*1.25f+line*0.55f;
        // KeyDhan brand: Key in white, Dhan in royal gold, with a small raised trademark.
        p.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        p.setTextSize(25f*scale); p.setColor(Color.WHITE);
        canvas.drawText("Key",x,y,p);
        float brandX=x+p.measureText("Key");
        p.setColor(0xFFE7C270); canvas.drawText("Dhan",brandX,y,p);
        float tmX=brandX+p.measureText("Dhan");
        p.setTextSize(11f*scale); canvas.drawText("™",tmX+2f*scale,y-13f*scale,p);
        p.setTextSize(22f*scale); p.setColor(Color.WHITE);
        canvas.drawText("  Real Time GPS Photo",tmX+20f*scale,y,p);
        p.setColor(0xFFE7C270); p.setTextSize(16f*scale); y+=line*0.78f;
        canvas.drawText("LIVE LOCATION  •  GPS ACCURACY",x,y,p);
        p.setColor(Color.WHITE); p.setFakeBoldText(false); p.setTextSize(19f*scale); y+=line*1.02f;
        canvas.drawText(String.format(Locale.US,"LAT  %.6f     LONG  %.6f",loc.getLatitude(),loc.getLongitude()),x,y,p);
        y+=line; canvas.drawText(trim(address,52),x,y,p);
        y+=line; p.setColor(0xFFE1E7F0); canvas.drawText(date,x,y,p);
        y+=line; p.setColor(0xFFFFD76A); p.setFakeBoldText(true); p.setTextSize(17f*scale);
        canvas.drawText("Made in India",x,y,p);
        p.setTextSize(18f*scale); canvas.drawText("  🇮🇳",x+p.measureText("Made in India"),y,p);
        if (showIp) {
            y+=line; p.setColor(0xFFE1E7F0); p.setFakeBoldText(false); p.setTextSize(17f*scale);
            canvas.drawText("PUBLIC IP  " + (publicIp == null ? "Not Available" : publicIp),x,y,p);
        }
        // Per-photo QR encodes a direct Google Maps query for this exact GPS fix.
        try {
            String mapUrl = String.format(Locale.US,"https://maps.google.com/?q=%.6f,%.6f",loc.getLatitude(),loc.getLongitude());
            Map<EncodeHintType,Object> qrHints = new HashMap<>();
            qrHints.put(EncodeHintType.MARGIN, 1);
            qrHints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.H);
            BitMatrix matrix = new QRCodeWriter().encode(mapUrl, BarcodeFormat.QR_CODE, qrSize, qrSize, qrHints);
            Bitmap qr = Bitmap.createBitmap(qrSize, qrSize, Bitmap.Config.ARGB_8888);
            for (int yy=0; yy<qrSize; yy++) for (int xx=0; xx<qrSize; xx++)
                qr.setPixel(xx, yy, matrix.get(xx,yy) ? Color.BLACK : Color.WHITE);
            // Small KeyDhan™ navy/gold center mark; high error correction keeps the location QR scannable.
            Canvas qrCanvas = new Canvas(qr);
            Paint logoBg = new Paint(Paint.ANTI_ALIAS_FLAG); logoBg.setColor(Color.WHITE);
            float logoW=qrSize*0.52f, logoH=qrSize*0.20f, logoCx=qrSize/2f, logoCy=qrSize/2f;
            qrCanvas.drawRoundRect(logoCx-logoW/2f-3f*scale,logoCy-logoH/2f-3f*scale,
                logoCx+logoW/2f+3f*scale,logoCy+logoH/2f+3f*scale,7f*scale,7f*scale,logoBg);
            Paint logoP = new Paint(Paint.ANTI_ALIAS_FLAG); logoP.setColor(NAVY);
            qrCanvas.drawRoundRect(logoCx-logoW/2f,logoCy-logoH/2f,logoCx+logoW/2f,logoCy+logoH/2f,5f*scale,5f*scale,logoP);
            logoP.setTypeface(Typeface.create("sans-serif",Typeface.BOLD));
            logoP.setTextSize(17f*scale); logoP.setTextAlign(Paint.Align.CENTER);
            float logoTextY=logoCy+6f*scale;
            logoP.setColor(Color.WHITE); qrCanvas.drawText("Key",logoCx-13f*scale,logoTextY,logoP);
            logoP.setColor(0xFFE7C270); qrCanvas.drawText("Dhan",logoCx+20f*scale,logoTextY,logoP);
            logoP.setTextSize(7f*scale); qrCanvas.drawText("™",logoCx+43f*scale,logoTextY-10f*scale,logoP);
            float qx=marked.getWidth()-pad-qrSize-24f*scale, qy=top+(boxHeight-qrSize)/2f;
            Paint qrBg = new Paint(Paint.ANTI_ALIAS_FLAG); qrBg.setColor(Color.WHITE);
            canvas.drawRoundRect(qx-4f*scale,qy-4f*scale,qx+qrSize+4f*scale,qy+qrSize+4f*scale,6f*scale,6f*scale,qrBg);
            canvas.drawBitmap(qr,qx,qy,null); qr.recycle();
        } catch (Exception qrError) {
            android.util.Log.e("KeyDhanGPS","Could not generate location QR",qrError);
        }
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
        photoPreviewVisible = true;
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
    @Override protected void onResume() {
        super.onResume();
        if (!photoPreviewVisible && cameraProvider != null && cameraPreview != null && imageCapture != null && previewView != null) {
            previewView.post(() -> bindSelectedCamera());
        }
    }

    private String fetchPublicIp() {
        HttpURLConnection connection = null;
        try {
            connection = (HttpURLConnection) new URL("https://api.ipify.org").openConnection();
            connection.setRequestMethod("GET");
            connection.setConnectTimeout(2500);
            connection.setReadTimeout(2500);
            connection.setUseCaches(false);
            try (java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.InputStreamReader(connection.getInputStream(), java.nio.charset.StandardCharsets.UTF_8))) {
                String ip = reader.readLine();
                if (ip != null && ip.matches("[0-9a-fA-F:.]{3,45}")) return ip;
            }
        } catch (Exception e) { android.util.Log.w("KeyDhanGPS", "Public IP unavailable", e); }
        finally { if (connection != null) connection.disconnect(); }
        return null;
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
