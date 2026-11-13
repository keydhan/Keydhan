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
        WindowCompat.setDecorFitsSystemWindows(getWindow(), true);
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
    private void buildCameraUi() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        previewView = new PreviewView(this);
        previewView.setScaleType(PreviewView.ScaleType.FILL_CENTER);
        root.addView(previewView, new FrameLayout.LayoutParams(-1, -1));

        // Premium header: system status icons remain in the OS status-bar area.
        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(14, 9, 14, 9);
        header.setBackground(shape(0xF2071228, 0, 0));
        Button exit = button("‹");
        exit.setTextSize(28);
        exit.setContentDescription("Exit GPS Camera");
        exit.setOnClickListener(v -> finish());
        header.addView(exit, new LinearLayout.LayoutParams(46, 46));

        LinearLayout brand = new LinearLayout(this);
        brand.setOrientation(LinearLayout.VERTICAL);
        brand.setGravity(Gravity.CENTER);
        TextView title = text("KEYDHAN™", 17, Color.WHITE, true);
        title.setGravity(Gravity.CENTER);
        TextView subtitle = text("GPS CAMERA", 11, GOLD, true);
        subtitle.setGravity(Gravity.CENTER);
        brand.addView(title);
        brand.addView(subtitle);
        header.addView(brand, new LinearLayout.LayoutParams(0, -2, 1));

        flashButton = button("⚡");
        flashButton.setTextSize(21);
        flashButton.setContentDescription("Toggle flash");
        flashButton.setOnClickListener(v -> toggleFlash());
        header.addView(flashButton, new LinearLayout.LayoutParams(46, 46));
        Button exitRight = button("↗");
        exitRight.setTextSize(18);
        exitRight.setContentDescription("Close camera");
        exitRight.setOnClickListener(v -> finish());
        LinearLayout.LayoutParams exitParams = new LinearLayout.LayoutParams(46, 46);
        exitParams.leftMargin = 7;
        header.addView(exitRight, exitParams);
        root.addView(header, new FrameLayout.LayoutParams(-1, -2, Gravity.TOP));

        // GPS information floats above the camera controls, never in the status bar.
        status = text("●  GPS SEARCHING…", 12, Color.WHITE, true);
        status.setGravity(Gravity.CENTER);
        status.setPadding(14, 12, 14, 12);
        status.setBackground(shape(0xD9071228, GOLD, 24));
        FrameLayout.LayoutParams gpsParams = new FrameLayout.LayoutParams(
            -1, -2, Gravity.BOTTOM);
        gpsParams.setMargins(18, 0, 18, 174);
        root.addView(status, gpsParams);

        LinearLayout bottom = new LinearLayout(this);
        bottom.setOrientation(LinearLayout.VERTICAL);
        bottom.setGravity(Gravity.CENTER_HORIZONTAL);
        bottom.setPadding(16, 14, 16, 15);
        bottom.setBackground(shape(0xF9071228, 0, 28));

        LinearLayout cameraChoices = new LinearLayout(this);
        cameraChoices.setGravity(Gravity.CENTER);
        cameraChoices.setPadding(0, 0, 0, 10);
        rearButton = button("✓  REAR CAMERA");
        frontButton = button("FRONT CAMERA");
        rearButton.setTextSize(12);
        frontButton.setTextSize(12);
        rearButton.setOnClickListener(v -> selectCamera(false));
        frontButton.setOnClickListener(v -> selectCamera(true));
        LinearLayout.LayoutParams choice = new LinearLayout.LayoutParams(0, 46, 1);
        choice.setMargins(3, 0, 3, 0);
        cameraChoices.addView(rearButton, choice);
        cameraChoices.addView(frontButton, choice);
        bottom.addView(cameraChoices);

        LinearLayout shutterRow = new LinearLayout(this);
        shutterRow.setGravity(Gravity.CENTER);
        shutterRow.setPadding(0, 0, 0, 1);
        TextView galleryHint = text("GALLERY", 10, 0xFFE7C270, true);
        galleryHint.setGravity(Gravity.CENTER);
        shutterRow.addView(galleryHint, new LinearLayout.LayoutParams(0, 72, 1));

        captureButton = new Button(this);
        captureButton.setText("●");
        captureButton.setTextSize(29);
        captureButton.setTextColor(NAVY);
        captureButton.setGravity(Gravity.CENTER);
        captureButton.setPadding(0, 0, 0, 2);
        captureButton.setAllCaps(false);
        captureButton.setContentDescription("Take GPS photo");
        GradientDrawable shutter = new GradientDrawable();
        shutter.setShape(GradientDrawable.OVAL);
        shutter.setColor(Color.WHITE);
        shutter.setStroke((int)(5 * getResources().getDisplayMetrics().density), GOLD);
        captureButton.setBackground(shutter);
        captureButton.setElevation(8);
        shutterRow.addView(captureButton, new LinearLayout.LayoutParams(82, 82));

        TextView gpsPhotoLabel = text("GPS PHOTO", 10, 0xFFE7C270, true);
        gpsPhotoLabel.setGravity(Gravity.CENTER);
        shutterRow.addView(gpsPhotoLabel, new LinearLayout.LayoutParams(0, 72, 1));
        bottom.addView(shutterRow);
        TextView hint = text("LOCATION-STAMPED PHOTO", 9, 0xFF9AA8BC, true);
        hint.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams hintParams = new LinearLayout.LayoutParams(-1, -2);
        hintParams.topMargin = 4;
        bottom.addView(hint, hintParams);

        captureButton.setOnClickListener(v -> capturePhoto());
        captureButton.setEnabled(false);
        root.addView(bottom, new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM));
        setContentView(root);
        updateCameraChoice();
    }
    private void updateCameraChoice() {
        if (rearButton == null) return;
        rearButton.setText(useFrontCamera ? "📷  REAR CAMERA" : "✓  REAR CAMERA");
        frontButton.setText(useFrontCamera ? "✓  FRONT CAMERA" : "🤳  FRONT CAMERA");
        rearButton.setBackground(shape(useFrontCamera ? 0xCC172640 : GOLD, GOLD, 16));
        frontButton.setBackground(shape(useFrontCamera ? GOLD : 0xCC172640, GOLD, 16));
        rearButton.setTextColor(useFrontCamera ? Color.WHITE : NAVY);
        frontButton.setTextColor(useFrontCamera ? NAVY : Color.WHITE);
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
        status.setText(String.format(Locale.US, "● GPS READY  •  %.6f, %.6f%s",
            location.getLatitude(), location.getLongitude(),
            accuracy >= 0 ? String.format(Locale.US, "  •  ±%.0fm", accuracy) : ""));
        captureButton.setEnabled(imageCapture != null);
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
        bindSelectedCamera();
    }
    private void syncFlashControl() {
        boolean available = activeCamera != null && activeCamera.getCameraInfo().hasFlashUnit() && !useFrontCamera;
        flashButton.setEnabled(available);
        flashButton.setAlpha(available ? 1f : 0.45f);
        flashButton.setText(available ? (flashOn ? "⚡  ON" : "⚡  OFF") : "⚡  N/A");
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
