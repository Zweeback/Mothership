package de.bentropie.gladosvoice;
/** Zero-dependency metallic/chorus DSP for little-endian PCM16. */
public final class RobotFx {
    private RobotFx() {}
    public static byte[] apply(byte[] pcm, int rate, int channels, float amount) {
        if (pcm == null) return new byte[0];
        if (amount <= 0.001f || rate < 8000 || channels < 1 || channels > 2) return pcm.clone();
        amount = Math.max(0f, Math.min(1f, amount));
        byte[] out = pcm.clone();
        int frameSize = channels*2;
        int frames = pcm.length/frameSize;
        int size = Math.max(512,(int)(rate*.045f));
        float[][] buffer = new float[channels][size];
        for (int n=0;n<frames;n++) {
            double phase = 2*Math.PI*.72*n/rate;
            int delay = (int)(rate*(.008+.004*Math.sin(phase)));
            delay = Math.max(1,Math.min(size-1,delay));
            float metallic = (float)Math.sin(2*Math.PI*27.5*n/rate);
            for (int channel=0;channel<channels;channel++) {
                int at=n*frameSize+channel*2;
                float dry=(short)((pcm[at]&255)|(pcm[at+1]<<8))/32768f;
                float echo=buffer[channel][(n-delay+size)%size];
                buffer[channel][n%size]=dry;
                float effect=(.73f*dry+.27f*echo)*(.91f+.09f*metallic);
                float mixed=dry*(1-amount)+effect*amount;
                int value=Math.round(Math.max(-1f,Math.min(.99997f,mixed))*32767);
                out[at]=(byte)value; out[at+1]=(byte)(value>>>8);
            }
        }
        return out;
    }
}
