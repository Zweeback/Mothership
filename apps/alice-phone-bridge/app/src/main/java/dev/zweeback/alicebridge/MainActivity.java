package dev.zweeback.alicebridge;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.StatFs;
import android.provider.MediaStore;
import android.provider.Settings;
import android.net.Uri;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.util.Locale;

public final class MainActivity extends Activity {
    private static final int MEDIA_REQUEST = 71;
    private TextView header, reportView;
    private String report = "";
    private boolean mediaRequested = false;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        ScrollView scroller = new ScrollView(this);
        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(28, 30, 28, 36);
        scroller.addView(panel);
        setContentView(scroller);

        TextView title = label(panel, "ALICE · Speicherblick", 25);
        title.setTypeface(null, Typeface.BOLD);
        label(panel, "Lokal. Lesend. Kein automatisches Löschen. Kein Internetzugriff.", 14);
        header = label(panel, "", 20);
        button(panel, "Speicher neu messen", v -> refresh(false));
        button(panel, "Größte Fotos und Videos untersuchen", v -> scanMedia());
        button(panel, "Android-Speicherverwaltung", v -> openSettings(Settings.ACTION_INTERNAL_STORAGE_SETTINGS));
        button(panel, "Installierte Apps verwalten", v -> openSettings(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS));
        button(panel, "Bericht selbst teilen", v -> shareReport());
        reportView = label(panel, "", 14);
        refresh(false);
    }

    private TextView label(LinearLayout panel, String s, int size) {
        TextView out = new TextView(this);
        out.setText(s);
        out.setTextSize(size);
        out.setTextColor(Color.rgb(27, 38, 56));
        out.setPadding(0, 12, 0, 14);
        out.setTextIsSelectable(true);
        panel.addView(out);
        return out;
    }
    private void button(LinearLayout panel, String text, View.OnClickListener cb) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        b.setOnClickListener(cb);
        panel.addView(b);
    }
    private static String gb(long bytes) {
        return String.format(Locale.GERMANY, "%.2f GiB", bytes / 1073741824.0);
    }
    private void refresh(boolean includeMedia) {
        try {
            StatFs stats = new StatFs(Environment.getDataDirectory().getPath());
            long total = stats.getTotalBytes();
            long free = stats.getAvailableBytes();
            long used = Math.max(0, total - free);
            double pct = total == 0 ? 0 : used * 100.0 / total;
            header.setText("Belegt " + String.format(Locale.GERMANY, "%.1f", pct) + "% · Frei " + gb(free));
            StringBuilder sb = new StringBuilder();
            sb.append("ALICE Speicherblick v0.1\n");
            sb.append("Android: ").append(Build.VERSION.RELEASE).append("\n");
            sb.append("Gemessenes /data-Dateisystem (nicht die Android-Kategorieansicht):\n");
            sb.append("Gesamt: ").append(gb(total)).append("\n");
            sb.append("Belegt (geschätzt): ").append(gb(used)).append("\n");
            sb.append("Für Apps verfügbar: ").append(gb(free)).append("\n");
            sb.append("Messung lokal, ohne Übertragung oder Löschung.\n");
            if (includeMedia) {
                sb.append("\nNur zugelassene/ausgewählte Medien:\n");
                appendTopMedia(sb, MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "Videos");
                appendTopMedia(sb, MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "Bilder");
            } else {
                sb.append("\nFür größte Medien bitte ausdrücklich die Sichtung starten.\n");
            }
            report = sb.toString();
            reportView.setText(report);
        } catch (Exception e) {
            report = "Speichermessung nicht möglich: " + e.getClass().getSimpleName();
            header.setText("Messung fehlgeschlagen");
            reportView.setText(report);
        }
    }
    private void appendTopMedia(StringBuilder sb, Uri uri, String name) {
        sb.append(name).append(":\n");
        String[] columns = { MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.SIZE, MediaStore.MediaColumns.RELATIVE_PATH };
        try (Cursor cursor = getContentResolver().query(uri, columns, null, null, MediaStore.MediaColumns.SIZE + " DESC")) {
            if (cursor == null) { sb.append("  Keine Lesedaten.\n"); return; }
            int n=0;
            int cName=cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME);
            int cSize=cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE);
            int cPath=cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH);
            while (cursor.moveToNext() && n<12) {
                long size = cursor.isNull(cSize) ? 0 : cursor.getLong(cSize);
                String path = cursor.getString(cPath);
                String file = cursor.getString(cName);
                sb.append("  ").append(gb(size)).append(" · ").append(path==null?"":path)
                  .append(file==null?"(ohne Name)":file).append("\n");
                n++;
            }
            if(n==0)sb.append("  Keine sichtbaren Medien.\n");
        } catch (SecurityException ex) {
            sb.append("  Nicht freigegeben.\n");
        } catch (Exception ex) {
            sb.append("  Abfrage nicht unterstützt: ").append(ex.getClass().getSimpleName()).append("\n");
        }
    }
    private void scanMedia() {
        if (Build.VERSION.SDK_INT >= 34) {
            if (checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED ||
                checkSelfPermission(Manifest.permission.READ_MEDIA_VIDEO) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{
                    Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VIDEO,
                    Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED
                }, MEDIA_REQUEST);
                return;
            }
        } else if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission(Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED ||
                checkSelfPermission(Manifest.permission.READ_MEDIA_VIDEO) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[]{ Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VIDEO }, MEDIA_REQUEST);
                return;
            }
        } else if (checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.READ_EXTERNAL_STORAGE}, MEDIA_REQUEST);
            return;
        }
        mediaRequested=true;
        refresh(true);
    }
    @Override public void onRequestPermissionsResult(int req, String[] permissions, int[] grants) {
        super.onRequestPermissionsResult(req, permissions, grants);
        if(req==MEDIA_REQUEST) {
            mediaRequested=true;
            refresh(true);
        }
    }
    @Override protected void onResume() {
        super.onResume();
        if (header != null && reportView != null) refresh(mediaRequested);
    }
    private void openSettings(String action) {
        try { startActivity(new Intent(action)); }
        catch (Exception ignored) { startActivity(new Intent(Settings.ACTION_SETTINGS)); }
    }
    private void shareReport() {
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType("text/plain");
        send.putExtra(Intent.EXTRA_SUBJECT, "ALICE Speicherbericht");
        send.putExtra(Intent.EXTRA_TEXT, report);
        startActivity(Intent.createChooser(send, "Bericht nur bei Bedarf teilen"));
    }
}
