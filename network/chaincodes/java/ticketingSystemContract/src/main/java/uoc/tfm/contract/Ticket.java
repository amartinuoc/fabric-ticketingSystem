package uoc.tfm.contract;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;

import org.hyperledger.fabric.contract.annotation.DataType;
import org.hyperledger.fabric.contract.annotation.Property;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import uoc.tfm.contract.enums.*;

@Data
@NoArgsConstructor
@AllArgsConstructor
@DataType()
public final class Ticket {

    // Unique identifier for the ticket
    @Property()
    @JsonProperty("ticketId")
    private String ticketId;

    // Title of the ticket
    @Property()
    @JsonProperty("title")
    private String title;

    // Description of the ticket
    @Property()
    @JsonProperty("description")
    private String description;

    // Project ID associated with the ticket
    @Property()
    @JsonProperty("projectIdNum")
    private int projectIdNum;

    // Creator of the ticket
    @Property()
    @JsonProperty("creator")
    private String creator;

    // Priority of the ticket
    @Property()
    @JsonProperty("ticketPriority")
    private TicketPriority ticketPriority;

    // Type of the ticket (e.g., Test, Development)
    @Property()
    @JsonProperty("ticketType")
    private TicketType ticketType;

    // Date and time when the ticket was created
    @Property()
    @JsonProperty("creationDate")
    private LocalDateTime creationDate;

    // Date and time when the ticket was last modified
    @Property()
    @JsonProperty("lastModifiedDate")
    private LocalDateTime lastModifiedDate;

    // Person assigned to the ticket
    @Property()
    @JsonProperty("assigned")
    private String assigned;

    // Version of the product related to the ticket
    @Property()
    @JsonProperty("relatedProductVersion")
    private String relatedProductVersion;

    // List of comments related to the ticket
    @Property()
    @JsonProperty("comments")
    private List<String> comments;

    // Story points (estimate of the overall effort required) associated
    @Property()
    @JsonProperty("storyPoints")
    private int storyPoints;

    // Status of the ticket
    @Property()
    @JsonProperty("ticketStatus")
    private TicketStatus ticketStatus;

    // Checks if this ticket is equal to another object
    @Override
    public boolean equals(final Object o) {
        if (this == o) {
            return true;
        }
        if (o == null || getClass() != o.getClass()) {
            return false;
        }
        Ticket ticket = (Ticket) o;
        // Arrays for String comparisons
        Object[] thisStrings = { ticketId, title, description, creator, assigned, relatedProductVersion };
        Object[] otherStrings = { ticket.ticketId, ticket.title, ticket.description, ticket.creator, ticket.assigned,
                ticket.relatedProductVersion };

        // Arrays for int comparisons
        int[] thisInts = { projectIdNum, storyPoints };
        int[] otherInts = { ticket.projectIdNum, ticket.storyPoints };

        // Arrays for LocalDateTime comparisons
        Object[] thisDates = { creationDate, lastModifiedDate };
        Object[] otherDates = { ticket.creationDate, ticket.lastModifiedDate };

        // Arrays for Enum comparisons
        Object[] thisEnums = { ticketPriority, ticketType, ticketStatus };
        Object[] otherEnums = { ticket.ticketPriority, ticket.ticketType, ticket.ticketStatus };

        // Arrays for List<String> comparisons
        Object[] thisComments = { comments };
        Object[] otherComments = { ticket.comments };

        return Objects.deepEquals(thisStrings, otherStrings) &&
                Objects.deepEquals(thisInts, otherInts) &&
                Objects.deepEquals(thisDates, otherDates) &&
                Objects.deepEquals(thisEnums, otherEnums) &&
                Objects.deepEquals(thisComments, otherComments);
    }

    // Generates a hash code for this ticket
    @Override
    public int hashCode() {
        return Objects.hash(ticketId, title, description, projectIdNum, creator, ticketPriority, ticketType,
                creationDate, lastModifiedDate, assigned, relatedProductVersion, comments, storyPoints, ticketStatus);
    }

    // Returns a string representation of this ticket
    @Override
    public String toString() {
        return this.getClass().getSimpleName() + "@" + Integer.toHexString(hashCode()) +
                "{" +
                "ticketId='" + ticketId + "'" +
                ", title='" + title + "'" +
                ", description='" + description + "'" +
                ", projectIdNum=" + projectIdNum +
                ", creator='" + creator + "'" +
                ", ticketPriority=" + (ticketPriority != null ? ticketPriority.name() : "null") +
                ", ticketType=" + (ticketType != null ? ticketType.name() : "null") +
                ", creationDate=" + creationDate +
                ", lastModifiedDate=" + lastModifiedDate +
                ", assigned='" + assigned + "'" +
                ", relatedProductVersion='" + relatedProductVersion + "'" +
                ", comments=" + comments +
                ", storyPoints=" + storyPoints +
                ", ticketStatus=" + (ticketStatus != null ? ticketStatus.name() : "null") +
                '}';
    }
}