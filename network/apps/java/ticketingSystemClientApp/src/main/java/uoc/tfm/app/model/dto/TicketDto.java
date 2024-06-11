
package uoc.tfm.app.model.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import uoc.tfm.app.config.JacksonConfig;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TicketDto {

    private String ticketId;

    private String title;

    private String description;

    private int projectIdNum;

    private String creator;

    private TicketPriority ticketPriority;

    private TicketType ticketType;

    private LocalDateTime creationDate;

    private LocalDateTime lastModifiedDate;

    private String assigned;

    private String relatedProductVersion;

    private List<String> comments;

    private int storyPoints;

    private TicketStatus ticketStatus;

    // Method to convert JSON to a list of TicketDto objects
    public static List<TicketDto> fromJsonList(String json) throws Exception {
        // Using the ObjectMapper bean from JacksonConfig class
        ObjectMapper objectMapper = new JacksonConfig().objectMapper();
        // Using Jackson ObjectMapper to deserialize JSON to a list of TicketDto objects
        return objectMapper.readValue(json, new TypeReference<List<TicketDto>>() {
        });
    }

    // Method to convert JSON to a TicketDto object
    public static TicketDto fromJson(String json) throws Exception {
        // Using the ObjectMapper bean from JacksonConfig class
        ObjectMapper objectMapper = new JacksonConfig().objectMapper();
        // Using Jackson ObjectMapper to deserialize JSON to a TicketDto object
        return objectMapper.readValue(json, new TypeReference<TicketDto>() {
        });
    }

}
