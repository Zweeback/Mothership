import de.bentropie.gladosvoice.RobotFx;
import de.bentropie.gladosvoice.TextChunks;
import java.util.List;
import java.util.Random;
public final class LocalTests {
    private static void check(boolean c,String m){if(!c)throw new AssertionError(m);}
    public static void main(String[]args){
        check(TextChunks.split("",1800).isEmpty(),"empty");
        check(TextChunks.split("Hallo Welt",1800).equals(List.of("Hallo Welt")),"simple");
        String s="Eine ziemlich lange Zeile. ".repeat(1000);
        List<String> chunks=TextChunks.split(s,1800);
        check(chunks.size()>5,"multiple");
        for(String c:chunks)check(!c.isEmpty()&&c.length()<=1800,"length");
        check(String.join(" ",chunks).replaceAll("\\s+"," ").equals(s.trim().replaceAll("\\s+"," ")),"full content");
        byte[] pcm=new byte[44100*2]; new Random(42).nextBytes(pcm);
        check(java.util.Arrays.equals(RobotFx.apply(pcm,44100,1,0),pcm),"effect off");
        byte[] wet=RobotFx.apply(pcm,44100,1,.7f);
        check(wet.length==pcm.length&&!java.util.Arrays.equals(wet,pcm),"effect on");
        System.out.println("PASS: chunking, long text, PCM bypass / effect");
    }
}
