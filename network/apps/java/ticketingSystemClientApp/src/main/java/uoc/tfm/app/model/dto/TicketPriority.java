package uoc.tfm.app.model.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum TicketPriority {

    LOW("PR-001", "Low priority"),
    MEDIUM("PR-002", "Medium priority"),
    HIGH("PR-003", "High priority"),
    UNKNOWN("PR-000", "Unknown priority");

    private final String code; // Ticket priority code
    private final String description; // Ticket priority description

}
