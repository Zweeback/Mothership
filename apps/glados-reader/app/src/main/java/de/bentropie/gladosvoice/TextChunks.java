package de.bentropie.gladosvoice;
import java.util.ArrayList;
import java.util.List;
/** Split arbitrary-length text into TTS-friendly fragments without losing content. */
public final class TextChunks {
    private TextChunks() {}
    public static List<String> split(String raw, int limit) {
        if (limit < 16) throw new IllegalArgumentException("limit must be >= 16");
        List<String> out = new ArrayList<>();
        if (raw == null || raw.trim().isEmpty()) return out;
        String remaining = raw.trim();
        while (!remaining.isEmpty()) {
            if (remaining.length() <= limit) { out.add(remaining); break; }
            int end = limit, best = -1;
            for (int i = end - 1; i >= Math.max(0, end - 240); i--) {
                char c = remaining.charAt(i);
                if (c == '.' || c == '!' || c == '?' || c == '\n' || c == ';') { best = i + 1; break; }
                if (Character.isWhitespace(c) && best < 0) best = i;
            }
            if (best > 0) end = best;
            String chunk = remaining.substring(0, end).trim();
            if (!chunk.isEmpty()) out.add(chunk);
            remaining = remaining.substring(end).trim();
        }
        return out;
    }
}
