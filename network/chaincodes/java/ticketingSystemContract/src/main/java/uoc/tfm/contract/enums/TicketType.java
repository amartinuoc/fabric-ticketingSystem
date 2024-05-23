package uoc.tfm.contract.enums;

import lombok.AllArgsConstructor;

@AllArgsConstructor
public enum TicketType {

    // Represents tickets related to testing
    TEST("TYPE-001", "Testing-related tickets"),

    // Represents tickets related to development
    DEVELOPMENT("TYPE-002", "Development-related tickets"),

    // Represents tickets related to Unknown type
    UNKNOWN("TYPE-000", "Unknown-related for tickets");

    private final String code; // Ticket type code
    private final String description; // Ticket type description

    // Method to get all values of the enum
    public static TicketType[] getAllTicketTypes() {
        return TicketType.values();
    }

    // Getter for ticket type code
    public String getCode() {
        return code;
    }

    // Getter for ticket type description
    public String getDescription() {
        return description;
    }
}
