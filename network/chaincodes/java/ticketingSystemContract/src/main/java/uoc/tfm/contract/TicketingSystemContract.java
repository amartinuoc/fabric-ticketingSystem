package uoc.tfm.contract;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

import org.json.JSONObject;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import org.hyperledger.fabric.contract.Context;
import org.hyperledger.fabric.contract.ContractInterface;
import org.hyperledger.fabric.contract.annotation.Contact;
import org.hyperledger.fabric.contract.annotation.Contract;
import org.hyperledger.fabric.contract.annotation.Default;
import org.hyperledger.fabric.contract.annotation.Info;
import org.hyperledger.fabric.contract.annotation.License;
import org.hyperledger.fabric.contract.annotation.Transaction;
import org.hyperledger.fabric.shim.ChaincodeException;
import org.hyperledger.fabric.shim.ChaincodeStub;
import org.hyperledger.fabric.shim.ledger.KeyModification;
import org.hyperledger.fabric.shim.ledger.KeyValue;
import org.hyperledger.fabric.shim.ledger.QueryResultsIterator;

import uoc.tfm.contract.enums.TicketError;
import uoc.tfm.contract.enums.TicketPriority;
import uoc.tfm.contract.enums.TicketStatus;
import uoc.tfm.contract.enums.TicketType;

@Contract(name = "TicketingSystemContract", info = @Info(title = "Ticketing System", description = "Contract for managing the lifecycle of tickets in a system.", version = "0.0.1-SNAPSHOT", license = @License(name = "Apache 2.0 License", url = "http://www.apache.org/licenses/LICENSE-2.0.html"), contact = @Contact(email = "amartinno@uoc.edu", name = "Alvaro Martin", url = "https://www.uoc.edu/es")))
@Default
public final class TicketingSystemContract implements ContractInterface {

    // Create an ObjectMapper with the JavaTimeModule module
    private final ObjectMapper mapper = new ObjectMapper().registerModule(new JavaTimeModule());

    private static int ticketIdNum_dev = 0;
    private static int ticketIdNum_qa = 0;

    /************************************************************************/
    /* SUBMIT TRANSACTIONS METHODS */
    /************************************************************************/

    /**
     * Creates some initial tickets on the ledger.
     *
     * @param ctx the transaction context
     */
    @Transaction(intent = Transaction.TYPE.SUBMIT)
    public String InitLedger(final Context ctx) {

        System.out.println("[InitLedger] Trying open new tickets");

        // Retrieve the name of the channel
        String channelName = getChannelName(ctx);

        List<Ticket> tickets = null;
        /// Open initial tickets based on the channel type
        if (channelName.contains("dev")) {
            // If the channel is for development, create development tickets
            tickets = openInitDevTickets(ctx);
        } else if (channelName.contains("qa")) {
            // If the channel is for QA, create QA tickets
            tickets = openInitQaTickets(ctx);
        }

        // Get the number of tickets
        int numberOfTickets = (tickets != null) ? tickets.size() : 0;

        // Get the IDs of the tickets
        List<String> ticketIds = new ArrayList<>();
        if (tickets != null) {
            for (Ticket ticket : tickets) {
                ticketIds.add(ticket.getTicketId());
            }
        }

        // Get the current date and time
        final LocalDateTime currentDateTime = getCurrentLocalDateTime(ctx);

        // Create a JSON response with number of tickets, list of IDs and timestamp
        JSONObject jsonResponseObject = new JSONObject();
        jsonResponseObject.put("NumberOfTickets", numberOfTickets);
        jsonResponseObject.put("TicketIds", ticketIds);
        jsonResponseObject.put("TimestampOperation", currentDateTime);
        String jsonResponse = jsonResponseObject.toString();

        System.out.println("[InitLedger] OK: " + jsonResponse);
        return jsonResponse;
    }

    /**
     * Creates and opens a new ticket on the ledger.
     *
     * @param ctx             the transaction context
     * @param title           the title of the ticket
     * @param description     the description of the ticket
     * @param projectIdNum    the ID of the project associated with the ticket
     * @param creator         the creator of the ticket
     * @param priority        the priority of the ticket
     * @param initStoryPoints the story points associated with the ticket
     * @return the created ticket
     */
    @Transaction(intent = Transaction.TYPE.SUBMIT)
    public Ticket OpenNewTicket(
            final Context ctx,
            final String title,
            final String description,
            final int projectIdNum,
            final String creator,
            final String priority,
            final int initStoryPoints) {

        ChaincodeStub stub = ctx.getStub();
        final String ticketId = getTicketId(ctx);

        System.out.println("[OpenNewTicket] Trying with ticketId=" + ticketId);

        // Check if the ticket exists
        if (ticketExists(ctx, ticketId)) {
            String errorMessage = String.format("Ticket %s already exists", ticketId);
            System.out.println(errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_ALREADY_EXISTS.getCodeAndName());
        }

        // Parse the priority from string to enum
        final TicketPriority ticketPriority = TicketPriority.fromString(priority);
        // Gets the ticket type from the context.
        final TicketType ticketType = getTicketType(ctx);
        // Retrieves the current date and time.
        final LocalDateTime currentDateTime = getCurrentLocalDateTime(ctx);
        // Initializes the assigned field as empty.
        final String assigned = "";
        // Initializes the related product version field as empty.
        final String relatedProductVersion = "";
        // Creates an empty list for comments.
        final List<String> comments = new ArrayList<>();
        // Sets the ticket status to OPEN.
        final TicketStatus ticketStatus = TicketStatus.OPEN;

        try {
            // Create the ticket object
            final Ticket ticket = new Ticket(
                    ticketId,
                    title,
                    description,
                    projectIdNum,
                    creator,
                    ticketPriority,
                    ticketType,
                    currentDateTime,
                    currentDateTime,
                    assigned,
                    relatedProductVersion,
                    comments,
                    initStoryPoints,
                    ticketStatus);

            // Serialize the ticket object to JSON and store it in the ledger
            final String jsonTicket = mapper.writeValueAsString(ticket);
            stub.putStringState(ticketId, jsonTicket);

            System.out.println("[OpenNewTicket] OK: " + ticket);
            return ticket;

        } catch (JsonProcessingException e) {
            System.out.println("[OpenNewTicket] NOK");
            // Handle JSON processing errors
            return handleJsonProcessingError(e, Ticket.class);
        }
    }

    /**
     * Updates the ticket status to indicate it is now in progress
     * and may assign a new person and/or add a comment.
     *
     * @param ctx      the transaction context
     * @param ticketId the ID of the ticket being updated
     * @param assigned the new assigned person
     * @param comment  an optional comment
     * @return the updated ticket
     */
    @Transaction(intent = Transaction.TYPE.SUBMIT)
    public Ticket UpdateTicketToInProgress(
            final Context ctx,
            final String ticketId,
            final String assigned,
            final String comment) {

        System.out.println("[UpdateTicketToInProgress] Trying with ticketId=" + ticketId);

        // Retrieve the ticket from the ledger
        Ticket ticket = ReadTicket(ctx, ticketId);

        // Check if the ticket status is OPEN
        if (ticket.getTicketStatus() != TicketStatus.OPEN) {
            String errorMessage = String.format(
                    "Ticket %s must be in OPEN to be updated to IN_PROGRESS",
                    ticketId);
            System.out.println("[UpdateTicketToInProgress] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_INVALID_STATUS.getCodeAndName());
        }

        // Get the current date and time
        final LocalDateTime currentDateTime = getCurrentLocalDateTime(ctx);

        // Update the ticket details
        ticket.setAssigned(assigned);
        ticket.setTicketStatus(TicketStatus.IN_PROGRESS);
        if (!comment.isEmpty()) {
            ticket.getComments().add(comment);
        }
        ticket.setLastModifiedDate(currentDateTime);

        // Update the ticket in the ledger and return the updated ticket
        Ticket updatedTicket = updateTicket(ctx, ticket);

        System.out.println("[UpdateTicketToInProgress] OK: " + updatedTicket);
        return updatedTicket;
    }

    /**
     * Adds a comment to a ticket that is in progress.
     * The ticket must be in the IN_PROGRESS state for the comment to be added.
     * The method will update the last modified date of the ticket if the comment is
     * not empty.
     *
     * @param ctx      the transaction context
     * @param ticketId the ID of the ticket being updated
     * @param comment  the comment to be added to the ticket
     * @return the updated ticket
     */
    @Transaction(intent = Transaction.TYPE.SUBMIT)
    public Ticket AddCommentForTicketInProgress(
            final Context ctx,
            final String ticketId,
            final String comment) {

        System.out.println("[addCommentForTicketInProgress] Trying with ticketId=" + ticketId);

        // Check if the comment is empty
        if (comment == null || comment.trim().isEmpty()) {
            String errorMessage = String.format(
                    "New comment cannot be empty for ticket %s",
                    ticketId);
            System.out.println("[addCommentForTicketInProgress] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_COMMENT_EMPTY.getCodeAndName());
        }

        // Retrieve the ticket from the ledger
        Ticket ticket = ReadTicket(ctx, ticketId);

        // Check if the ticket status is IN_PROGRESS
        if (ticket.getTicketStatus() != TicketStatus.IN_PROGRESS) {
            String errorMessage = String.format(
                    "Ticket %s must be in IN_PROGRESS to add a comment",
                    ticketId);
            System.out.println("[addCommentForTicketInProgress] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_INVALID_STATUS.getCodeAndName());
        }

        // Get the current date and time
        final LocalDateTime currentDateTime = getCurrentLocalDateTime(ctx);

        // Update the ticket details
        ticket.getComments().add(comment);
        ticket.setLastModifiedDate(currentDateTime);

        // Update the ticket in the ledger and return the updated ticket
        Ticket updatedTicket = updateTicket(ctx, ticket);

        System.out.println("[addCommentForTicketInProgress] OK: " + updatedTicket);
        return updatedTicket;
    }

    /**
     * Updates the ticket status to indicate it has been resolved,
     * setting related product version and real story points.
     *
     * @param ctx                   the transaction context
     * @param ticketId              the ID of the ticket being updated
     * @param relatedProductVersion the related product version
     * @param realinitS             the actual story points
     * @param comment               an optional comment
     * @return the updated ticket
     */
    @Transaction(intent = Transaction.TYPE.SUBMIT)
    public Ticket UpdateTicketToResolved(
            final Context ctx,
            final String ticketId,
            final String relatedProductVersion,
            final int realStoryPoints,
            final String comment) {

        System.out.println("[UpdateTicketToResolved] Trying with ticketId=" + ticketId);

        // Retrieve the ticket from the ledger
        Ticket ticket = ReadTicket(ctx, ticketId);

        // Check if the ticket status is IN_PROGRESS
        if (ticket.getTicketStatus() != TicketStatus.IN_PROGRESS) {
            String errorMessage = String.format(
                    "Ticket %s must be in IN_PROGRESS to be updated to RESOLVED",
                    ticketId);
            System.out.println("[UpdateTicketToResolved] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_INVALID_STATUS.getCodeAndName());
        }

        // Get the current date and time
        final LocalDateTime currentDateTime = getCurrentLocalDateTime(ctx);

        // Update the ticket details
        ticket.setTicketStatus(TicketStatus.RESOLVED);
        ticket.setRelatedProductVersion(relatedProductVersion);
        ticket.setStoryPoints(realStoryPoints);
        if (!comment.isEmpty()) {
            ticket.getComments().add(comment);
        }
        ticket.setLastModifiedDate(currentDateTime);

        // Update the ticket in the ledger and return the updated ticket
        Ticket updatedTicket = updateTicket(ctx, ticket);

        System.out.println("[UpdateTicketToResolved] OK: " + updatedTicket);
        return updatedTicket;
    }

    /**
     * Updates the ticket status to indicate it has been closed,
     * adding an optional comment.
     *
     * @param ctx      the transaction context
     * @param ticketId the ID of the ticket being updated
     * @param comment  an optional comment
     * @return the updated ticket
     */
    @Transaction(intent = Transaction.TYPE.SUBMIT)
    public Ticket UpdateTicketToClosed(final Context ctx, final String ticketId, final String comment) {

        System.out.println("[UpdateTicketToClosed] Trying with ticketId=" + ticketId);

        // Retrieve the ticket from the ledger
        Ticket ticket = ReadTicket(ctx, ticketId);

        // Check if the ticket status is RESOLVED
        if (ticket.getTicketStatus() != TicketStatus.RESOLVED) {
            String errorMessage = String.format(
                    "Ticket %s must be in RESOLVED to be updated to CLOSED",
                    ticketId);
            System.out.println("[UpdateTicketToClosed] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_INVALID_STATUS.getCodeAndName());
        }

        // Get the current date and time
        final LocalDateTime currentDateTime = getCurrentLocalDateTime(ctx);

        // Update the ticket details
        ticket.setTicketStatus(TicketStatus.CLOSED);
        if (!comment.isEmpty()) {
            ticket.getComments().add(comment);
        }
        ticket.setLastModifiedDate(currentDateTime);

        // Update the ticket in the ledger and return the updated ticket
        Ticket updatedTicket = updateTicket(ctx, ticket);

        System.out.println("[UpdateTicketToClosed] OK: " + updatedTicket);
        return updatedTicket;
    }

    /**
     * Deletes a ticket from the ledger.
     *
     * @param ctx      the transaction context
     * @param ticketId the ID of the ticket to be deleted
     * @return the timestamp of the deletion
     */
    @Transaction(intent = Transaction.TYPE.SUBMIT)
    public String DeleteTicket(final Context ctx, final String ticketId) {

        System.out.println("[DeleteTicket] Trying with ticketId=" + ticketId);

        ChaincodeStub stub = ctx.getStub();

        // Check if the ticket exists
        if (!ticketExists(ctx, ticketId)) {
            String errorMessage = String.format(
                    "Ticket %s does not exist",
                    ticketId);
            System.out.println("[DeleteTicket] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_NOT_FOUND.getCodeAndName());
        }

        // Delete the ticket from the ledger
        stub.delState(ticketId);

        // Get the current date and time
        final LocalDateTime currentDateTime = getCurrentLocalDateTime(ctx);

        // Create a JSON response with ticket ID and timestamp
        JSONObject jsonResponseObject = new JSONObject();
        jsonResponseObject.put("TicketId", ticketId);
        jsonResponseObject.put("TimestampOperation", currentDateTime);
        String jsonResponse = jsonResponseObject.toString();

        System.out.println("[DeleteTicket] OK: " + jsonResponse);
        return jsonResponse;
    }

    /************************************************************************/
    /* EVALUATE TRANSACTIONS METHODS */
    /************************************************************************/

    /**
     * Retrieves a ticket from the ledger by its ID.
     *
     * @param ctx      the transaction context
     * @param ticketId the ID of the ticket to retrieve
     * @return the ticket object
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public Ticket ReadTicket(final Context ctx, final String ticketId) {

        System.out.println("[ReadTicket] Trying with ticketId=" + ticketId);

        ChaincodeStub stub = ctx.getStub();
        String jsonTicket = stub.getStringState(ticketId);

        // Check if the ticket exists
        if (jsonTicket == null || jsonTicket.isEmpty()) {
            String errorMessage = String.format(
                    "Ticket %s does not exist",
                    ticketId);
            System.out.println("[ReadTicket] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_NOT_FOUND.getCodeAndName());
        }

        try {
            // Deserialize the JSON string to a Ticket object
            Ticket ticket = mapper.readValue(jsonTicket, Ticket.class);

            System.out.println("[ReadTicket] OK: " + ticket);
            return ticket;

        } catch (JsonProcessingException e) {
            System.out.println("[ReadTicket] NOK: Error processing JSON");
            // Handle JSON processing errors
            return handleJsonProcessingError(e, Ticket.class);
        }
    }

    /**
     * Retrieves all tickets from the ledger.
     *
     * @param ctx the transaction context
     * @return array of tickets found on the ledger
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public String GetAllTickets(final Context ctx) {

        System.out.println("[GetAllTickets] Trying with all tickets");

        ChaincodeStub stub = ctx.getStub();
        List<Ticket> queryResults = new ArrayList<>();

        // Query the ledger for all tickets by specifying a range
        QueryResultsIterator<KeyValue> results = stub.getStateByRange("", "");

        try {
            // Iterate through the query results
            for (KeyValue result : results) {
                // Deserialize each ticket from JSON format
                Ticket ticket = mapper.readValue(result.getStringValue(), Ticket.class);
                System.out.println("[GetAllTickets] Retrieved ticket: " + ticket);
                queryResults.add(ticket);
            }

            // Serialize the list of tickets to JSON format
            final String jsonResponse = mapper.writeValueAsString(queryResults);

            System.out.println("[GetAllTickets] OK: Retrieved " + queryResults.size() + " tickets");
            return jsonResponse;

        } catch (JsonProcessingException e) {
            System.out.println("[GetAllTickets] NOK: Error processing JSON");
            return handleJsonProcessingError(e, String.class);
        }
    }

    /**
     * Retrieves all tickets from the ledger by project.
     *
     * @param ctx          the transaction context
     * @param projectIdNum the numeric id of the project to filter tickets by
     * @return array of tickets found on the ledger for the specified project
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public String GetAllTicketsByProject(final Context ctx, int projectIdNum) {

        System.out.println("[GetAllTicketsByProject] Trying with projectIdNum=" + projectIdNum);

        ChaincodeStub stub = ctx.getStub();
        List<Ticket> queryResults = new ArrayList<>();

        // Query the ledger for all tickets by specifying a range
        QueryResultsIterator<KeyValue> results = stub.getStateByRange("", "");

        try {
            // Iterate through the query results
            for (KeyValue result : results) {
                // Deserialize each ticket from JSON format
                Ticket ticket = mapper.readValue(result.getStringValue(), Ticket.class);
                // Check if the ticket belongs to the specified project
                if (ticket.getProjectIdNum() == projectIdNum) {
                    System.out.println("[GetAllTicketsByProject] Retrieved ticket: " + ticket);
                    queryResults.add(ticket);
                }
            }

            // Serialize the list of tickets to JSON format
            final String jsonResponse = mapper.writeValueAsString(queryResults);

            System.out.println("[GetAllTicketsByProject] OK: Retrieved " + queryResults.size() +
                    " tickets for projectID=" + projectIdNum);
            return jsonResponse;

        } catch (JsonProcessingException e) {
            // Handle any JSON processing errors
            System.out.println("[GetAllTicketsByProject] NOK: Error processing JSON");
            return handleJsonProcessingError(e, String.class);
        }
    }

    /**
     * Retrieves all tickets from the ledger by status.
     *
     * @param ctx    the transaction context
     * @param status the status to filter tickets by
     * @return array of tickets found on the ledger with the specified status
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public String GetAllTicketsByStatus(final Context ctx, String status) {

        System.out.println("[GetAllTicketsByStatus] Trying with status=" + status);

        // Validate the status input
        try {
            TicketStatus.valueOf(status);
        } catch (IllegalArgumentException e) {
            String errorMessage = TicketError.TICKET_INVALID_STATUS.getDescription() + ": " + status;
            System.out.println("[GetAllTicketsByStatus] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_INVALID_STATUS.getCodeAndName());
        }

        ChaincodeStub stub = ctx.getStub();
        List<Ticket> queryResults = new ArrayList<>();
        QueryResultsIterator<KeyValue> results = stub.getStateByRange("", "");

        try {
            // Iterate through the query results
            for (KeyValue result : results) {
                // Deserialize each ticket from JSON format
                Ticket ticket = mapper.readValue(result.getStringValue(), Ticket.class);
                // Check if the ticket status matches the specified status
                if (ticket.getTicketStatus().name().equals(status)) {
                    System.out.println("[GetAllTicketsByStatus] Retrieved ticket: " + ticket);
                    queryResults.add(ticket);
                }
            }

            // Serialize the list of tickets to JSON format
            final String jsonResponse = mapper.writeValueAsString(queryResults);

            System.out.println("[GetAllTicketsByStatus] OK: Retrieved " + queryResults.size() +
                    " tickets with status=" + status);
            return jsonResponse;

        } catch (JsonProcessingException e) {
            // Handle any JSON processing errors
            System.out.println("[GetAllTicketsByStatus] NOK: Error processing JSON");
            return handleJsonProcessingError(e, String.class);
        }
    }

    /**
     * Retrieves all tickets from the ledger by the assigned user.
     *
     * @param ctx      the transaction context
     * @param assigned the assigned user to filter tickets by
     * @return array of tickets found on the ledger assigned to the specified user
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public String GetAllTicketsByAssigned(final Context ctx, String assigned) {

        System.out.println("[GetAllTicketsByAssigned] Trying with assigned=" + assigned);

        // Validate the assigned input
        if (assigned == null || assigned.trim().isEmpty()) {
            String errorMessage = TicketError.TICKET_ASSIGNED_EMPTY.getDescription();
            System.out.println("[GetAllTicketsByAssigned] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_ASSIGNED_EMPTY.getCodeAndName());
        }

        ChaincodeStub stub = ctx.getStub();
        List<Ticket> queryResults = new ArrayList<>();
        QueryResultsIterator<KeyValue> results = stub.getStateByRange("", "");

        try {
            // Iterate through the query results
            for (KeyValue result : results) {
                // Deserialize each ticket from JSON format
                Ticket ticket = mapper.readValue(result.getStringValue(), Ticket.class);
                // Check if the assigned user in ticket matches the specified assigned user
                if (ticket.getAssigned().contains(assigned)) {
                    System.out.println("[GetAllTicketsByAssigned] Retrieved ticket: " + ticket);
                    queryResults.add(ticket);
                }
            }

            // Serialize the list of tickets to JSON format
            final String jsonResponse = mapper.writeValueAsString(queryResults);

            System.out.println("[GetAllTicketsByAssigned] OK: Retrieved " + queryResults.size() +
                    " tickets assigned to " + assigned);
            return jsonResponse;

        } catch (JsonProcessingException e) {
            // Handle any JSON processing errors
            System.out.println("[GetAllTicketsByAssigned] NOK: Error processing JSON");
            return handleJsonProcessingError(e, String.class);
        }
    }

    /**
     * Retrieves the transaction history for a specific ticket from the ledger.
     *
     * @param ctx      the transaction context
     * @param ticketId the ID of the ticket to retrieve history for
     * @return JSON string representing the transaction history
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    public String GetTicketHistory(Context ctx, String ticketId) {

        System.out.println("[GetTicketHistory] Trying with ticketId=" + ticketId);

        // Retrieve the transaction history for the specified ticket ID
        QueryResultsIterator<KeyModification> resultsIterator = ctx.getStub().getHistoryForKey(ticketId);
        List<String> history = new ArrayList<>();

        try {
            // Iterate through the transaction history results
            for (KeyModification km : resultsIterator) {
                // Build a record for each transaction
                StringBuilder record = new StringBuilder();
                record.append("TransactionID: ").append(km.getTxId());
                record.append(", Timestamp: ").append(km.getTimestamp());
                record.append(", IsDeleted: ").append(km.isDeleted());
                record.append(", Value: ").append(new String(km.getValue()));

                // Add the transaction record to the history list
                history.add(record.toString());
            }
        } catch (Exception e) {
            // Handle any exceptions that occur during history retrieval
            String errorMessage = String.format("%s %s: %s",
                    TicketError.TICKET_HISTORY_RETRIEVAL_ERROR.getDescription(),
                    ticketId, e.getMessage());
            System.out.println("[GetTicketHistory] NOK: " + errorMessage);
            throw new ChaincodeException(errorMessage, TicketError.TICKET_HISTORY_RETRIEVAL_ERROR.getCodeAndName());
        } finally {
            try {
                // Close the results iterator after use
                if (resultsIterator != null) {
                    resultsIterator.close();
                }
            } catch (Exception e) {
                // errors that occur while closing the results iterator
                System.out.println("[GetTicketHistory] Error closing results iterator: " + e.getMessage());
            }
        }

        try {
            // Convert the history list to JSON format
            final String jsonResponse = mapper.writeValueAsString(history);
            System.out.println("[GetTicketHistory] OK: Retrieved history for ticketId=" + ticketId);
            return jsonResponse;

        } catch (JsonProcessingException e) {
            // Handle any JSON processing errors
            System.out.println("[GetTicketHistory] NOK: Error processing JSON");
            return handleJsonProcessingError(e, String.class);
        }
    }

    /************************************************************************/
    /* PRIVATE METHODS */
    /************************************************************************/

    /**
     * Checks the existence of the ticket on the ledger
     *
     * @param ctx      the transaction context
     * @param ticketId the ID of the ticket
     * @return boolean indicating the existence of the ticket
     */
    @Transaction(intent = Transaction.TYPE.EVALUATE)
    private boolean ticketExists(final Context ctx, final String ticketId) {
        ChaincodeStub stub = ctx.getStub();
        String jsonTicket = stub.getStringState(ticketId);
        return (jsonTicket != null && !jsonTicket.isEmpty());
    }

    /**
     * Updates a ticket in the ledger.
     *
     * @param ctx       the transaction context
     * @param newTicket the updated ticket object
     * @return the updated ticket object
     */
    private Ticket updateTicket(final Context ctx, final Ticket ticket) {

        ChaincodeStub stub = ctx.getStub();

        // Check if the ticket exists before updating
        if (!ticketExists(ctx, ticket.getTicketId())) {
            String errorMessage = String.format("Ticket %s does not exist", ticket.getTicketId());
            throw new ChaincodeException(errorMessage, TicketError.TICKET_NOT_FOUND.getCodeAndName());
        }

        try {
            // Serialize the updated ticket object to JSON and update the ledger
            String jsonTicket = mapper.writeValueAsString(ticket);
            stub.putStringState(ticket.getTicketId(), jsonTicket);
            return ticket;

        } catch (JsonProcessingException e) {
            // Handle any JSON processing errors
            return handleJsonProcessingError(e, Ticket.class);
        }
    }

    /**
     * Generates the ticket ID based on the channel name and the last ticket ID
     * number.
     * 
     * @param ctx the transaction context
     * @return the next ticket ID
     */
    private String getTicketId(final Context ctx) {
        long epochMs = ctx.getStub().getTxTimestamp().toEpochMilli();
        String channelName = getChannelName(ctx);
        if (channelName.contains("dev")) {
            long id = epochMs + ticketIdNum_dev;
            return "dev_t" + id;
        } else if (channelName.contains("qa")) {
            long id = epochMs + ticketIdNum_qa;
            return "qa_t" + id;
        } else {
            return "XX_t" + epochMs;
        }
    }

    /**
     * Increases the ticket ID number based on the channel name.
     * 
     * @param ctx the transaction context
     */
    private void increaseTicketIdNum(final Context ctx) {
        String channelName = getChannelName(ctx);
        if (channelName.contains("dev")) {
            ticketIdNum_dev++;
        } else if (channelName.contains("qa")) {
            ticketIdNum_qa++;
        }
    }

    /**
     * Resets the ticket ID number based on the channel name.
     * 
     * @param ctx the transaction context
     */
    private void resetTicketIdNum(final Context ctx) {
        String channelName = getChannelName(ctx);
        if (channelName.contains("dev")) {
            ticketIdNum_dev = 0;
        } else if (channelName.contains("qa")) {
            ticketIdNum_qa = 0;
        }
    }

    /**
     * Retrieves the ticket type based on the channel name.
     * 
     * @param ctx the transaction context
     * @return the ticket type
     */
    private TicketType getTicketType(final Context ctx) {
        String channelName = getChannelName(ctx);
        if (channelName.contains("dev")) {
            return TicketType.DEVELOPMENT;
        } else if (channelName.contains("qa")) {
            return TicketType.TEST;
        } else {
            return TicketType.UNKNOWN;
        }
    }

    /**
     * Retrieves the channel name from the transaction context.
     * 
     * @param ctx the transaction context
     * @return the channel name
     */
    private String getChannelName(final Context ctx) {
        ChaincodeStub stub = ctx.getStub();
        return stub.getChannelId().toLowerCase();
    }

    /**
     * Retrieves the current local date and time based on the transaction timestamp.
     * 
     * @param ctx the transaction context
     * @return the current local date and time
     */
    private LocalDateTime getCurrentLocalDateTime(final Context ctx) {
        return LocalDateTime.ofInstant(
                ctx.getStub().getTxTimestamp(),
                ZoneId.of("Europe/Madrid"));
    }

    @SuppressWarnings("null")
    private <T> T handleJsonProcessingError(JsonProcessingException e, Class<T> returnType) {
        String errorMessage = TicketError.TICKET_JSON_PROCESSING_ERROR.getDescription() + ": " + e.getMessage();
        System.out.println(errorMessage);

        if (returnType == null) {
            return returnType.cast(null);
        }

        if (returnType.equals(String.class) || returnType.equals(Ticket.class)) {
            throw new ChaincodeException(errorMessage, TicketError.TICKET_JSON_PROCESSING_ERROR.getCodeAndName());
        } else {
            throw new IllegalArgumentException("handleJsonProcessingError - returnType cannot be null");
        }
    }

    /**
     * Creates initial development tickets.
     *
     * @param ctx the transaction context
     * @return a list of initial development tickets
     */
    private List<Ticket> openInitDevTickets(final Context ctx) {
        List<Ticket> devTickets = new ArrayList<>();

        // Create development tickets
        devTickets.add(OpenNewTicket(ctx, "Build login page layout (Dev)",
                "The login page layout needs to be adjusted for better mobile responsiveness.",
                1, "Sofía García", TicketPriority.LOW.name(), 3));

        increaseTicketIdNum(ctx);

        devTickets.add(OpenNewTicket(ctx, "Add product filtering feature (Dev)",
                "Users should be able to filter products based on various criteria.",
                1, "Lucía Martínez", TicketPriority.HIGH.name(), 8));

        increaseTicketIdNum(ctx);

        devTickets.add(OpenNewTicket(ctx, "Implement user registration (Dev)",
                "New users should be able to register accounts on the platform.",
                2, "Pablo Ruiz", TicketPriority.MEDIUM.name(), 5));

        increaseTicketIdNum(ctx);

        devTickets.add(OpenNewTicket(ctx, "Implement OAuth2 authentication (Dev)",
                "OAuth2 authentication needs to be integrated for better security.",
                2, "Marta Rodríguez", TicketPriority.MEDIUM.name(), 8));

        increaseTicketIdNum(ctx);

        devTickets.add(OpenNewTicket(ctx, "Fix database connection issue (Dev)",
                "There is an intermittent issue with connecting to the database.",
                3, "Javier López", TicketPriority.HIGH.name(), 5));

        increaseTicketIdNum(ctx);

        devTickets.add(OpenNewTicket(ctx, "Update API documentation (Dev)",
                "The API documentation needs to be updated to reflect recent changes.",
                3, "Andrea Sánchez", TicketPriority.LOW.name(), 2));

        resetTicketIdNum(ctx);

        return devTickets;
    }

    /**
     * Creates initial QA tickets.
     *
     * @param ctx the transaction context
     * @return a list of initial QA tickets
     */
    private List<Ticket> openInitQaTickets(final Context ctx) {
        List<Ticket> qaTickets = new ArrayList<>();

        // Create QA tickets
        qaTickets.add(OpenNewTicket(ctx, "Perform login page layout testing (QA)",
                "The login page layout needs to be tested on various devices and browsers.",
                1, "David Martínez", TicketPriority.LOW.name(), 2));

        increaseTicketIdNum(ctx);

        qaTickets.add(OpenNewTicket(ctx, "Test product filtering feature (QA)",
                "The product filtering feature should be tested with different filter combinations.",
                1, "Carlos García", TicketPriority.HIGH.name(), 3));

        increaseTicketIdNum(ctx);

        qaTickets.add(OpenNewTicket(ctx, "Conduct user registration testing (QA)",
                "Registration functionality needs to be thoroughly tested to ensure it works as expected.",
                2, "Laura López", TicketPriority.MEDIUM.name(), 2));

        increaseTicketIdNum(ctx);

        qaTickets.add(OpenNewTicket(ctx, "Perform OAuth2 authentication testing (QA)",
                "OAuth2 authentication flows should be tested to ensure they work correctly.",
                2, "Elena Gómez", TicketPriority.MEDIUM.name(), 3));

        increaseTicketIdNum(ctx);

        qaTickets.add(OpenNewTicket(ctx, "Test database connection stability (QA)",
                "Database connections should be tested under varying load conditions for stability.",
                3, "Ana Fernández", TicketPriority.HIGH.name(), 2));

        increaseTicketIdNum(ctx);

        qaTickets.add(OpenNewTicket(ctx, "Review and verify API documentation (QA)",
                "API documentation needs to be reviewed and verified for accuracy and completeness.",
                3, "Diego Martín", TicketPriority.LOW.name(), 2));

        resetTicketIdNum(ctx);

        return qaTickets;
    }

}
