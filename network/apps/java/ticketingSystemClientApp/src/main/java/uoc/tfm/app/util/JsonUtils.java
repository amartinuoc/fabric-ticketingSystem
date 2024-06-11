package uoc.tfm.app.util;

import java.nio.charset.StandardCharsets;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;

public class JsonUtils {

    public static String prettyJson(final byte[] json) {
        return prettyJson(new String(json, StandardCharsets.UTF_8));
    }

    public static String prettyJson(final String json) {
        try {
            ObjectMapper objectMapper = new ObjectMapper();
            objectMapper.enable(SerializationFeature.INDENT_OUTPUT);
            JsonNode parsedJson = objectMapper.readTree(json);
            return objectMapper.writeValueAsString(parsedJson);
        } catch (Exception e) {
            e.printStackTrace();
            return "";
        }
    }

}
