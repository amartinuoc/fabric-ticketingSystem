package uoc.tfm.app.model.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum TicketType {

    TEST("TYPE-001", "Testing-related tickets"),
    DEVELOPMENT("TYPE-002", "Development-related tickets"),
    UNKNOWN("TYPE-000", "Unknown-related for tickets");

    private final String code; // Ticket type code
    private final String description; // Ticket type description

}
