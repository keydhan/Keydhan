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
        getWindow().setNavigationBarColor(Color.BLACK);
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
    private Button button(String value) {
        Button b = new Button(this); b.setText(value); b.setTextColor(Color.WHITE);
        b.setAllCaps(false);
        b.setBackgroundTintList(android.content.res.ColorStateList.valueOf(GOLD));
        return b;
    }
    private void buildCameraUi() {
        FrameLayout root = new FrameLayout(this); root.setBackgroundColor(Color.BLACK);
        previewView = new PreviewView(this); previewView.setScaleType(PreviewView.ScaleType.FILL_CENTER);
        root.addView(previewView, new FrameLayout.LayoutParams(-1, -1));

        LinearLayout header = new LinearLayout(this);
        header.setGravity(Gravity.CENTER_VERTICAL); header.setPadding(10, 8, 10, 8);
        header.setBackgroundColor(0xE6071228);
        Button exit = button("✕  Exit"); exit.setTextSize(13);
        exit.setOnClickListener(v -> finish());
        header.addView(exit, new LinearLayout.LayoutParams(-2, -2));
        TextView title = text("KEYDHAN™ GPS CAMERA", 14, Color.WHITE, true);
        title.setGravity(Gravity.CENTER);
        header.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        flashButton = button("⚡ Flash Off"); flashButton.setTextSize(12);
        flashButton.setOnClickListener(v -> toggleFlash());
        header.addView(flashButton, new LinearLayout.LayoutParams(-2, -2));
        root.addView(header, new FrameLayout.LayoutParams(-1, -2, Gravity.TOP));

        LinearLayout bottom = new LinearLayout(this);
        bottom.setOrientation(LinearLayout.VERTICAL); bottom.setPadding(14, 12, 14, 16);
        bottom.setBackgroundColor(0xE6071228);
        status = text("◉  Getting GPS location…", 13, Color.WHITE, true);
        bottom.addView(status);
        LinearLayout cameraChoices = new LinearLayout(this);
        cameraChoices.setGravity(Gravity.CENTER); cameraChoices.setPadding(0, 8, 0, 4);
        rearButton = button("📷  Rear Camera"); frontButton = button("🤳  Front Camera");
        rearButton.setTextSize(13); frontButton.setTextSize(13);
        rearButton.setOnClickListener(v -> selectCamera(false));
        frontButton.setOnClickListener(v -> selectCamera(true));
        cameraChoices.addView(rearButton, new LinearLayout.LayoutParams(0, -2, 1));
        cameraChoices.addView(frontButton, new LinearLayout.LayoutParams(0, -2, 1));
        bottom.addView(cameraChoices);
        captureButton = button("●   CAPTURE GPS PHOTO");
        captureButton.setTextSize(16);
        LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(-1, -2);
        cp.topMargin = 5; bottom.addView(captureButton, cp);
        captureButton.setOnClickListener(v -> capturePhoto());
        root.addView(bottom, new FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM));
        setContentView(root);
        captureButton.setEnabled(false);
        updateCameraChoice();
    }

    private void updateCameraChoice() {
        if (rearButton == null) return;
        rearButton.setAlpha(useFrontCamera ? 0.58f : 1f);
        frontButton.setAlpha(useFrontCamera ? 1f : 0.58f);
        rearButton.setText(useFrontCamera ? "📷  Rear Camera" : "✓  Rear Camera");
        frontButton.setText(useFrontCamera ? "✓  Front Camera" : "🤳  Front Camera");
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
            if (flashOn && activeCamera.getCameraInfo().hasFlashUnit()) activeCamera.getCameraControl().enableTorch(true);
            updateCameraChoice();
        } catch (Exception e) { Toast.makeText(this, "Camera switch failed: " + e.getMessage(), Toast.LENGTH_LONG).show(); }
    }
    private void selectCamera(boolean front) {
        if (useFrontCamera == front) return;
        useFrontCamera = front; flashOn = false;
        flashButton.setText("⚡ Flash Off");
        bindSelectedCamera();
    }
    private void toggleFlash() {
        if (activeCamera == null || !activeCamera.getCameraInfo().hasFlashUnit()) {
            Toast.makeText(this, "Flash is not available on this camera.", Toast.LENGTH_SHORT).show(); return;
        }
        flashOn = !flashOn;
        activeCamera.getCameraControl().enableTorch(flashOn);
        flashButton.setText(flashOn ? "⚡ Flash On" : "⚡ Flash Off");
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
        Bitmap marked = original.copy(Bitmap.Config.ARGB_8888, true);
        original.recycle();
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
        TextView heading = text("✓  PHOTO PREVIEW",16,GOLD,true); panel.addView(heading);
        TextView sub = text("Check your GPS watermark before saving.",12,Color.WHITE,false);
        panel.addView(sub);
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
            lastSavedUri=uri; pendingPhoto.delete(); pendingPhoto=null;
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

echo "GPS Camera native files configured."
