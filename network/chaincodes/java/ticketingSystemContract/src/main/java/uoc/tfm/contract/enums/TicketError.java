package uoc.tfm.contract.enums;

import lombok.AllArgsConstructor;

@AllArgsConstructor
public enum TicketError {

    // Error code when a ticket is not found
    TICKET_NOT_FOUND("ERR-001", "Ticket not found"),

    // Error code when a ticket already exists
    TICKET_ALREADY_EXISTS("ERR-002", "Ticket already exists"),

    // Error code for JSON processing errors related to tickets
    TICKET_JSON_PROCESSING_ERROR("ERR-003", "Error processing JSON for ticket"),

    // Error code when a ticket has invalid status
    TICKET_INVALID_STATUS("ERR-004", "Ticket invalid status"),

    // Error code for an empty comment when adding to a ticket
    TICKET_COMMENT_EMPTY("ERR-005", "Comment cannot be empty when adding to a ticket"),

    // Error code for an empty assigned user parameter
    TICKET_ASSIGNED_EMPTY("ERR-006", "Assigned user parameter cannot be empty"),

    // Error code while retrieving history for ticket
    TICKET_HISTORY_RETRIEVAL_ERROR("ERR-007", "Error retrieving history for ticket");

    private final String code; // Ticket Error code
    private final String description; // Ticket Description of the error

    // Method to get all values of the enum
    public static TicketError[] getAllTicketErrors() {
        return TicketError.values();
    }

    // Getter for ticket error code
    public String getCode() {
        return code;
    }

    // Getter for ticket error description
    public String getDescription() {
        return description;
    }

    public String getCodeAndName() {
        return code + ":" + this.name();
    }

}
