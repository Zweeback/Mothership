package de.bentropie.gladosvoice;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioTrack;
import android.media.MediaPlayer;
import android.os.Bundle;
import android.os.SystemClock;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.speech.tts.Voice;
import android.view.Gravity;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;
import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {
    private static final int BG=Color.rgb(12,19,23), PANEL=Color.rgb(25,37,43);
    private static final int ORANGE=Color.rgb(255,160,59), MUTED=Color.rgb(155,178,188);
    private TextToSpeech tts;
    private EditText editor;
    private TextView status;
    private Spinner chooser;
    private Button go;
    private SeekBar speed, pitch, effect;
    private final ArrayList<Voice> german = new ArrayList<>();
    private final ArrayList<String> chunks = new ArrayList<>();
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private final Object playbackLock = new Object();
    private volatile AudioTrack track;
    private volatile MediaPlayer media;
    private int generation=0, part=0;
    private boolean ready=false;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        makeUi();
        incoming(getIntent());
        tts=new TextToSpeech(this, result -> runOnUiThread(() -> {
            if(result!=TextToSpeech.SUCCESS || tts==null) {
                setStatus("Keine Android-TTS-Engine verfügbar");
                return;
            }
            int code=tts.setLanguage(Locale.GERMANY);
            if(code==TextToSpeech.LANG_MISSING_DATA || code==TextToSpeech.LANG_NOT_SUPPORTED) {
                setStatus("Deutsche Sprachdaten in den Android-Einstellungen installieren");
                return;
            }
            tts.setOnUtteranceProgressListener(progress);
            ready=true; go.setEnabled(true);
            fillVoices();
            setStatus("Bereit · Deutsche Sprachengine aktiv");
        }));
    }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent); setIntent(intent); incoming(intent);
    }
    private void incoming(Intent intent) {
        if(intent==null||editor==null)return;
        CharSequence s=null;
        if(Intent.ACTION_SEND.equals(intent.getAction()) && "text/plain".equals(intent.getType()))
            s=intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
        if(Intent.ACTION_PROCESS_TEXT.equals(intent.getAction()))
            s=intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT);
        if(s!=null && s.length()>0) editor.setText(s.toString());
    }

    private void makeUi() {
        ScrollView sc=new ScrollView(this);
        sc.setFillViewport(true);sc.setBackgroundColor(BG);
        LinearLayout root=new LinearLayout(this); root.setOrientation(1);
        root.setPadding(dp(20),dp(20),dp(20),dp(32));sc.addView(root);
        setContentView(sc);
        TextView eye=txt("◎",100,ORANGE,true);
        eye.setGravity(Gravity.CENTER);root.addView(eye,new LinearLayout.LayoutParams(-1,dp(132)));
        TextView title=txt("APERTURE // ROBOT VOICE",23,Color.WHITE,true);
        title.setGravity(Gravity.CENTER);root.addView(title);
        TextView subtitle=txt("GLaDOS-inspirierter deutscher Vorleser",13,MUTED,false);
        subtitle.setGravity(Gravity.CENTER);root.addView(subtitle);space(root,24);
        root.addView(txt("DEIN TEXT",12,ORANGE,true));space(root,7);
        editor=new EditText(this);
        editor.setTextColor(Color.WHITE);editor.setHintTextColor(MUTED);
        editor.setTextSize(16);editor.setGravity(Gravity.TOP);
        editor.setPadding(dp(15),dp(13),dp(15),dp(13));
        editor.setInputType(android.text.InputType.TYPE_CLASS_TEXT |
            android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        editor.setMinLines(6);editor.setMaxLines(14);
        editor.setBackground(bg(PANEL));
        editor.setHint("Beliebigen Text eingeben …");
        editor.setText("Guten Abend. Das Testlabor ist jetzt betriebsbereit. Bitte bleiben Sie ruhig. Dies ist lediglich ein harmloser Sprachtest.");
        root.addView(editor,new LinearLayout.LayoutParams(-1,-2));space(root,10);
        Button paste=btn("AUS ZWISCHENABLAGE EINFÜGEN",PANEL,Color.WHITE);
        root.addView(paste,new LinearLayout.LayoutParams(-1,dp(46)));
        paste.setOnClickListener(v->paste());space(root,18);
        root.addView(txt("DEUTSCHE STIMME",12,ORANGE,true));space(root,8);
        chooser=new Spinner(this);
        chooser.setBackground(bg(PANEL));root.addView(chooser,new LinearLayout.LayoutParams(-1,dp(48)));
        space(root,16);
        speed=slider(root,"TEMPO",82);
        pitch=slider(root,"TONHÖHE",83);
        effect=slider(root,"METALLISCHER EFFEKT",70);
        space(root,8);
        LinearLayout actions=new LinearLayout(this);actions.setOrientation(0);
        go=btn("▶  VORLESEN",ORANGE,BG);go.setEnabled(false);
        actions.addView(go,new LinearLayout.LayoutParams(0,dp(56),2));
        Button stop=btn("■  STOPP",PANEL,Color.WHITE);
        LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(0,dp(56),1);p.leftMargin=dp(9);
        actions.addView(stop,p);root.addView(actions);
        go.setOnClickListener(v->startReading());
        stop.setOnClickListener(v->{stopReading();setStatus("Gestoppt");});
        space(root,14);
        status=txt("Sprachengine wird initialisiert …",13,MUTED,false);
        status.setGravity(Gravity.CENTER);root.addView(status);
        space(root,19);
        root.addView(txt("Keine Werbung · Keine Telemetrie · Keine App-Server",11,MUTED,false));
        root.addView(txt("Kein offizielles Portal-Produkt / keine Originalstimme",11,MUTED,false));
    }

    private void fillVoices() {
        german.clear();
        if(tts.getVoices()!=null) for(Voice v:tts.getVoices())
            if("de".equals(v.getLocale().getLanguage())) german.add(v);
        german.sort(Comparator.comparing(Voice::isNetworkConnectionRequired).thenComparing(Voice::getName));
        ArrayList<String> labels=new ArrayList<>();
        labels.add("Deutsch · Systemstimme");
        for(Voice v:german) labels.add(v.getLocale().toLanguageTag()+" · "+v.getName()+
            (v.isNetworkConnectionRequired()?" · Online":" · Lokal"));
        ArrayAdapter<String> adapter=new ArrayAdapter<>(this,android.R.layout.simple_spinner_dropdown_item,labels);
        chooser.setAdapter(adapter);
        for(int i=0;i<german.size();i++) if(!german.get(i).isNetworkConnectionRequired()) {
            chooser.setSelection(i+1);break;
        }
    }

    private void startReading() {
        if(!ready){setStatus("TTS noch nicht bereit");return;}
        String s=editor.getText().toString();
        if(s.trim().isEmpty()){setStatus("Bitte Text eingeben");return;}
        stopReading();
        chunks.addAll(TextChunks.split(s,Math.min(1800,TextToSpeech.getMaxSpeechInputLength()-8)));
        if(chunks.isEmpty())return;
        tts.setSpeechRate(.55f+speed.getProgress()*.0055f);
        tts.setPitch(.55f+pitch.getProgress()*.0055f);
        int selected=chooser.getSelectedItemPosition()-1;
        if(selected>=0&&selected<german.size()){
            if(tts.setVoice(german.get(selected))!=TextToSpeech.SUCCESS)
                tts.setLanguage(Locale.GERMANY);
        }else tts.setLanguage(Locale.GERMANY);
        part=0; renderPart(generation);
    }
    private void renderPart(int g) {
        if(g!=generation)return;
        if(part>=chunks.size()){setStatus("Fertig · "+chunks.size()+" Abschnitte");return;}
        File file=temp(g,part);if(file.exists())file.delete();
        setStatus("Synthese "+(part+1)+"/"+chunks.size());
        int r=tts.synthesizeToFile(chunks.get(part),new Bundle(),file,"robot-"+g+"-"+part);
        if(r==TextToSpeech.ERROR) plain(g);
    }
    private void plain(int g) {
        if(g!=generation || part>=chunks.size())return;
        setStatus("Standard-TTS · Roboterfilter nicht verfügbar");
        int r=tts.speak(chunks.get(part),TextToSpeech.QUEUE_FLUSH,new Bundle(),"plain-"+g+"-"+part);
        if(r==TextToSpeech.ERROR)setStatus("TTS konnte den Text nicht lesen");
    }

    private final UtteranceProgressListener progress=new UtteranceProgressListener(){
        @Override public void onStart(String id){}
        @Override public void onDone(String id){
            String[] p=id.split("-");if(p.length!=3)return;
            int g,i;try{g=Integer.parseInt(p[1]);i=Integer.parseInt(p[2]);}
            catch(NumberFormatException e){return;}
            runOnUiThread(()->{
                if(g!=generation||i!=part)return;
                if(id.startsWith("plain-"))next(g);
                else{File f=temp(g,i); worker.execute(()->playWav(g,f));}
            });
        }
        @Override public void onError(String id){runOnUiThread(()->handleError(id));}
        @Override public void onError(String id,int code){runOnUiThread(()->handleError(id));}
    };
    private void handleError(String id){
        String[] p=id.split("-");if(p.length!=3)return;
        try {
            int g=Integer.parseInt(p[1]),i=Integer.parseInt(p[2]);
            if(g==generation&&i==part){
                if(id.startsWith("robot-"))plain(g);
                else setStatus("Sprachengine konnte den Text nicht erzeugen");
            }
        }catch(NumberFormatException ignored){}
    }

    private void playWav(int g,File f) {
        if(g!=generation){f.delete();return;}
        boolean played=false;
        try {
            Wave wave=Wave.read(f);
            if(wave!=null){
                byte[] bytes=RobotFx.apply(wave.data,wave.rate,wave.channels,effect.getProgress()/100f);
                int cfg=wave.channels==1?AudioFormat.CHANNEL_OUT_MONO:AudioFormat.CHANNEL_OUT_STEREO;
                int min=AudioTrack.getMinBufferSize(wave.rate,cfg,AudioFormat.ENCODING_PCM_16BIT);
                if(min>0){
                    AudioTrack a=new AudioTrack.Builder().setAudioAttributes(new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                        .setAudioFormat(new AudioFormat.Builder().setSampleRate(wave.rate)
                            .setChannelMask(cfg).setEncoding(AudioFormat.ENCODING_PCM_16BIT).build())
                        .setTransferMode(AudioTrack.MODE_STREAM).setBufferSizeInBytes(Math.max(8192,min*2)).build();
                    synchronized(playbackLock){if(g==generation)track=a;}
                    if(g==generation){
                        a.play();int n=0;
                        while(n<bytes.length&&g==generation) {
                            int written=a.write(bytes,n,Math.min(4096,bytes.length-n),AudioTrack.WRITE_BLOCKING);
                            if(written<=0)break;n+=written;
                        }
                        if(n==bytes.length&&g==generation){
                            int frames=bytes.length/(2*wave.channels);
                            long deadline=SystemClock.elapsedRealtime()+3000+frames*1000L/wave.rate;
                            while(g==generation && a.getPlaybackHeadPosition()<frames &&
                                    SystemClock.elapsedRealtime()<deadline)SystemClock.sleep(35);
                            played=true;
                        }
                    }
                    synchronized(playbackLock){if(track==a)track=null;}
                    try{a.stop();}catch(Exception ignored){}
                    a.release();
                }
            }
        }catch(Exception ignored){}
        if(!played&&g==generation)played=playFallback(g,f);
        f.delete();
        final boolean success=played;
        if(g==generation)runOnUiThread(()->{
            if(g==generation){if(success)next(g);else plain(g);}
        });
    }
    private boolean playFallback(int g,File f){
        MediaPlayer m=new MediaPlayer();
        synchronized(playbackLock){if(g==generation)media=m;}
        try {
            m.setDataSource(f.getAbsolutePath());m.prepare();
            if(g!=generation)return false;
            m.start();
            long deadline=SystemClock.elapsedRealtime()+120000;
            while(g==generation&&m.isPlaying()&&SystemClock.elapsedRealtime()<deadline)SystemClock.sleep(40);
            return g==generation&&!m.isPlaying();
        }catch(Exception e){return false;}
        finally{
            synchronized(playbackLock){if(media==m)media=null;}
            try{m.release();}catch(Exception ignored){}
        }
    }
    private void next(int g){if(g==generation){part++;renderPart(g);}}
    private void stopReading(){
        generation++;part=0;chunks.clear();
        if(tts!=null)tts.stop();
        synchronized(playbackLock){
            try{if(track!=null){track.pause();track.flush();}}catch(Exception ignored){}
            try{if(media!=null)media.pause();}catch(Exception ignored){}
        }
    }
    private File temp(int g,int i){return new File(getCacheDir(),"robot-"+g+"-"+i+".wav");}

    private static final class Wave {
        final int rate,channels;final byte[] data;
        Wave(int rate,int channels,byte[] data){this.rate=rate;this.channels=channels;this.data=data;}
        static int u16(RandomAccessFile f)throws IOException{
            return f.readUnsignedByte() | f.readUnsignedByte()<<8;
        }
        static long u32(RandomAccessFile f)throws IOException{
            return u16(f)|((long)u16(f)<<16);
        }
        static Wave read(File file)throws IOException{
            try(RandomAccessFile f=new RandomAccessFile(file,"r")){
                if(f.length()<44||f.length()>30_000_000)return null;
                byte[] h=new byte[4];f.readFully(h);
                if(!"RIFF".equals(new String(h,StandardCharsets.US_ASCII)))return null;
                u32(f);f.readFully(h);
                if(!"WAVE".equals(new String(h,StandardCharsets.US_ASCII)))return null;
                int fmt=-1,ch=-1,rate=-1,bits=-1;byte[] data=null;
                while(f.getFilePointer()+8<=f.length()){
                    f.readFully(h);String type=new String(h,StandardCharsets.US_ASCII);
                    long len=u32(f),pos=f.getFilePointer();
                    if(len>f.length()-pos)return null;
                    if("fmt ".equals(type)&&len>=16){
                        fmt=u16(f);ch=u16(f);rate=(int)u32(f);
                        u32(f);u16(f);bits=u16(f);
                    }else if("data".equals(type)&&len<=25_000_000){
                        data=new byte[(int)len];f.readFully(data);
                    }
                    f.seek(pos+len+len%2);
                    if(fmt!=-1&&data!=null)break;
                }
                if(fmt!=1||bits!=16||(ch!=1&&ch!=2)||rate<8000||rate>96000||data==null)return null;
                return new Wave(rate,ch,data);
            }
        }
    }
    private void paste(){
        ClipboardManager c=(ClipboardManager)getSystemService(Context.CLIPBOARD_SERVICE);
        ClipData clip=c==null?null:c.getPrimaryClip();
        if(clip==null||clip.getItemCount()==0){
            Toast.makeText(this,"Zwischenablage leer",Toast.LENGTH_SHORT).show();return;
        }
        CharSequence value=clip.getItemAt(0).coerceToText(this);
        if(value!=null)editor.setText(value.toString());
    }
    private void setStatus(String s){if(status!=null)status.setText(s);}
    private SeekBar slider(LinearLayout root,String name,int v){
        root.addView(txt(name,12,ORANGE,true));
        SeekBar b=new SeekBar(this);b.setMax(100);b.setProgress(v);
        b.setProgressTintList(ColorStateList.valueOf(ORANGE));
        b.setThumbTintList(ColorStateList.valueOf(ORANGE));
        root.addView(b,new LinearLayout.LayoutParams(-1,dp(42)));
        space(root,11);return b;
    }
    private TextView txt(String s,int size,int color,boolean bold){
        TextView t=new TextView(this);t.setText(s);t.setTextSize(size);t.setTextColor(color);
        if(bold)t.setTypeface(Typeface.DEFAULT,Typeface.BOLD);return t;
    }
    private Button btn(String s,int color,int ink){
        Button b=new Button(this);b.setAllCaps(false);b.setText(s);b.setTextSize(13);
        b.setTextColor(ink);b.setBackground(bg(color));return b;
    }
    private GradientDrawable bg(int color){
        GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(10));return d;
    }
    private void space(LinearLayout r,int amount){r.addView(new View(this),new LinearLayout.LayoutParams(1,dp(amount)));}
    private int dp(int value){return Math.round(value*getResources().getDisplayMetrics().density);}
    @Override protected void onDestroy(){
        stopReading();if(tts!=null)tts.shutdown();
        worker.shutdownNow();super.onDestroy();
    }
}
