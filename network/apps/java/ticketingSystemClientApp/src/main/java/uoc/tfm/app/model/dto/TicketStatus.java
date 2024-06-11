package uoc.tfm.app.model.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum TicketStatus {

    OPEN("ST-001", "Tickets that are open and pending"),
    IN_PROGRESS("ST-002", "Tickets that are in progress"),
    RESOLVED("ST-003", "Tickets that have been resolved"),
    CLOSED("ST-004", "Tickets that are closed"),
    UNKNOWN("ST-000", "Tickets with status unknown");

    private final String code; // Ticket status code
    private final String description; // Ticket status description

}

