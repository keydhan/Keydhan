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
    implementation "com.google.android.gms:play-services-mlkit-document-scanner:16.0.0"
    implementation "com.google.mlkit:text-recognition:16.0.1"
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
scanner_activity='''        <activity
            android:name="com.keydhan.app.DocumentScannerActivity"
            android:exported="false"
            android:screenOrientation="portrait"
            android:theme="@android:style/Theme.Material.Light.NoActionBar" />
'''
if "DocumentScannerActivity" not in s:
    s=s.replace("</application>",scanner_activity+"</application>")
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
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import android.view.View;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
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
        TextView scannerButton = new TextView(this);
        scannerButton.setText("▤  Doc Scanner");
        scannerButton.setTextColor(Color.WHITE);
        scannerButton.setTextSize(14);
        scannerButton.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        scannerButton.setGravity(Gravity.CENTER);
        scannerButton.setPadding(22, 14, 22, 14);
        scannerButton.setBackgroundColor(Color.rgb(10, 40, 88));
        scannerButton.setElevation(12f);
        scannerButton.setOnClickListener(v ->
            startActivity(new Intent(MainActivity.this, DocumentScannerActivity.class))
        );
        FrameLayout.LayoutParams scannerParams = new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM | Gravity.START
        );
        scannerParams.setMargins(18, 0, 0, 96);
        addContentView(scannerButton, scannerParams);
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
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.IntentSenderRequest;
import androidx.activity.result.contract.ActivityResultContracts;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner;
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult;
import androidx.activity.OnBackPressedCallback;
import android.content.ContentValues;
import android.database.Cursor;
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
import android.widget.GridLayout;
import android.widget.ScrollView;
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
    private static final String PREF_PRIVACY_NOTICE_SEEN = "privacy_notice_seen";
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
    private TextView flashSettingsStatus;
    private TextView photoQualityStatus;
    private static final String PREF_PHOTO_QUALITY = "photo_quality";
    private File pendingPhoto;
    private Uri lastSavedUri;
    private boolean photoPreviewVisible = false;
    private OnBackPressedCallback gpsPhotosBackCallback;

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
        settings.setOnClickListener(v -> showCameraSettings());
        LinearLayout.LayoutParams settingsLp = new LinearLayout.LayoutParams(62, 62);
        settingsLp.leftMargin = 7;
        header.addView(settings, settingsLp);
        FrameLayout.LayoutParams headerParams = new FrameLayout.LayoutParams(-1, -2, Gravity.TOP);
        headerParams.leftMargin = 10; headerParams.rightMargin = 10;
        root.addView(header, headerParams);

        // Compact privacy assurance strip sits directly below the header, over the preview.
        boolean privacySeen = getPreferences(MODE_PRIVATE).getBoolean(PREF_PRIVACY_NOTICE_SEEN, false);
        LinearLayout privacyStrip = new LinearLayout(this);
        privacyStrip.setGravity(Gravity.CENTER_VERTICAL);
        privacyStrip.setPadding(12, 8, 12, 8);
        privacyStrip.setBackground(shape(0xE6102944, GOLD, 16));
        TextView privacyShield = text("◆", 18, GOLD, true);
        privacyShield.setGravity(Gravity.CENTER);
        privacyStrip.addView(privacyShield, new LinearLayout.LayoutParams(30, 34));
        LinearLayout privacyCopy = new LinearLayout(this);
        privacyCopy.setOrientation(LinearLayout.VERTICAL);
        privacyCopy.setPadding(7, 0, 5, 0);
        TextView privacyTitle = text(privacySeen ? "PRIVACY PROTECTED  ·  LOCAL PROCESSING" : "YOUR PRIVACY IS PROTECTED", 11, Color.WHITE, true);
        TextView privacySub = text(privacySeen ? "Photos are processed and saved on your phone." : "Photos stay on your phone. No photo uploads to KeyDhan servers.", 10, 0xFFE8D8B2, false);
        privacyCopy.addView(privacyTitle);
        privacyCopy.addView(privacySub);
        privacyStrip.addView(privacyCopy, new LinearLayout.LayoutParams(0, -2, 1));
        TextView privacyAction = text(privacySeen ? "i" : "GOT IT", privacySeen ? 19 : 10, GOLD, true);
        privacyAction.setGravity(Gravity.CENTER);
        privacyAction.setIncludeFontPadding(false);
        privacyAction.setPadding(0, 0, 0, 1);
        if (privacySeen) {
            privacyAction.setBackground(shape(0x00102238, GOLD, 50));
            privacyStrip.addView(privacyAction, new LinearLayout.LayoutParams(36, 36));
        } else {
            privacyAction.setPadding(6, 4, 6, 4);
            privacyStrip.addView(privacyAction, new LinearLayout.LayoutParams(-2, 38));
        }
        privacyStrip.setOnClickListener(v -> showPrivacyDetails());
        FrameLayout.LayoutParams privacyParams = new FrameLayout.LayoutParams(-1, -2, Gravity.TOP);
        privacyParams.leftMargin = 14; privacyParams.rightMargin = 14;
        privacyParams.topMargin = 112;
        root.addView(privacyStrip, privacyParams);
        if (!privacySeen) {
            privacyAction.setText("GOT IT");
            privacyStrip.setOnClickListener(v -> {
                getPreferences(MODE_PRIVATE).edit().putBoolean(PREF_PRIVACY_NOTICE_SEEN, true).apply();
                privacyTitle.setText("PRIVACY PROTECTED  ·  LOCAL PROCESSING");
                privacySub.setText("Photos are processed and saved on your phone.");
                privacyAction.setText("i");
                privacyAction.setTextSize(19);
                privacyAction.setIncludeFontPadding(false);
                privacyAction.setPadding(0, 0, 0, 1);
                privacyAction.setBackground(shape(0x00102238, GOLD, 50));
                android.view.ViewGroup.LayoutParams infoSize = privacyAction.getLayoutParams();
                infoSize.width = (int)(36 * getResources().getDisplayMetrics().density);
                infoSize.height = (int)(36 * getResources().getDisplayMetrics().density);
                privacyAction.setLayoutParams(infoSize);
                privacyStrip.setOnClickListener(ignored -> showPrivacyDetails());
            });
        }

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
                // Keep the control at its original 74px footprint on every density.
                float d = Math.min(getWidth(), getHeight()) / 74f;
                float cx = getWidth()/2f, cy = getHeight()/2f;

                // Navy inset leaves generous breathing room around the arrows.
                p.setStyle(Paint.Style.FILL);
                p.setColor(NAVY);
                canvas.drawCircle(cx, cy, 28.5f*d, p);

                // Smaller, separated circular arrows: one pearl-white, one champagne-gold.
                float radius = 14.5f*d;
                RectF orbit = new RectF(cx-radius, cy-radius, cx+radius, cy+radius);
                p.setStyle(Paint.Style.STROKE);
                p.setStrokeWidth(2.35f*d);
                p.setStrokeCap(Paint.Cap.ROUND);
                p.setStrokeJoin(Paint.Join.ROUND);

                float[] starts = {135f, 315f};
                int[] arrowColors = {0xFFFFF8E8, 0xFFFFD978};
                float[] ends = {335f, 155f};
                for (int i = 0; i < 2; i++) {
                    p.setColor(arrowColors[i]);
                    p.setStyle(Paint.Style.STROKE);
                    canvas.drawArc(orbit, starts[i], 200f, false, p);

                    double radians = Math.toRadians(ends[i]);
                    float ex = cx + radius*(float)Math.cos(radians);
                    float ey = cy + radius*(float)Math.sin(radians);
                    double tangent = Math.toRadians(ends[i] + 90f);
                    float tx = (float)Math.cos(tangent), ty = (float)Math.sin(tangent);
                    float nx = -ty, ny = tx;
                    float back = 6.5f*d, halfWidth = 3.8f*d;
                    Path arrow = new Path();
                    arrow.moveTo(ex, ey);
                    arrow.lineTo(ex - tx*back + nx*halfWidth, ey - ty*back + ny*halfWidth);
                    arrow.lineTo(ex - tx*back - nx*halfWidth, ey - ty*back - ny*halfWidth);
                    arrow.close();
                    p.setStyle(Paint.Style.FILL);
                    canvas.drawPath(arrow, p);
                }
            }
        };
        GradientDrawable flipRing = new GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            new int[]{0xFFFFF6D8, 0xFFE2B84F, 0xFFB98532});
        flipRing.setShape(GradientDrawable.OVAL);
        flipRing.setStroke((int)(1.2f * getResources().getDisplayMetrics().density), 0xFFFFF0C2);
        flip.setBackground(flipRing);
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
        galleryGroup.setGravity(Gravity.CENTER);
        galleryGroup.setContentDescription("Open Gallery");
        TextView galleryLabel = text("GALLERY", 13, Color.WHITE, true);
        galleryLabel.setGravity(Gravity.CENTER);
        galleryLabel.setTextAlignment(View.TEXT_ALIGNMENT_CENTER);
        galleryGroup.addView(galleryLabel, new LinearLayout.LayoutParams(-1, -2));
        galleryGroup.setOnClickListener(v -> openDeviceGallery());
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
        gpsPhotoGroup.setGravity(Gravity.CENTER);
        gpsPhotoGroup.setContentDescription("Open GPS Photos");
        TextView gpsPhotoLabel = text("GPS PHOTO", 13, Color.WHITE, true);
        gpsPhotoLabel.setGravity(Gravity.CENTER);
        gpsPhotoLabel.setTextAlignment(View.TEXT_ALIGNMENT_CENTER);
        gpsPhotoGroup.addView(gpsPhotoLabel, new LinearLayout.LayoutParams(-1, -2));
        gpsPhotoGroup.setOnClickListener(v -> openGpsPhotos());
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
            privacyParams.topMargin = bars.top + (int)(112 * getResources().getDisplayMetrics().density);
            bottomParams.bottomMargin = bars.bottom + (int)(8 * getResources().getDisplayMetrics().density);
            header.setLayoutParams(headerParams);
            privacyStrip.setLayoutParams(privacyParams);
            dock.setLayoutParams(bottomParams);
            gpsParams.bottomMargin = bars.bottom + (int)(128 * getResources().getDisplayMetrics().density);
            gpsCard.setLayoutParams(gpsParams);
            return windowInsets;
        });
        setContentView(root);
        ViewCompat.requestApplyInsets(root);
        if (cameraPreview != null) cameraPreview.setSurfaceProvider(previewView.getSurfaceProvider());
    }

    private void showCameraSettings() {
        final float d = getResources().getDisplayMetrics().density;
        int pad = (int)(18 * d);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(pad, pad, pad, (int)(12*d));
        page.setBackground(shape(0xFF07152D, GOLD, 24));

        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        TextView backMark = text("⚙", 24, GOLD, true);
        backMark.setGravity(Gravity.CENTER);
        top.addView(backMark, new LinearLayout.LayoutParams((int)(42*d), (int)(42*d)));
        LinearLayout topTitles = new LinearLayout(this);
        topTitles.setOrientation(LinearLayout.VERTICAL);
        topTitles.setPadding((int)(8*d), 0, 0, 0);
        topTitles.addView(text("KeyDhan™", 21, Color.WHITE, true));
        topTitles.addView(text("CAMERA SETTINGS", 11, GOLD, true));
        top.addView(topTitles, new LinearLayout.LayoutParams(0, -2, 1));
        TextView close = text("×", 28, Color.WHITE, true);
        close.setGravity(Gravity.CENTER);
        close.setBackground(shape(0xFF243752, GOLD, 50));
        close.setContentDescription("Close camera settings");
        close.setClickable(true);
        close.setFocusable(true);
        LinearLayout.LayoutParams closeLp = new LinearLayout.LayoutParams((int)(42*d), (int)(42*d));
        closeLp.leftMargin = (int)(8*d);
        top.addView(close, closeLp);
        page.addView(top);

        TextView heroTitle = text("Camera Control Center", 20, Color.WHITE, true);
        heroTitle.setPadding(0, (int)(18*d), 0, (int)(3*d));
        page.addView(heroTitle);
        TextView heroSub = text("Manage your camera, GPS stamping and privacy preferences.", 12, 0xFFB9C6D8, false);
        page.addView(heroSub);
        addSettingsSection(page, "01  CAMERA PREFERENCES", d);
        LinearLayout cameraCard = settingsCard(d);
        flashSettingsStatus = addSettingsRow(cameraCard, "⚡", "Flash", "Control camera flash",
            flashOn ? "ON" : "OFF", () -> {
                toggleFlash();
            }, d);
        addSettingsDivider(cameraCard, d);
        photoQualityStatus = addSettingsRow(cameraCard, "▧", "Photo Quality", "Choose your image quality",
            getPhotoQualityLabel(), () -> showPhotoQualityOptions(), d);
        updatePhotoQualityStatus();
        page.addView(cameraCard);

        addSettingsSection(page, "02  GPS & PHOTO STAMPING", d);
        LinearLayout gpsCard = settingsCard(d);
        addSettingsRow(gpsCard, "⌖", "GPS Watermark", "Add GPS details to captured photos", "ON", () ->
            Toast.makeText(this, "GPS watermark is enabled.", Toast.LENGTH_SHORT).show(), d);
        page.addView(gpsCard);

        addSettingsSection(page, "03  PRIVACY & SECURITY", d);
        LinearLayout privacyCard = settingsCard(d);
        boolean publicIp = getPreferences(MODE_PRIVATE).getBoolean(PREF_SHOW_IP, false);
        LinearLayout ipRow = new LinearLayout(this);
        ipRow.setGravity(Gravity.CENTER_VERTICAL);
        ipRow.setPadding((int)(12*d), (int)(12*d), (int)(10*d), (int)(12*d));
        TextView ipIcon = text("◎", 24, GOLD, true);
        ipIcon.setGravity(Gravity.CENTER);
        ipRow.addView(ipIcon, new LinearLayout.LayoutParams((int)(42*d), (int)(42*d)));
        LinearLayout ipCopy = new LinearLayout(this);
        ipCopy.setOrientation(LinearLayout.VERTICAL);
        ipCopy.setPadding((int)(8*d), 0, (int)(6*d), 0);
        ipCopy.addView(text("Public IP on Photo", 14, Color.WHITE, true));
        ipCopy.addView(text("Optionally show your public IP in the photo stamp", 11, 0xFFB9C6D8, false));
        TextView ipState = text(publicIp ? "● ON  ·  ENABLED" : "○ OFF  ·  DISABLED", 10,
            publicIp ? 0xFF63D99A : 0xFF9AA8BA, true);
        ipState.setPadding(0, (int)(6*d), 0, 0);
        ipCopy.addView(ipState);
        ipRow.addView(ipCopy, new LinearLayout.LayoutParams(0, -2, 1));

        // High-contrast custom switch: gold track + knob on the right when ON;
        // muted navy track + knob on the left when OFF.
        FrameLayout ipSwitch = new FrameLayout(this);
        int switchW = (int)(66*d), switchH = (int)(38*d), knobSize = (int)(28*d);
        ipSwitch.setFocusable(true);
        ipSwitch.setClickable(true);
        ipSwitch.setContentDescription(publicIp ? "Public IP enabled" : "Public IP disabled");
        ipSwitch.setBackground(shape(publicIp ? 0xFFC9A34D : 0xFF34465E, 0, 30));
        View knob = new View(this);
        knob.setBackground(shape(Color.WHITE, publicIp ? 0xFFE7C270 : 0xFFCBD5E1, 50));
        FrameLayout.LayoutParams knobParams = new FrameLayout.LayoutParams(knobSize, knobSize,
            publicIp ? Gravity.END | Gravity.CENTER_VERTICAL : Gravity.START | Gravity.CENTER_VERTICAL);
        int knobMargin = (int)(5*d);
        knobParams.leftMargin = knobMargin;
        knobParams.rightMargin = knobMargin;
        ipSwitch.addView(knob, knobParams);
        ipRow.addView(ipSwitch, new LinearLayout.LayoutParams(switchW, switchH));
        ipSwitch.setOnClickListener(v -> {
            boolean enabled = !getPreferences(MODE_PRIVATE).getBoolean(PREF_SHOW_IP, false);
            getPreferences(MODE_PRIVATE).edit().putBoolean(PREF_SHOW_IP, enabled).apply();
            ipSwitch.setBackground(shape(enabled ? 0xFFC9A34D : 0xFF34465E, 0, 30));
            FrameLayout.LayoutParams updated = (FrameLayout.LayoutParams) knob.getLayoutParams();
            updated.gravity = enabled ? Gravity.END | Gravity.CENTER_VERTICAL : Gravity.START | Gravity.CENTER_VERTICAL;
            knob.setLayoutParams(updated);
            ipState.setText(enabled ? "● ON  ·  ENABLED" : "○ OFF  ·  DISABLED");
            ipState.setTextColor(enabled ? 0xFF63D99A : 0xFF9AA8BA);
            ipSwitch.setContentDescription(enabled ? "Public IP enabled" : "Public IP disabled");
            Toast.makeText(this, "Public IP on photo: " + (enabled ? "On" : "Off"), Toast.LENGTH_SHORT).show();
        });
        privacyCard.addView(ipRow);
        addSettingsDivider(privacyCard, d);
        addSettingsRow(privacyCard, "◇", "Privacy & Data Security", "Learn how your data is processed", "›", () ->
            showPrivacyDetails(), d);
        page.addView(privacyCard);

        TextView footer = text("Your photos stay on your device.", 11, 0xFFD9B45C, true);
        footer.setGravity(Gravity.CENTER);
        footer.setPadding(0, (int)(17*d), 0, (int)(10*d));
        page.addView(footer);
        Button done = new Button(this);
        done.setText("DONE");
        done.setAllCaps(false);
        done.setTextSize(13);
        done.setTypeface(null, android.graphics.Typeface.BOLD);
        done.setTextColor(0xFF07152D);
        done.setBackground(shape(0xFFC9A34D, 0, 18));
        page.addView(done, new LinearLayout.LayoutParams(-1, (int)(48*d)));

        android.widget.ScrollView scroll = new android.widget.ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setClipToPadding(false);
        scroll.addView(page);
        android.app.AlertDialog dialog = new android.app.AlertDialog.Builder(this).create();
        dialog.setView(scroll);
        done.setOnClickListener(v -> dialog.dismiss());
        close.setOnClickListener(v -> dialog.dismiss());
        dialog.show();
        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(Color.TRANSPARENT));
            dialog.getWindow().setDimAmount(0.72f);
            dialog.getWindow().setLayout((int)(getResources().getDisplayMetrics().widthPixels * 0.92f),
                (int)(getResources().getDisplayMetrics().heightPixels * 0.82f));
        }
    }

    private void addSettingsSection(LinearLayout parent, String label, float d) {
        TextView heading = text(label, 10, GOLD, true);
        heading.setPadding((int)(3*d), (int)(17*d), 0, (int)(7*d));
        parent.addView(heading);
    }

    private LinearLayout settingsCard(float d) {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(shape(0xFF10233D, 0x665C718D, 18));
        return card;
    }

    private void addSettingsDivider(LinearLayout parent, float d) {
        View line = new View(this);
        line.setBackgroundColor(0x553E526D);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, Math.max(1, (int)d));
        lp.leftMargin = (int)(60*d);
        lp.rightMargin = (int)(12*d);
        parent.addView(line, lp);
    }

    private TextView addSettingsRow(LinearLayout parent, String icon, String title, String description, String value, Runnable action, float d) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding((int)(12*d), (int)(12*d), (int)(12*d), (int)(12*d));
        TextView glyph = text(icon, 23, GOLD, true);
        glyph.setGravity(Gravity.CENTER);
        row.addView(glyph, new LinearLayout.LayoutParams((int)(42*d), (int)(42*d)));
        LinearLayout copy = new LinearLayout(this);
        copy.setOrientation(LinearLayout.VERTICAL);
        copy.setPadding((int)(8*d), 0, (int)(5*d), 0);
        copy.addView(text(title, 14, Color.WHITE, true));
        copy.addView(text(description, 11, 0xFFB9C6D8, false));
        row.addView(copy, new LinearLayout.LayoutParams(0, -2, 1));
        TextView status = text(value, 10, GOLD, true);
        status.setGravity(Gravity.CENTER);
        status.setPadding((int)(9*d), (int)(6*d), (int)(9*d), (int)(6*d));
        status.setBackground(shape(0x332C405A, 0x667E8EA5, 20));
        row.addView(status);
        row.setClickable(true);
        row.setBackgroundResource(android.R.drawable.list_selector_background);
        row.setOnClickListener(v -> action.run());
        parent.addView(row);
        return status;
    }

    private void showPrivacyDetails() {
        boolean publicIpEnabled = getPreferences(MODE_PRIVATE).getBoolean(PREF_SHOW_IP, false);
        float density = getResources().getDisplayMetrics().density;
        int pad = (int)(20 * density);
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(pad, pad, pad, (int)(14 * density));
        card.setBackground(shape(0xFF071A32, GOLD, 22));

        LinearLayout heading = new LinearLayout(this);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        TextView shield = text("⬡", 25, GOLD, true);
        shield.setGravity(Gravity.CENTER);
        heading.addView(shield, new LinearLayout.LayoutParams((int)(38*density), -2));
        TextView headingText = text("KeyDhan Privacy & Data Security", 18, Color.WHITE, true);
        headingText.setPadding((int)(8*density), 0, 0, 0);
        heading.addView(headingText, new LinearLayout.LayoutParams(0, -2, 1));
        card.addView(heading);

        TextView localTitle = text("100% LOCAL PHOTO PROCESSING", 12, GOLD, true);
        localTitle.setPadding(0, (int)(18*density), 0, (int)(7*density));
        card.addView(localTitle);
        TextView localCopy = text("Your photos are processed and saved locally on your phone. Photos are not uploaded to KeyDhan servers. Your location is used to create the GPS stamp on the photo.", 14, 0xFFF1F4FA, false);
        localCopy.setLineSpacing(2*density, 1.05f);
        card.addView(localCopy);

        if (publicIpEnabled) {
            View divider = new View(this);
            divider.setBackgroundColor(0x668F7748);
            LinearLayout.LayoutParams dividerParams = new LinearLayout.LayoutParams(-1, (int)(1*density));
            dividerParams.setMargins(0, (int)(17*density), 0, (int)(14*density));
            card.addView(divider);

            LinearLayout ipHeading = new LinearLayout(this);
            ipHeading.setGravity(Gravity.CENTER_VERTICAL);
            TextView globe = text("◎", 21, GOLD, true);
            ipHeading.addView(globe);
            TextView ipTitle = text("PUBLIC IP IS ON", 14, Color.WHITE, true);
            ipTitle.setPadding((int)(9*density), 0, 0, 0);
            ipHeading.addView(ipTitle);
            TextView enabled = text("ON", 10, 0xFF071A32, true);
            enabled.setGravity(Gravity.CENTER);
            enabled.setPadding((int)(10*density), (int)(4*density), (int)(10*density), (int)(4*density));
            enabled.setBackground(shape(0xFFE5BD63, 0, 18));
            LinearLayout.LayoutParams enabledParams = new LinearLayout.LayoutParams(-2, -2);
            enabledParams.leftMargin = (int)(8*density);
            ipHeading.addView(enabled, enabledParams);
            card.addView(ipHeading);

            TextView ipCopy = text("An external IP lookup service is contacted to retrieve your public IP address for the photo.", 13, 0xFFE5EAF2, false);
            ipCopy.setPadding(0, (int)(9*density), 0, (int)(13*density));
            ipCopy.setLineSpacing(2*density, 1.04f);
            card.addView(ipCopy);

            TextView turnOffTitle = text("Want to turn it OFF?", 14, GOLD, true);
            card.addView(turnOffTitle);
            TextView turnOffSteps = text("GPS Camera  →  Settings ⚙  →  Show Public IP on Photo  →  OFF", 13, Color.WHITE, true);
            turnOffSteps.setPadding(0, (int)(7*density), 0, (int)(7*density));
            turnOffSteps.setLineSpacing(2*density, 1.04f);
            card.addView(turnOffSteps);
            TextView offNote = text("When OFF, the app will not request your public IP and no IP address will be added to your photo.", 12, 0xFFB8C4D5, false);
            offNote.setLineSpacing(1*density, 1.02f);
            card.addView(offNote);
        }

        Button gotIt = new Button(this);
        gotIt.setText("Got it");
        gotIt.setAllCaps(false);
        gotIt.setTextSize(14);
        gotIt.setTypeface(null, Typeface.BOLD);
        gotIt.setTextColor(0xFF071A32);
        gotIt.setBackground(shape(GOLD, 0, 18));
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(-1, (int)(48*density));
        buttonParams.topMargin = (int)(18*density);
        card.addView(gotIt, buttonParams);

        android.widget.ScrollView scroll = new android.widget.ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setClipToPadding(false);
        scroll.addView(card);
        android.app.AlertDialog dialog = new android.app.AlertDialog.Builder(this).create();
        dialog.setView(scroll);
        gotIt.setOnClickListener(v -> {
            getPreferences(MODE_PRIVATE).edit().putBoolean(PREF_PRIVACY_NOTICE_SEEN, true).apply();
            dialog.dismiss();
        });
        dialog.show();
        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(Color.TRANSPARENT));
            dialog.getWindow().setDimAmount(0.72f);
            dialog.getWindow().setLayout((int)(getResources().getDisplayMetrics().widthPixels * 0.90f), -2);
        }
    }

    // Open the device's installed Gallery app when available; never force Google Photos.
    private void openDeviceGallery() {
        try {
            Intent gallery = new Intent(Intent.ACTION_MAIN);
            gallery.addCategory(Intent.CATEGORY_APP_GALLERY);
            if (gallery.resolveActivity(getPackageManager()) != null) {
                startActivity(gallery);
                return;
            }
            // System image picker fallback for devices whose Gallery app has no launcher category.
            Intent picker = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
            picker.setType("image/*");
            if (picker.resolveActivity(getPackageManager()) != null) startActivity(picker);
            else Toast.makeText(this, "Gallery is not available.", Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            Toast.makeText(this, "Gallery is not available.", Toast.LENGTH_SHORT).show();
        }
    }

    // Return to the live camera from the in-app KeyDhan GPS photo album.
    private void closeGpsPhotos() {
        if (gpsPhotosBackCallback != null) gpsPhotosBackCallback.setEnabled(false);
        buildCameraUi();
        if (cameraProvider != null) bindSelectedCamera();
    }

    // Show only photos captured and saved by KeyDhan GPS Camera.
    private void openGpsPhotos() {
        if (gpsPhotosBackCallback == null) {
            gpsPhotosBackCallback = new OnBackPressedCallback(false) {
                @Override public void handleOnBackPressed() {
                    closeGpsPhotos();
                }
            };
            getOnBackPressedDispatcher().addCallback(this, gpsPhotosBackCallback);
        }
        gpsPhotosBackCallback.setEnabled(true);

        final float density = getResources().getDisplayMetrics().density;
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding((int)(14*density), (int)(10*density),
            (int)(14*density), (int)(12*density));
        page.setBackgroundColor(NAVY);

        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setPadding(0, 0, 0, (int)(12*density));

        // Draw a clear gold back arrow instead of a font glyph that can render as a dash.
        View back = new View(this) {
            private final Paint arrowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
            @Override protected void onDraw(Canvas canvas) {
                super.onDraw(canvas);
                float cx = getWidth()/2f, cy = getHeight()/2f;
                float d = getResources().getDisplayMetrics().density;
                arrowPaint.setColor(0xFFFFE7A0);
                arrowPaint.setStyle(Paint.Style.STROKE);
                arrowPaint.setStrokeWidth(2.5f*d);
                arrowPaint.setStrokeCap(Paint.Cap.ROUND);
                arrowPaint.setStrokeJoin(Paint.Join.ROUND);
                Path path = new Path();
                path.moveTo(cx+9*d, cy);
                path.lineTo(cx-9*d, cy);
                path.moveTo(cx-9*d, cy);
                path.lineTo(cx-1*d, cy-8*d);
                path.moveTo(cx-9*d, cy);
                path.lineTo(cx-1*d, cy+8*d);
                canvas.drawPath(path, arrowPaint);
            }
        };
        back.setBackground(shape(0xFF142944, GOLD, 28));
        back.setContentDescription("Back to GPS Camera");
        back.setClickable(true);
        back.setFocusable(true);
        top.addView(back, new LinearLayout.LayoutParams((int)(48*density), (int)(48*density)));
        back.setOnClickListener(v -> closeGpsPhotos());

        LinearLayout heading = new LinearLayout(this);
        heading.setOrientation(LinearLayout.VERTICAL);
        heading.setPadding((int)(12*density), 0, 0, 0);
        TextView albumTitle = text("KeyDhan GPS Photos", 19, Color.WHITE, true);
        TextView albumSubtitle = text("Photos captured with KeyDhan GPS Camera", 11, 0xFFE7C270, false);
        heading.addView(albumTitle);
        heading.addView(albumSubtitle);
        top.addView(heading, new LinearLayout.LayoutParams(0, -2, 1));
        page.addView(top);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(3);
        grid.setUseDefaultMargins(true);
        grid.setPadding(2, 4, 2, 12);

        int count = 0;
        String[] projection = {
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.RELATIVE_PATH
        };
        String selection = MediaStore.Images.Media.RELATIVE_PATH + "=?";
        String[] selectionArgs = {"Pictures/KeyDhan GPS Camera/"};
        try (Cursor cursor = getContentResolver().query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection, selection, selectionArgs,
                MediaStore.Images.Media.DATE_ADDED + " DESC")) {
            if (cursor != null) {
                int idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID);
                while (cursor.moveToNext()) {
                    long imageId = cursor.getLong(idColumn);
                    Uri imageUri = Uri.withAppendedPath(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI, String.valueOf(imageId));
                    ImageView thumb = new ImageView(this);
                    thumb.setScaleType(ImageView.ScaleType.CENTER_CROP);
                    thumb.setBackground(shape(0xFF142944, GOLD, 10));
                    thumb.setImageURI(imageUri);
                    GridLayout.LayoutParams tile = new GridLayout.LayoutParams();
                    tile.width = getResources().getDisplayMetrics().widthPixels / 3
                        - (int)(18 * density);
                    tile.height = tile.width;
                    tile.setMargins(3, 3, 3, 3);
                    grid.addView(thumb, tile);
                    thumb.setContentDescription("Open saved KeyDhan GPS photo");
                    thumb.setOnClickListener(v -> {
                        try {
                            Intent view = new Intent(Intent.ACTION_VIEW);
                            view.setDataAndType(imageUri, "image/*");
                            view.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                            startActivity(view);
                        } catch (Exception e) {
                            Toast.makeText(this, "Could not open this photo.", Toast.LENGTH_SHORT).show();
                        }
                    });
                    count++;
                }
            }
        } catch (Exception e) {
            android.util.Log.e("KeyDhanGPS", "Could not load KeyDhan GPS photos", e);
        }
        if (count == 0) {
            TextView empty = text("No KeyDhan GPS photos yet.\\nCapture and save a GPS photo to see it here.", 15, 0xFFE8D8B2, false);
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(24, 48, 24, 48);
            page.addView(empty, new LinearLayout.LayoutParams(-1, -2));
        } else {
            scroll.addView(grid);
            page.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
        }

        // Respect Android status/navigation bars: keep title clear of status icons.
        ViewCompat.setOnApplyWindowInsetsListener(page, (view, windowInsets) -> {
            androidx.core.graphics.Insets bars =
                windowInsets.getInsets(WindowInsetsCompat.Type.systemBars());
            page.setPadding((int)(14*density), bars.top + (int)(8*density),
                (int)(14*density), bars.bottom + (int)(10*density));
            return windowInsets;
        });
        setContentView(page);
        ViewCompat.requestApplyInsets(page);
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
    private int getPhotoQualityValue() {
        String quality = getPreferences(MODE_PRIVATE).getString(PREF_PHOTO_QUALITY, "HIGH");
        if ("STANDARD".equals(quality)) return 80;
        if ("DATA_SAVER".equals(quality)) return 65;
        return 95;
    }
    private String getPhotoQualityLabel() {
        String quality = getPreferences(MODE_PRIVATE).getString(PREF_PHOTO_QUALITY, "HIGH");
        if ("STANDARD".equals(quality)) return "STANDARD";
        if ("DATA_SAVER".equals(quality)) return "DATA SAVER";
        return "HIGH";
    }
    private ImageCapture buildImageCapture() {
        return new ImageCapture.Builder()
            .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
            .setJpegQuality(getPhotoQualityValue())
            .build();
    }
    private void updatePhotoQualityStatus() {
        if (photoQualityStatus == null) return;
        photoQualityStatus.setText(getPhotoQualityLabel());
        photoQualityStatus.setTextColor("HIGH".equals(getPhotoQualityLabel()) ? 0xFF63D99A : GOLD);
    }
    private void showPhotoQualityOptions() {
        String[] labels = {"High — Best detail", "Standard — Balanced size", "Data Saver — Smaller files"};
        String[] values = {"HIGH", "STANDARD", "DATA_SAVER"};
        String current = getPreferences(MODE_PRIVATE).getString(PREF_PHOTO_QUALITY, "HIGH");
        int selected = 0;
        for (int i=0;i<values.length;i++) if(values[i].equals(current)) selected=i;
        new android.app.AlertDialog.Builder(this)
            .setTitle("Photo Quality")
            .setSingleChoiceItems(labels, selected, (dialog, which) -> {
                String choice = values[which];
                getPreferences(MODE_PRIVATE).edit().putString(PREF_PHOTO_QUALITY, choice).apply();
                updatePhotoQualityStatus();
                if (cameraProvider != null && cameraPreview != null) {
                    try {
                        imageCapture = buildImageCapture();
                        bindSelectedCamera();
                    } catch (Exception e) {
                        Toast.makeText(this, "Could not apply photo quality: " + e.getMessage(), Toast.LENGTH_LONG).show();
                    }
                }
                Toast.makeText(this, "Photo quality: " + getPhotoQualityLabel(), Toast.LENGTH_SHORT).show();
                dialog.dismiss();
            })
            .setNegativeButton("CANCEL", null)
            .show();
    }

    private void startCameraAndLocation() {
        ListenableFuture<ProcessCameraProvider> future = ProcessCameraProvider.getInstance(this);
        future.addListener(() -> {
            try {
                cameraProvider = future.get();
                cameraPreview = new Preview.Builder().build();
                cameraPreview.setSurfaceProvider(previewView.getSurfaceProvider());
                imageCapture = buildImageCapture();
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
    private void updateFlashSettingsStatus() {
        if (flashSettingsStatus != null) {
            flashSettingsStatus.setText(flashOn ? "ON" : "OFF");
            flashSettingsStatus.setTextColor(flashOn ? 0xFF63D99A : GOLD);
            flashSettingsStatus.setBackground(shape(flashOn ? 0x333A9B70 : 0x332C405A,
                flashOn ? 0x8870D6A0 : 0x667E8EA5, 20));
        }
    }
    private void toggleFlash() {
        if (activeCamera == null) {
            Toast.makeText(this, "Camera is still starting. Please wait.", Toast.LENGTH_SHORT).show();
            return;
        }
        if (useFrontCamera || !activeCamera.getCameraInfo().hasFlashUnit()) {
            flashOn = false;
            syncFlashControl();
            updateFlashSettingsStatus();
            Toast.makeText(this, "Flash is available only on the rear camera on this phone.", Toast.LENGTH_SHORT).show();
            return;
        }
        final boolean requested = !flashOn;
        flashButton.setEnabled(false);
        activeCamera.getCameraControl().enableTorch(requested).addListener(() -> runOnUiThread(() -> {
            flashOn = requested;
            syncFlashControl();
            updateFlashSettingsStatus();
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
    private void drawGpsStampIcon(Canvas canvas, Paint paint, int kind, float cx, float cy, float size) {
        paint.setColor(Color.WHITE); paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(Math.max(2f, size * 0.10f)); paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        if (kind == 0) { // coordinates: crosshair / target
            canvas.drawCircle(cx, cy, size*0.30f, paint);
            canvas.drawLine(cx-size*0.55f,cy,cx-size*0.20f,cy,paint);
            canvas.drawLine(cx+size*0.20f,cy,cx+size*0.55f,cy,paint);
            canvas.drawLine(cx,cy-size*0.55f,cx,cy-size*0.20f,paint);
            canvas.drawLine(cx,cy+size*0.20f,cx,cy+size*0.55f,paint);
        } else if (kind == 1) { // location pin
            Path pin = new Path(); pin.moveTo(cx,cy+size*0.58f);
            pin.cubicTo(cx-size*0.12f,cy+size*0.30f,cx-size*0.52f,cy-size*0.05f,cx-size*0.52f,cy-size*0.28f);
            pin.cubicTo(cx-size*0.52f,cy-size*0.92f,cx+size*0.52f,cy-size*0.92f,cx+size*0.52f,cy-size*0.28f);
            pin.cubicTo(cx+size*0.52f,cy-size*0.05f,cx+size*0.12f,cy+size*0.30f,cx,cy+size*0.58f);
            canvas.drawPath(pin,paint); canvas.drawCircle(cx,cy-size*0.30f,size*0.14f,paint);
        } else if (kind == 2) { // calendar
            RectF r = new RectF(cx-size*0.48f,cy-size*0.40f,cx+size*0.48f,cy+size*0.42f);
            canvas.drawRoundRect(r,size*0.10f,size*0.10f,paint);
            canvas.drawLine(r.left,cy-size*0.12f,r.right,cy-size*0.12f,paint);
            canvas.drawLine(cx-size*0.22f,cy-size*0.55f,cx-size*0.22f,cy-size*0.28f,paint);
            canvas.drawLine(cx+size*0.22f,cy-size*0.55f,cx+size*0.22f,cy-size*0.28f,paint);
        } else { // Wi-Fi
            RectF a = new RectF(cx-size*0.58f,cy-size*0.48f,cx+size*0.58f,cy+size*0.60f);
            canvas.drawArc(a,225,90,false,paint);
            RectF b = new RectF(cx-size*0.34f,cy-size*0.22f,cx+size*0.34f,cy+size*0.43f);
            canvas.drawArc(b,225,90,false,paint);
            canvas.drawCircle(cx,cy+size*0.34f,size*0.07f,paint);
        }
        paint.setStyle(Paint.Style.FILL);
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
        float scale = Math.max(0.72f, marked.getWidth() / 1080f), pad = 29f * scale, line = 50f * scale;
        int qrSize = Math.round(330f * scale);
        float boxHeight = Math.max(pad * 1.4f + line * (showIp ? 7.05f : 6.2f), qrSize + pad * 1.4f); // Tighter top/bottom card margins; content and QR remain safely inside.
        float top = marked.getHeight() - boxHeight - pad;
        // Layered premium card: soft shadow, deep navy face, gold outer keyline and fine inner highlight.
        // Do not paint an opaque shadow fill: it would cancel the glass transparency.
        Paint shadow = new Paint(Paint.ANTI_ALIAS_FLAG); shadow.setColor(0x55304058);
        shadow.setStyle(Paint.Style.STROKE); shadow.setStrokeWidth(2f*scale);
        shadow.setShadowLayer(10f*scale, 0f, 4f*scale, 0x66000000);
        canvas.drawRoundRect(pad, top, marked.getWidth()-pad, marked.getHeight()-pad, 25f*scale, 25f*scale, shadow);
        Paint bg = new Paint(Paint.ANTI_ALIAS_FLAG); bg.setColor(0x66071833); // 40% navy opacity / 60% transparent; QR stays opaque white.
        canvas.drawRoundRect(pad+2f*scale, top+2f*scale, marked.getWidth()-pad-2f*scale, marked.getHeight()-pad-2f*scale, 23f*scale, 23f*scale, bg);
        Paint gold = new Paint(Paint.ANTI_ALIAS_FLAG); gold.setColor(0xFFE4BD68);
        gold.setStyle(Paint.Style.STROKE); gold.setStrokeWidth(5.5f*scale);
        canvas.drawRoundRect(pad+2f*scale, top+2f*scale, marked.getWidth()-pad-2f*scale,
            marked.getHeight()-pad-2f*scale, 23f*scale, 23f*scale, gold);
        Paint innerKeyline = new Paint(Paint.ANTI_ALIAS_FLAG); innerKeyline.setColor(0x668F713C);
        innerKeyline.setStyle(Paint.Style.STROKE); innerKeyline.setStrokeWidth(1f*scale);
        canvas.drawRoundRect(pad+9f*scale, top+9f*scale, marked.getWidth()-pad-9f*scale,
            marked.getHeight()-pad-9f*scale, 18f*scale, 18f*scale, innerKeyline);
        gold.setStyle(Paint.Style.FILL);
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG); p.setColor(Color.WHITE);
        p.setTypeface(Typeface.create("sans-serif",Typeface.BOLD));
        float x=pad*1.8f, y=top+pad*0.95f+line*0.52f;
        float qx=marked.getWidth()-pad-qrSize-24f*scale;
        float textMax=Math.max(180f*scale,qx-x-22f*scale);
        // Responsive brand line: preserve Key white / Dhan gold / raised trademark.
        p.setTextSize(46f*scale); p.setColor(Color.WHITE);
        canvas.drawText("Key",x,y,p);
        float brandX=x+p.measureText("Key");
        p.setColor(0xFFE7C270); canvas.drawText("Dhan",brandX,y,p);
        float tmX=brandX+p.measureText("Dhan");
        p.setTextSize(16f*scale); canvas.drawText("™",tmX+3f*scale,y-23f*scale,p);
        p.setTextSize(33f*scale); p.setColor(Color.WHITE);
        String title="Real Time GPS Photo";
        p.setTextSize(Math.min(33f*scale, Math.max(22f*scale, textMax*0.052f)));
        canvas.drawText(title,Math.min(tmX+24f*scale, qx-textMax*0.68f),y,p);
        y+=line*0.92f;
        p.setColor(0xFFFFD36A); p.setTextSize(27f*scale); p.setFakeBoldText(true);
        canvas.drawText("LIVE LOCATION  •  GPS ACCURACY",x+textMax*0.16f,y,p);
        y+=line*0.28f;
        Paint divider = new Paint(Paint.ANTI_ALIAS_FLAG); divider.setColor(0xBFE7C270); divider.setStrokeWidth(1.6f*scale);
        canvas.drawLine(x,y,qx-12f*scale,y,divider);
        y+=line*0.78f;
        float iconX=x+17f*scale, textX=x+54f*scale, iconSize=23f*scale;
        p.setTypeface(Typeface.create("sans-serif",Typeface.NORMAL)); p.setFakeBoldText(false);
        p.setColor(Color.WHITE); p.setTextSize(30f*scale);
        Paint iconDisc = new Paint(Paint.ANTI_ALIAS_FLAG); iconDisc.setColor(0xFF203B5B);
        canvas.drawCircle(iconX,y-8f*scale,17f*scale,iconDisc);
        Paint iconRing = new Paint(Paint.ANTI_ALIAS_FLAG); iconRing.setColor(0xFFB99550);
        iconRing.setStyle(Paint.Style.STROKE); iconRing.setStrokeWidth(1.2f*scale);
        canvas.drawCircle(iconX,y-8f*scale,17f*scale,iconRing);
        drawGpsStampIcon(canvas,p,0,iconX,y-6f*scale,iconSize);
        String coords=String.format(Locale.US,"LAT  %.6f     LONG  %.6f",loc.getLatitude(),loc.getLongitude());
        p.setTextSize(Math.min(30f*scale, textMax*0.043f));
        canvas.drawText(coords,textX,y,p);
        y+=line*0.92f;
        canvas.drawCircle(iconX,y-7f*scale,15f*scale,iconDisc);
        canvas.drawCircle(iconX,y-7f*scale,15f*scale,iconRing);
        drawGpsStampIcon(canvas,p,1,iconX,y-6f*scale,iconSize);
        p.setTextSize(28f*scale);
        String addressText=address == null ? "" : address;
        int addressStart=0;
        while(addressStart<addressText.length()) {
            int count=p.breakText(addressText,addressStart,addressText.length(),true,textMax-(textX-x),null);
            if(count<=0) break;
            canvas.drawText(addressText,addressStart,addressStart+count,textX,y,p);
            addressStart+=count;
            if(addressStart<addressText.length()) y+=line*0.72f;
        }
        y+=line*0.88f;
        canvas.drawCircle(iconX,y-7f*scale,15f*scale,iconDisc);
        canvas.drawCircle(iconX,y-7f*scale,15f*scale,iconRing);
        drawGpsStampIcon(canvas,p,2,iconX,y-6f*scale,iconSize);
        p.setTextSize(28f*scale); p.setColor(0xFFF4F6FA);
        canvas.drawText(date,textX,y,p);
        y+=line*0.42f;
        // Visually separate the national identity and optional network metadata from live location details.
        Paint footerDivider = new Paint(Paint.ANTI_ALIAS_FLAG);
        footerDivider.setColor(0xFFE7C270); footerDivider.setStrokeWidth(2.4f*scale);
        canvas.drawLine(x,y,qx-12f*scale,y,footerDivider);
        y+=line*0.78f;
        p.setColor(0xFFFFD36A); p.setTypeface(Typeface.create("sans-serif",Typeface.BOLD)); p.setTextSize(29f*scale);
        canvas.drawText("Made in India",textX,y,p);
        float flagX=textX+p.measureText("Made in India")+12f*scale, flagY=y-15f*scale;
        Paint flagPaint=new Paint(Paint.ANTI_ALIAS_FLAG);
        flagPaint.setColor(0xFFFF9933); canvas.drawRect(flagX,flagY,flagX+23f*scale,flagY+5f*scale,flagPaint);
        flagPaint.setColor(Color.WHITE); canvas.drawRect(flagX,flagY+5f*scale,flagX+23f*scale,flagY+10f*scale,flagPaint);
        flagPaint.setColor(0xFF138808); canvas.drawRect(flagX,flagY+10f*scale,flagX+23f*scale,flagY+15f*scale,flagPaint);
        flagPaint.setColor(0xFF000080); canvas.drawCircle(flagX+11.5f*scale,flagY+7.5f*scale,2f*scale,flagPaint);
        if (showIp) {
            y+=line*0.88f;
            drawGpsStampIcon(canvas,p,3,iconX,y-6f*scale,iconSize);
            p.setColor(0xFFF4F6FA); p.setTypeface(Typeface.create("sans-serif",Typeface.NORMAL)); p.setTextSize(27f*scale);
            canvas.drawText("PUBLIC IP  " + (publicIp == null ? "Not Available" : publicIp),textX,y,p);
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
            // Compact premium navy badge with a distinct gold keyline, matching the approved reference.
            // Smaller center badge leaves more QR modules exposed; larger wordmark stays legible.
            float logoW=qrSize*0.42f, logoH=qrSize*0.17f, logoCx=qrSize/2f, logoCy=qrSize/2f;
            Paint logoGold = new Paint(Paint.ANTI_ALIAS_FLAG); logoGold.setColor(GOLD);
            qrCanvas.drawRoundRect(logoCx-logoW/2f-3.5f*scale,logoCy-logoH/2f-3.5f*scale,
                logoCx+logoW/2f+3.5f*scale,logoCy+logoH/2f+3.5f*scale,12f*scale,12f*scale,logoGold);
            Paint logoP = new Paint(Paint.ANTI_ALIAS_FLAG); logoP.setColor(NAVY);
            qrCanvas.drawRoundRect(logoCx-logoW/2f,logoCy-logoH/2f,logoCx+logoW/2f,logoCy+logoH/2f,9f*scale,9f*scale,logoP);
            logoP.setTypeface(Typeface.create("sans-serif",Typeface.BOLD));
            logoP.setTextSize(qrSize*0.092f); logoP.setTextAlign(Paint.Align.LEFT);
            String keyText="Key", dhanText="Dhan";
            float keyWidth=logoP.measureText(keyText), dhanWidth=logoP.measureText(dhanText);
            float tmWidth=qrSize*0.030f, fullWidth=keyWidth+dhanWidth+tmWidth+qrSize*0.012f;
            float textStart=logoCx-fullWidth/2f, logoTextY=logoCy+qrSize*0.026f;
            logoP.setColor(Color.WHITE); qrCanvas.drawText(keyText,textStart,logoTextY,logoP);
            logoP.setColor(0xFFE7C270); qrCanvas.drawText(dhanText,textStart+keyWidth,logoTextY,logoP);
            logoP.setTextSize(qrSize*0.034f); qrCanvas.drawText("™",textStart+keyWidth+dhanWidth+qrSize*0.012f,logoTextY-qrSize*0.034f,logoP);
            float qy=top+(boxHeight-qrSize)/2f;
            Paint qrFrame = new Paint(Paint.ANTI_ALIAS_FLAG); qrFrame.setColor(GOLD);
            canvas.drawRoundRect(qx-7f*scale,qy-7f*scale,qx+qrSize+7f*scale,qy+qrSize+7f*scale,10f*scale,10f*scale,qrFrame);
            Paint qrBg = new Paint(Paint.ANTI_ALIAS_FLAG); qrBg.setColor(Color.WHITE);
            canvas.drawRoundRect(qx-3f*scale,qy-3f*scale,qx+qrSize+3f*scale,qy+qrSize+3f*scale,7f*scale,7f*scale,qrBg);
            canvas.drawBitmap(qr,qx,qy,null); qr.recycle();
        } catch (Exception qrError) {
            android.util.Log.e("KeyDhanGPS","Could not generate location QR",qrError);
        }
        pendingPhoto = new File(getCacheDir(),"keydhan-preview-"+System.currentTimeMillis()+".jpg");
        try (OutputStream out = new java.io.FileOutputStream(pendingPhoto)) {
            marked.compress(Bitmap.CompressFormat.JPEG,getPhotoQualityValue(),out);
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

cat > "$PKG/DocumentScannerActivity.java" <<'EOF'
package com.keydhan.app;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.IntentSenderRequest;
import androidx.activity.result.contract.ActivityResultContracts;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner;
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;
import java.util.HashMap;

import android.Manifest;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.pdf.PdfDocument;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.view.Gravity;
import android.view.View;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import androidx.activity.ComponentActivity;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import com.google.common.util.concurrent.ListenableFuture;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Locale;

public class DocumentScannerActivity extends ComponentActivity {
    private static final int REQ_CAMERA=7301, REQ_IMPORT=7302;
    private static final int NAVY=0xFF071228, GOLD=0xFFD2A952;
    private final ArrayList<File> pages=new ArrayList<>();
    private PreviewView previewView;
    private ImageCapture capture;
    private TextView count;
    private LinearLayout thumbnails;
    private String quality="Balanced";
    private final HashMap<String,Integer> pageRotations=new HashMap<>();
    private final HashMap<String,Integer> pageFilters=new HashMap<>();
    private ActivityResultLauncher<IntentSenderRequest> autoScanLauncher;

    @Override public void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setStatusBarColor(NAVY);
        getWindow().setNavigationBarColor(NAVY);
        autoScanLauncher=registerForActivityResult(new ActivityResultContracts.StartIntentSenderForResult(), result -> {
            if(result.getResultCode()!=RESULT_OK || result.getData()==null) return;
            GmsDocumentScanningResult scan=GmsDocumentScanningResult.fromActivityResultIntent(result.getData());
            if(scan==null || scan.getPdf()==null) { Toast.makeText(this,"No scanned PDF returned",Toast.LENGTH_LONG).show(); return; }
            try {
                Uri source=scan.getPdf().getUri();
                String name="KeyDhan_AutoScan_"+new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date())+".pdf";
                ContentValues values=new ContentValues();
                values.put(MediaStore.Downloads.DISPLAY_NAME,name);
                values.put(MediaStore.Downloads.MIME_TYPE,"application/pdf");
                values.put(MediaStore.Downloads.RELATIVE_PATH,Environment.DIRECTORY_DOCUMENTS+"/KeyDhan Scanner");
                Uri dest=getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI,values);
                if(dest==null) throw new Exception("Cannot create PDF");
                try(InputStream in=getContentResolver().openInputStream(source); OutputStream out=getContentResolver().openOutputStream(dest)) {
                    byte[] buf=new byte[8192]; int len; while((len=in.read(buf))>0) out.write(buf,0,len);
                }
                Toast.makeText(this,"Auto-scanned PDF saved in Documents/KeyDhan Scanner",Toast.LENGTH_LONG).show();
                Intent share=new Intent(Intent.ACTION_SEND); share.setType("application/pdf");
                share.putExtra(Intent.EXTRA_STREAM,dest); share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                startActivity(Intent.createChooser(share,"Share scanned PDF"));
            } catch(Exception e) { Toast.makeText(this,"Auto scan export failed: "+e.getMessage(),Toast.LENGTH_LONG).show(); }
        });
        buildUi();
    }
    private int dp(float value){return (int)(value*getResources().getDisplayMetrics().density+0.5f);}
    private android.graphics.drawable.GradientDrawable bg(int color,int stroke,int radius) {
        android.graphics.drawable.GradientDrawable d=new android.graphics.drawable.GradientDrawable();
        d.setColor(color); d.setCornerRadius(radius*getResources().getDisplayMetrics().density);
        if(stroke!=0)d.setStroke((int)getResources().getDisplayMetrics().density,stroke);
        return d;
    }
    private TextView text(String s,int size,int color,boolean bold) {
        TextView t=new TextView(this); t.setText(s); t.setTextSize(size); t.setTextColor(color);
        if(bold)t.setTypeface(null,android.graphics.Typeface.BOLD); return t;
    }
    private Button button(String s) {
        Button b=new Button(this); b.setText(s); b.setTextColor(Color.WHITE); b.setTextSize(13);
        b.setAllCaps(false); b.setGravity(Gravity.CENTER); b.setIncludeFontPadding(false); b.setMinHeight(0); b.setMinimumHeight(0); b.setMinWidth(0); b.setMinimumWidth(0); b.setPadding(12,8,12,8); b.setMaxLines(2); b.setBackground(bg(0xFF172640,GOLD,18)); return b;
    }
    private void applySafeInsets(View root) {
        ViewCompat.setOnApplyWindowInsetsListener(root,(view,insets)->{
            androidx.core.graphics.Insets bars=insets.getInsets(WindowInsetsCompat.Type.systemBars());
            view.setPadding(0,bars.top,0,bars.bottom);
            return insets;
        });
    }
    private void buildUi() {
        FrameLayout root=new FrameLayout(this);
        root.setBackgroundColor(NAVY);
        LinearLayout page=new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(16),dp(12),dp(16),dp(10));
        LinearLayout header=new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setPadding(dp(18),dp(16),dp(18),dp(14));
        header.setBackground(bg(0xFF071228,GOLD,22));
        header.addView(text("KeyDhan™",23,Color.WHITE,true));
        header.addView(text("DOCUMENT SCANNER  •  PRIVATE & SECURE",11,GOLD,true));
        page.addView(header,new LinearLayout.LayoutParams(-1,-2));
        ScrollView middle=new ScrollView(this);
        middle.setFillViewport(true);
        middle.setClipToPadding(false);
        LinearLayout center=new LinearLayout(this);
        center.setOrientation(LinearLayout.VERTICAL);
        center.setGravity(Gravity.CENTER);
        center.setPadding(dp(14),dp(20),dp(14),dp(20));
        TextView symbol=text("▤",58,GOLD,true);
        symbol.setGravity(Gravity.CENTER);
        center.addView(symbol,new LinearLayout.LayoutParams(-1,-2));
        TextView title=text("Turn paper into perfect PDFs",22,Color.WHITE,true);
        title.setGravity(Gravity.CENTER);
        title.setPadding(0,dp(10),0,0);
        center.addView(title);
        TextView desc=text("Scan documents, receipts, notes and IDs. Auto-detect edges, straighten pages and create a clean PDF — right on your device.",14,0xFFD5DCE8,false);
        desc.setGravity(Gravity.CENTER);
        desc.setLineSpacing(dp(3),1f);
        desc.setPadding(dp(6),dp(12),dp(6),dp(12));
        center.addView(desc);
        TextView privacy=text("Your scans stay on this device",12,GOLD,true);
        privacy.setGravity(Gravity.CENTER);
        privacy.setPadding(0,dp(8),0,0);
        center.addView(privacy);
        middle.addView(center,new ScrollView.LayoutParams(-1,-1));
        page.addView(middle,new LinearLayout.LayoutParams(-1,0,1f));
        LinearLayout actions=new LinearLayout(this);
        actions.setOrientation(LinearLayout.VERTICAL);
        actions.setPadding(dp(2),dp(8),dp(2),dp(4));
        Button auto=button("✦   Auto Scan Document");
        auto.setTextColor(NAVY); auto.setTextSize(16);
        auto.setBackground(bg(GOLD,0xFFFFE7A8,24));
        Button manual=button("▣   Scan with Camera");
        Button imp=button("＋   Import from Gallery");
        actions.addView(auto,new LinearLayout.LayoutParams(-1,dp(54)));
        LinearLayout.LayoutParams mp=new LinearLayout.LayoutParams(-1,dp(50)); mp.topMargin=dp(9);
        actions.addView(manual,mp);
        LinearLayout.LayoutParams ip=new LinearLayout.LayoutParams(-1,dp(50)); ip.topMargin=dp(8);
        actions.addView(imp,ip);
        page.addView(actions,new LinearLayout.LayoutParams(-1,-2));
        root.addView(page,new FrameLayout.LayoutParams(-1,-1));
        applySafeInsets(root);
        setContentView(root);
        auto.setOnClickListener(v->launchAutoScan());
        manual.setOnClickListener(v->{
            if(ContextCompat.checkSelfPermission(this,Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED)
                ActivityCompat.requestPermissions(this,new String[]{Manifest.permission.CAMERA},REQ_CAMERA);
            else buildCameraUi();
        });
        imp.setOnClickListener(v->pickImages());
    }
    private void buildCameraUi() {
        FrameLayout root=new FrameLayout(this); root.setBackgroundColor(Color.BLACK);
        previewView=new PreviewView(this); previewView.setScaleType(PreviewView.ScaleType.FILL_CENTER);
        root.addView(previewView,new FrameLayout.LayoutParams(-1,-1));
        LinearLayout header=new LinearLayout(this); header.setOrientation(LinearLayout.VERTICAL);
        header.setPadding(dp(16),dp(14),dp(16),dp(12)); header.setBackground(bg(0xEE071228,GOLD,22));
        header.addView(text("KeyDhan™  DOC SCANNER",21,Color.WHITE,true));
        header.addView(text("Private • On-device processing",12,GOLD,true));
        FrameLayout.LayoutParams hp=new FrameLayout.LayoutParams(-1,-2,Gravity.TOP);
        hp.setMargins(dp(12),dp(12),dp(12),0); root.addView(header,hp);

        LinearLayout bottom=new LinearLayout(this); bottom.setOrientation(LinearLayout.VERTICAL);
        bottom.setPadding(dp(12),dp(8),dp(12),dp(12)); bottom.setBackground(bg(0xF2071228,GOLD,24));
        LinearLayout top=new LinearLayout(this); top.setGravity(Gravity.CENTER_VERTICAL);
        Button imp=button("＋ Import"), q=button("Quality: "+quality), auto=button("Auto Scan");
        count=text("0 pages",13,Color.WHITE,true);
        top.addView(imp,new LinearLayout.LayoutParams(0,dp(44),1));
        top.addView(q,new LinearLayout.LayoutParams(0,46,1));
        top.addView(auto,new LinearLayout.LayoutParams(0,46,1)); top.addView(count);
        bottom.addView(top);
        thumbnails=new LinearLayout(this); thumbnails.setOrientation(LinearLayout.HORIZONTAL);
        ScrollView sc=new ScrollView(this); sc.setHorizontalScrollBarEnabled(false); sc.addView(thumbnails);
        bottom.addView(sc,new LinearLayout.LayoutParams(-1,dp(66)));
        LinearLayout actions=new LinearLayout(this); actions.setGravity(Gravity.CENTER);
        Button snap=button("●  Scan Page"), pdf=button("Export PDF");
        snap.setTextSize(17); snap.setTextColor(NAVY); snap.setBackground(bg(GOLD,0xFFFFE7A8,32));
        actions.addView(snap,new LinearLayout.LayoutParams(0,dp(54),1.2f));
        actions.addView(pdf,new LinearLayout.LayoutParams(0,dp(54),1));
        bottom.addView(actions);
        root.addView(bottom,new FrameLayout.LayoutParams(-1,-2,Gravity.BOTTOM));
        applySafeInsets(root);
        setContentView(root);
        auto.setOnClickListener(v->launchAutoScan());
        snap.setOnClickListener(v->takePage());
        imp.setOnClickListener(v->pickImages());
        q.setOnClickListener(v->{quality=quality.equals("Balanced")?"High":quality.equals("High")?"Small Size":"Balanced";q.setText("Quality: "+quality);});
        pdf.setOnClickListener(v->makePdf());
        startCamera();
    }
    private void launchAutoScan() {
        GmsDocumentScannerOptions options=new GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(100)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_PDF)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build();
        GmsDocumentScanner scanner=GmsDocumentScanning.getClient(options);
        scanner.getStartScanIntent(this).addOnSuccessListener(sender ->
            autoScanLauncher.launch(new IntentSenderRequest.Builder(sender).build()))
            .addOnFailureListener(e -> Toast.makeText(this,"Auto Scan unavailable: "+e.getMessage(),Toast.LENGTH_LONG).show());
    }
    private void startCamera() {
        ListenableFuture<ProcessCameraProvider> f=ProcessCameraProvider.getInstance(this);
        f.addListener(()->{try{
            ProcessCameraProvider p=f.get(); Preview preview=new Preview.Builder().build();
            preview.setSurfaceProvider(previewView.getSurfaceProvider());
            capture=new ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY).setJpegQuality(100).build();
            p.unbindAll(); p.bindToLifecycle(this,CameraSelector.DEFAULT_BACK_CAMERA,preview,capture);
        }catch(Exception e){Toast.makeText(this,"Camera unavailable: "+e.getMessage(),Toast.LENGTH_LONG).show();}},ContextCompat.getMainExecutor(this));
    }
    private void takePage() {
        if(capture==null){Toast.makeText(this,"Camera is starting",Toast.LENGTH_SHORT).show();return;}
        File file=new File(getCacheDir(),"scan_"+System.currentTimeMillis()+".jpg");
        capture.takePicture(new ImageCapture.OutputFileOptions.Builder(file).build(),ContextCompat.getMainExecutor(this),
            new ImageCapture.OnImageSavedCallback(){
                @Override public void onImageSaved(ImageCapture.OutputFileResults r){pages.add(file);refresh();}
                @Override public void onError(ImageCaptureException e){Toast.makeText(DocumentScannerActivity.this,"Scan failed: "+e.getMessage(),Toast.LENGTH_LONG).show();}
            });
    }
    private void pickImages() {
        Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT); i.setType("image/*");
        i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE,true); i.addCategory(Intent.CATEGORY_OPENABLE);
        startActivityForResult(i,REQ_IMPORT);
    }
    @Override protected void onActivityResult(int req,int result,Intent data) {
        super.onActivityResult(req,result,data);
        if(req!=REQ_IMPORT||result!=RESULT_OK||data==null)return;
        try{
            if(data.getClipData()!=null)for(int n=0;n<data.getClipData().getItemCount();n++)copyImage(data.getClipData().getItemAt(n).getUri());
            else if(data.getData()!=null)copyImage(data.getData());
            refresh();
        }catch(Exception e){Toast.makeText(this,"Import failed: "+e.getMessage(),Toast.LENGTH_LONG).show();}
    }
    private void copyImage(Uri uri)throws Exception {
        File f=new File(getCacheDir(),"import_"+System.currentTimeMillis()+".jpg");
        try(InputStream in=getContentResolver().openInputStream(uri);FileOutputStream out=new FileOutputStream(f)){
            byte[] b=new byte[8192];int n;while((n=in.read(b))>0)out.write(b,0,n);
        } pages.add(f);
    }
    private void refresh() {
        count.setText(pages.size()+" pages"); thumbnails.removeAllViews();
        for(int i=0;i<pages.size();i++){final int at=i;ImageView v=new ImageView(this);
            Bitmap b=BitmapFactory.decodeFile(pages.get(i).getAbsolutePath());
            if(b!=null){v.setImageBitmap(Bitmap.createScaledBitmap(b,dp(64),dp(70),true));b.recycle();}
            v.setScaleType(ImageView.ScaleType.CENTER_CROP);v.setPadding(dp(3),dp(3),dp(3),dp(3));
            v.setOnClickListener(x->openPageEditor(at));
            thumbnails.addView(v,new LinearLayout.LayoutParams(dp(72),dp(76)));
        }
    }

    private void openPageEditor(int position) {
        if(position<0||position>=pages.size()) return;
        File file=pages.get(position);
        LinearLayout panel=new LinearLayout(this); panel.setOrientation(LinearLayout.VERTICAL); panel.setPadding(dp(12),dp(8),dp(12),dp(8));
        ImageView preview=new ImageView(this); preview.setAdjustViewBounds(true); preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
        Bitmap initial=BitmapFactory.decodeFile(file.getAbsolutePath()); if(initial!=null){preview.setImageBitmap(initial);initial.recycle();}
        panel.addView(preview,new LinearLayout.LayoutParams(-1,dp(220)));
        TextView hint=text("Page "+(position+1)+" of "+pages.size()+" • Edits are applied when exporting",12,0xFFD5DCE8,false); panel.addView(hint);
        LinearLayout row1=new LinearLayout(this); row1.setGravity(Gravity.CENTER);
        Button rotate=button("↻ Rotate"), filter=button("Filter: "+filterName(file)), ocr=button("OCR Text");
        row1.addView(rotate,new LinearLayout.LayoutParams(0,dp(48),1)); row1.addView(filter,new LinearLayout.LayoutParams(0,48,1)); row1.addView(ocr,new LinearLayout.LayoutParams(0,48,1)); panel.addView(row1);
        LinearLayout row2=new LinearLayout(this); row2.setGravity(Gravity.CENTER);
        Button left=button("← Move"), right=button("Move →"), del=button("Delete");
        row2.addView(left,new LinearLayout.LayoutParams(0,48,1)); row2.addView(right,new LinearLayout.LayoutParams(0,48,1)); row2.addView(del,new LinearLayout.LayoutParams(0,48,1)); panel.addView(row2);
        android.app.AlertDialog dialog=new android.app.AlertDialog.Builder(this).setTitle("Edit scanned page").setView(panel).setPositiveButton("Done",(d,w)->refresh()).create();
        rotate.setOnClickListener(v->{pageRotations.put(file.getAbsolutePath(),(pageRotations.getOrDefault(file.getAbsolutePath(),0)+90)%360); Bitmap bm=renderPage(file); if(bm!=null) preview.setImageBitmap(bm);});
        filter.setOnClickListener(v->{pageFilters.put(file.getAbsolutePath(),(pageFilters.getOrDefault(file.getAbsolutePath(),0)+1)%3); filter.setText("Filter: "+filterName(file)); Bitmap bm=renderPage(file); if(bm!=null) preview.setImageBitmap(bm);});
        left.setOnClickListener(v->{if(position>0){java.util.Collections.swap(pages,position,position-1);dialog.dismiss();refresh();openPageEditor(position-1);}});
        right.setOnClickListener(v->{if(position<pages.size()-1){java.util.Collections.swap(pages,position,position+1);dialog.dismiss();refresh();openPageEditor(position+1);}});
        del.setOnClickListener(v->{pages.remove(file);pageRotations.remove(file.getAbsolutePath());pageFilters.remove(file.getAbsolutePath());file.delete();dialog.dismiss();refresh();});
        ocr.setOnClickListener(v->runOcr(file));
        dialog.show();
    }
    private String filterName(File f){int x=pageFilters.getOrDefault(f.getAbsolutePath(),0);return x==0?"Original":x==1?"Grayscale":"B&W";}
    private Bitmap renderPage(File f){
        try {
            Bitmap src=BitmapFactory.decodeFile(f.getAbsolutePath()); if(src==null)return null;
            android.graphics.Matrix matrix=new android.graphics.Matrix(); matrix.postRotate(pageRotations.getOrDefault(f.getAbsolutePath(),0));
            Bitmap rotated=Bitmap.createBitmap(src,0,0,src.getWidth(),src.getHeight(),matrix,true); if(rotated!=src)src.recycle();
            int mode=pageFilters.getOrDefault(f.getAbsolutePath(),0); if(mode==0)return rotated;
            Bitmap out=Bitmap.createBitmap(rotated.getWidth(),rotated.getHeight(),Bitmap.Config.ARGB_8888);
            if(mode==1){Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);android.graphics.ColorMatrix cm=new android.graphics.ColorMatrix();cm.setSaturation(0);p.setColorFilter(new android.graphics.ColorMatrixColorFilter(cm));new android.graphics.Canvas(out).drawBitmap(rotated,0,0,p);}
            else {int w=rotated.getWidth(),h=rotated.getHeight();int[] px=new int[w*h];rotated.getPixels(px,0,w,0,0,w,h);for(int k=0;k<px.length;k++){int c=px[k],gray=(Color.red(c)*30+Color.green(c)*59+Color.blue(c)*11)/100;px[k]=gray>165?Color.WHITE:Color.BLACK;}out.setPixels(px,0,w,0,0,w,h);}
            rotated.recycle();return out;
        } catch(Exception e){return null;}
    }
    private void runOcr(File file){
        try {
            InputImage image=InputImage.fromFilePath(this,Uri.fromFile(file));
            TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS).process(image).addOnSuccessListener(result->{
                String value=result.getText(); if(value.trim().isEmpty())value="No readable text found."; final String extracted=value;
                android.widget.EditText box=new android.widget.EditText(this);box.setText(extracted);box.setTextIsSelectable(true);box.setMinHeight(180);
                new android.app.AlertDialog.Builder(this).setTitle("Extracted text").setView(box).setPositiveButton("Copy",(d,w)->{((android.content.ClipboardManager)getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(android.content.ClipData.newPlainText("Scanned text",extracted));Toast.makeText(this,"Text copied",Toast.LENGTH_SHORT).show();}).setNegativeButton("Close",null).show();
            }).addOnFailureListener(e->Toast.makeText(this,"OCR failed: "+e.getMessage(),Toast.LENGTH_LONG).show());
        } catch(Exception e){Toast.makeText(this,"OCR could not start: "+e.getMessage(),Toast.LENGTH_LONG).show();}
    }
    private Bitmap prepare(File f)throws Exception {
        Bitmap edited=renderPage(f);
        if(edited==null)throw new Exception("Unable to read edited page");
        int max=quality.equals("High")?2800:quality.equals("Balanced")?2200:1500;
        int longest=Math.max(edited.getWidth(),edited.getHeight());
        if(longest>max){
            float scale=(float)max/longest;
            Bitmap smaller=Bitmap.createScaledBitmap(edited,Math.max(1,(int)(edited.getWidth()*scale)),Math.max(1,(int)(edited.getHeight()*scale)),true);
            edited.recycle();edited=smaller;
        }
        if(quality.equals("Small Size")){
            Bitmap gray=Bitmap.createBitmap(edited.getWidth(),edited.getHeight(),Bitmap.Config.ARGB_8888);
            Paint p=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);
            android.graphics.ColorMatrix cm=new android.graphics.ColorMatrix();cm.setSaturation(0);
            p.setColorFilter(new android.graphics.ColorMatrixColorFilter(cm));
            new android.graphics.Canvas(gray).drawBitmap(edited,0,0,p);edited.recycle();edited=gray;
        }
        return edited;
    }
    private void makePdf() {
        if(pages.isEmpty()){Toast.makeText(this,"Scan or import at least one page",Toast.LENGTH_SHORT).show();return;}
        PdfDocument pdf=new PdfDocument();
        try{
            int n=1;for(File f:pages){Bitmap b=prepare(f);PdfDocument.Page page=pdf.startPage(new PdfDocument.PageInfo.Builder(b.getWidth(),b.getHeight(),n++).create());
                page.getCanvas().drawBitmap(b,0,0,new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG));pdf.finishPage(page);b.recycle();}
            String name="KeyDhan_Scan_"+new SimpleDateFormat("yyyyMMdd_HHmmss",Locale.US).format(new Date())+".pdf";
            ContentValues v=new ContentValues();v.put(MediaStore.Downloads.DISPLAY_NAME,name);v.put(MediaStore.Downloads.MIME_TYPE,"application/pdf");
            v.put(MediaStore.Downloads.RELATIVE_PATH,Environment.DIRECTORY_DOCUMENTS+"/KeyDhan Scanner");
            Uri uri=getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI,v);if(uri==null)throw new Exception("Cannot create PDF");
            try(OutputStream out=getContentResolver().openOutputStream(uri)){pdf.writeTo(out);}
            Toast.makeText(this,"Saved in Documents/KeyDhan Scanner",Toast.LENGTH_LONG).show();
            Intent share=new Intent(Intent.ACTION_SEND);share.setType("application/pdf");share.putExtra(Intent.EXTRA_STREAM,uri);
            share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);startActivity(Intent.createChooser(share,"Share scanned PDF"));
        }catch(Exception e){Toast.makeText(this,"PDF export failed: "+e.getMessage(),Toast.LENGTH_LONG).show();}
        finally{pdf.close();}
    }
    @Override public void onRequestPermissionsResult(int r,String[] p,int[] g){
        super.onRequestPermissionsResult(r,p,g);
        if(r==REQ_CAMERA&&g.length>0&&g[0]==PackageManager.PERMISSION_GRANTED)buildCameraUi();
        else if(r==REQ_CAMERA){Toast.makeText(this,"Camera permission is required",Toast.LENGTH_LONG).show();finish();}
    }
    @Override protected void onDestroy(){super.onDestroy();for(File f:pages)if(f.exists())f.delete();}
}
EOF
