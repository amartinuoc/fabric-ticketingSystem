package uoc.tfm.contract.enums;

import lombok.AllArgsConstructor;

@AllArgsConstructor
public enum TicketStatus {

    // Represents tickets that are open and pending
    OPEN("ST-001", "Tickets that are open and pending"),

    // Represents tickets that are in progress
    IN_PROGRESS("ST-002", "Tickets that are in progress"),

    // Represents tickets that have been resolved
    RESOLVED("ST-003", "Tickets that have been resolved"),

    // Represents tickets that are closed
    CLOSED("ST-004", "Tickets that are closed"),

    // Represents unknown tickets status
    UNKNOWN("ST-000", "Tickets with status unknown");

    private final String code; // Ticket status code
    private final String description; // Ticket status description

    // Method to get all values of the enum
    public static TicketStatus[] getAllTicketStatus() {
        return TicketStatus.values();
    }

    /**
     * Returns the enum constant of the specified enum type with the specified name,
     * ignoring case considerations.
     * 
     * @param status the name of the enum constant to be returned.
     * @return the enum constant with the specified name.
     */
    public static TicketStatus fromString(String status) {
        if (status != null) {
            for (TicketStatus ts : TicketStatus.values()) {
                if (status.equalsIgnoreCase(ts.name())) {
                    return ts;
                }
            }
        }
        return UNKNOWN;
    }

    // Getter for ticket status code
    public String getCode() {
        return code;
    }

    // Getter for ticket status description
    public String getDescription() {
        return description;
    }
}