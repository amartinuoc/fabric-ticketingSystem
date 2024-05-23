package uoc.tfm.contract.enums;

import lombok.AllArgsConstructor;

@AllArgsConstructor
public enum TicketPriority {

    // Represents low priority tasks
    LOW("PR-001", "Low priority"),

    // Represents medium priority tasks
    MEDIUM("PR-002", "Medium priority"),

    // Represents high priority tasks
    HIGH("PR-003", "High priority"),

    // Represents unknown priority tasks
    UNKNOWN("PR-000", "Unknown priority");

    private final String code; // Ticket priority code
    private final String description; // Ticket priority description

    // Method to get all values of the enum
    public static TicketPriority[] getAllTicketPriorities() {
        return TicketPriority.values();
    }

    /**
     * Returns the enum constant of the specified enum type with the specified name,
     * ignoring case considerations.
     * 
     * @param priority the name of the enum constant to be returned.
     * @return the enum constant with the specified name.
     */
    public static TicketPriority fromString(String priority) {
        if (priority != null) {
            for (TicketPriority tp : TicketPriority.values()) {
                if (priority.equalsIgnoreCase(tp.name())) {
                    return tp;
                }
            }
        }
        return UNKNOWN;
    }

    // Getter for ticket priority code
    public String getCode() {
        return code;
    }

    // Getter for ticket priority description
    public String getDescription() {
        return description;
    }
}