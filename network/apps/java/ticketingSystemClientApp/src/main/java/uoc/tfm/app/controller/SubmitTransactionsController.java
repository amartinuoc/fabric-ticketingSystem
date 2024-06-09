package uoc.tfm.app.controller;

import org.hyperledger.fabric.client.CommitException;
import org.hyperledger.fabric.client.CommitStatusException;
import org.hyperledger.fabric.client.EndorseException;
import org.hyperledger.fabric.client.SubmitException;
import org.hyperledger.fabric.client.TransactionException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.extern.slf4j.Slf4j;
import uoc.tfm.app.model.dto.TicketDto;
import uoc.tfm.app.model.dto.TicketPriority;
import uoc.tfm.app.service.FabricGatewayService;
import uoc.tfm.app.util.JsonUtils;

@Slf4j
@RestController
@RequestMapping("/api/v1/fabric/submit-transactions/")
@OpenAPIDefinition(info = @Info(title = "Ticketing System UOC TFM API", version = "1.0.0"))
@Tag(name = "Submit Transactions")
public class SubmitTransactionsController {

    private final FabricGatewayService fabricGatewayService;

    public SubmitTransactionsController(FabricGatewayService fabricGatewayService) {
        this.fabricGatewayService = fabricGatewayService;
    }

    /**
     * Creates and opens a new ticket on the ledger.
     *
     * @param title           the title of the ticket
     * @param description     the description of the ticket
     * @param projectIdNum    the ID of the project associated with the ticket
     * @param creator         the creator of the ticket
     * @param priority        the priority of the ticket
     * @param initStoryPoints the story points associated with the ticket
     * @return the created ticket
     */
    @PostMapping("/open-new-ticket")
    @Operation(summary = "Create and open a new ticket", description = "Creates and opens a new ticket on the ledger")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Successfully created ticket", content = @Content(schema = @Schema(implementation = TicketDto.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    public ResponseEntity<?> openNewTicket(
            @Parameter(name = "title", description = "Title of the ticket") @RequestParam String title,
            @Parameter(name = "description", description = "Description of the ticket") @RequestParam String description,
            @Parameter(name = "projectIdNum", description = "ID of the project associated with the ticket") @RequestParam int projectIdNum,
            @Parameter(name = "creator", description = "Creator of the ticket") @RequestParam String creator,
            @Parameter(name = "priority", description = "Priority of the ticket") @RequestParam TicketPriority priority,
            @Parameter(name = "initStoryPoints", description = "Initial story points associated with the ticket") @RequestParam int initStoryPoints) {

        String methodName = "OpenNewTicket";

        log.info("\n--> Submit Transaction: {} [creating a new ticket on the ledger]", methodName);

        // Validate input parameters
        if (title == null || title.isEmpty()) {
            String msg = "Title cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }
        if (description == null || description.isEmpty()) {
            String msg = "Description cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }
        if (creator == null || creator.isEmpty()) {
            String msg = "Creator cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }

        // Check if the service is not operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            // Submit the transaction to open a new ticket
            var result = fabricGatewayService.getContract().submitTransaction(
                    methodName,
                    title,
                    description,
                    String.valueOf(projectIdNum),
                    creator,
                    priority.name(),
                    String.valueOf(initStoryPoints));

            // Convert the result to a pretty JSON format
            String prettyResult = JsonUtils.prettyJson(result);
            // Deserialize the JSON string to a TicketDto object
            TicketDto ticket = TicketDto.fromJson(prettyResult);

            log.info("*** Transaction committed successfully: " + ticket);
            // Return the created ticket with status 201 Created
            return ResponseEntity.status(201).body(ticket);

        } catch (Exception e) {
            // Handle exceptions
            return handleException(e, methodName);
        }
    }

    /**
     * Updates the ticket status to indicate it is now in progress
     * and may assign a new person and/or add a comment.
     *
     * @param ticketId the ID of the ticket being updated
     * @param assigned the new assigned person
     * @param comment  an optional comment
     * @return the updated ticket
     */
    @PostMapping("/update-ticket-to-in-progress")
    @Operation(summary = "Update ticket to In Progress", description = "Updates the ticket status to indicate it is now in progress and may assign a new person and/or add a comment")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully updated ticket", content = @Content(schema = @Schema(implementation = TicketDto.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    public ResponseEntity<?> updateTicketToInProgress(
            @Parameter(name = "ticketId", description = "ID of the ticket being updated") @RequestParam String ticketId,
            @Parameter(name = "assigned", description = "New assigned person") @RequestParam String assigned,
            @Parameter(name = "comment", description = "An optional comment") @RequestParam(required = false) String comment) {

        String methodName = "UpdateTicketToInProgress";

        log.info("\n--> Submit Transaction: {} [updating ticket to IN_PROGRESS on the ledger]", methodName);

        // Validate input parameters
        if (ticketId == null || ticketId.isEmpty()) {
            String msg = "Ticket ID cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }
        if (assigned == null || assigned.isEmpty()) {
            String msg = "Assigned person cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }
        if (comment == null) {
            comment = ""; // Ensure comment is not null
        }

        // Check if the service is not operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            // Submit the transaction to update the ticket to in progress
            var result = fabricGatewayService.getContract().submitTransaction(
                    methodName,
                    ticketId,
                    assigned,
                    comment);

            // Convert the result to a pretty JSON format
            String prettyResult = JsonUtils.prettyJson(result);
            // Deserialize the JSON string to a TicketDto object
            TicketDto ticket = TicketDto.fromJson(prettyResult);

            log.info("*** Transaction committed successfully: " + ticket);
            // Return the updated ticket with status 200 OK
            return ResponseEntity.ok(ticket);

        } catch (Exception e) {
            // Handle exceptions
            return handleException(e, methodName);
        }
    }

    /**
     * Adds a comment to a ticket that is in progress.
     * The ticket must be in the IN_PROGRESS state for the comment to be added.
     * The method will update the last modified date of the ticket if the comment is
     * not empty.
     *
     * @param ticketId the ID of the ticket being updated
     * @param comment  the comment to be added to the ticket
     * @return the updated ticket
     */
    @PostMapping("/add-comment-to-ticket-in-progress")
    @Operation(summary = "Add comment to ticket in progress", description = "Adds a comment to a ticket that is in progress. The ticket must be in the IN_PROGRESS state for the comment to be added. The method will update the last modified date of the ticket if the comment is not empty.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully added comment to ticket", content = @Content(schema = @Schema(implementation = TicketDto.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    public ResponseEntity<?> addCommentToTicketInProgress(
            @Parameter(name = "ticketId", description = "ID of the ticket being updated") @RequestParam String ticketId,
            @Parameter(name = "comment", description = "The comment to be added to the ticket") @RequestParam String comment) {

        String methodName = "AddCommentForTicketInProgress";

        log.info("\n--> Submit Transaction: {} [adding comment to ticket in progress on the ledger]", methodName);

        // Validate input parameters
        if (ticketId == null || ticketId.isEmpty()) {
            String msg = "Ticket ID cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }
        if (comment == null || comment.trim().isEmpty()) {
            String msg = "Comment cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }

        // Check if the service is not operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            // Submit the transaction to add the comment to the ticket
            var result = fabricGatewayService.getContract().submitTransaction(
                    methodName,
                    ticketId,
                    comment);

            // Convert the result to a pretty JSON format
            String prettyResult = JsonUtils.prettyJson(result);
            // Deserialize the JSON string to a TicketDto object
            TicketDto ticket = TicketDto.fromJson(prettyResult);

            log.info("*** Transaction committed successfully: " + ticket);
            // Return the updated ticket with status 200 OK
            return ResponseEntity.ok(ticket);

        } catch (Exception e) {
            // Handle exceptions
            return handleException(e, methodName);
        }
    }

    /**
     * Updates the ticket status to indicate it has been resolved,
     * setting related product version and real story points.
     *
     * @param ticketId              the ID of the ticket being updated
     * @param relatedProductVersion the related product version
     * @param realStoryPoints       the actual story points
     * @param comment               an optional comment
     * @return the updated ticket
     */
    @PostMapping("/update-ticket-to-resolved")
    @Operation(summary = "Update ticket to Resolved", description = "Updates the ticket status to indicate it has been resolved, setting related product version and real story points")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully updated ticket to resolved", content = @Content(schema = @Schema(implementation = TicketDto.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    public ResponseEntity<?> updateTicketToResolved(
            @Parameter(name = "ticketId", description = "ID of the ticket being updated") @RequestParam String ticketId,
            @Parameter(name = "relatedProductVersion", description = "The related product version") @RequestParam String relatedProductVersion,
            @Parameter(name = "realStoryPoints", description = "The actual story points") @RequestParam int realStoryPoints,
            @Parameter(name = "comment", description = "An optional comment") @RequestParam(required = false) String comment) {

        String methodName = "UpdateTicketToResolved";

        log.info("\n--> Submit Transaction: {} [updating ticket to RESOLVED on the ledger]", methodName);

        // Validate input parameters
        if (ticketId == null || ticketId.isEmpty()) {
            String msg = "Ticket ID cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }
        if (relatedProductVersion == null || relatedProductVersion.isEmpty()) {
            String msg = "Related product version cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }
        if (realStoryPoints <= 0) {
            String msg = "Real story points must be a positive integer.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }
        if (comment == null) {
            comment = ""; // Ensure comment is not null
        }

        // Check if the service is not operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            // Submit the transaction to update the ticket to resolved
            var result = fabricGatewayService.getContract().submitTransaction(
                    methodName,
                    ticketId,
                    relatedProductVersion,
                    String.valueOf(realStoryPoints),
                    comment);

            // Convert the result to a pretty JSON format
            String prettyResult = JsonUtils.prettyJson(result);
            // Deserialize the JSON string to a TicketDto object
            TicketDto ticket = TicketDto.fromJson(prettyResult);

            log.info("*** Transaction committed successfully: " + ticket);
            // Return the updated ticket with status 200 OK
            return ResponseEntity.ok(ticket);

        } catch (Exception e) {
            // Handle exceptions
            return handleException(e, methodName);
        }
    }

    /**
     * Updates the ticket status to indicate it has been closed,
     * adding an optional comment.
     *
     * @param ticketId the ID of the ticket being updated
     * @param comment  an optional comment
     * @return the updated ticket
     */
    @PostMapping("/update-ticket-to-closed")
    @Operation(summary = "Update ticket to Closed", description = "Updates the ticket status to indicate it has been closed, adding an optional comment")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully updated ticket to closed", content = @Content(schema = @Schema(implementation = TicketDto.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    public ResponseEntity<?> updateTicketToClosed(
            @Parameter(name = "ticketId", description = "ID of the ticket being updated") @RequestParam String ticketId,
            @Parameter(name = "comment", description = "An optional comment") @RequestParam(required = false) String comment) {

        String methodName = "UpdateTicketToClosed";

        log.info("\n--> Submit Transaction: {} [updating ticket to CLOSED on the ledger]", methodName);

        // Validate input parameters
        if (ticketId == null || ticketId.isEmpty()) {
            String msg = "Ticket ID cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }
        if (comment == null) {
            comment = ""; // Ensure comment is not null
        }

        // Check if the service is not operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            // Submit the transaction to update the ticket to closed
            var result = fabricGatewayService.getContract().submitTransaction(
                    methodName,
                    ticketId,
                    comment);

            // Convert the result to a pretty JSON format
            String prettyResult = JsonUtils.prettyJson(result);
            // Deserialize the JSON string to a TicketDto object
            TicketDto ticket = TicketDto.fromJson(prettyResult);

            log.info("*** Transaction committed successfully: " + ticket);
            // Return the updated ticket with status 200 OK
            return ResponseEntity.ok(ticket);

        } catch (Exception e) {
            // Handle exceptions
            return handleException(e, methodName);
        }
    }

    /**
     * Deletes a ticket from the ledger.
     *
     * @param ticketId the ID of the ticket to be deleted
     * @return the timestamp of the deletion
     */
    @DeleteMapping("/delete-ticket")
    @Operation(summary = "Delete ticket", description = "Deletes a ticket from the ledger")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Ticket successfully deleted", content = @Content(schema = @Schema(implementation = String.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "404", description = "Ticket not found", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    public ResponseEntity<?> deleteTicket(
            @Parameter(name = "ticketId", description = "ID of the ticket to be deleted") @RequestParam String ticketId) {

        String methodName = "DeleteTicket";

        log.info("\n--> Submit Transaction: {} [deleting ticket from the ledger]", methodName);

        // Validate input parameters
        if (ticketId == null || ticketId.isEmpty()) {
            String msg = "Ticket ID cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }

        // Check if the service is not operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            // Submit the transaction to delete the ticket
            var result = fabricGatewayService.getContract().submitTransaction(
                    methodName,
                    ticketId);

            // Convert the result to a pretty JSON format
            String prettyResult = JsonUtils.prettyJson(result);

            log.info("*** Transaction committed successfully: " + prettyResult);
            // Return the timestamp of the deletion with status 200 OK
            return ResponseEntity.ok(prettyResult);

        } catch (Exception e) {
            // Handle exceptions
            return handleException(e, methodName);
        }
    }

    private ResponseEntity<?> handleException(Exception e, String methodName) {
        if (e instanceof EndorseException | e instanceof SubmitException | e instanceof CommitStatusException) {
            TransactionException te = (TransactionException) e;
            log.error("*** New Error submitting {} transaction", methodName);
            log.error("Error transaction ID: {}", te.getTransactionId());
            log.error("Error status code: {}", te.getStatus().getCode());
            var details = te.getDetails();
            if (!details.isEmpty()) {
                log.error("Error details:");
                for (var detail : details) {
                    log.error("- address: {}, mspId: {}, message: {}", detail.getAddress(), detail.getMspId(),
                            detail.getMessage());
                }
            } else {
                log.error("Error message: {}", te.getMessage());
            }
            return ResponseEntity.status(500)
                    .body("Error submitting " + methodName + " transaction: " + te.getMessage());
        } else if (e instanceof CommitException) {
            CommitException ce = (CommitException) e;
            log.error("*** New Error submitting {} transaction", methodName);
            log.error("Error transaction ID: {}", ce.getTransactionId());
            log.error("Error status code: {}", ce.getCode());
            log.error("Error message: {}", ce.getMessage());
            return ResponseEntity.status(500)
                    .body("Error submitting  " + methodName + " transaction: " + ce.getMessage());
            // e.printStackTrace(System.out);
        } else if (e instanceof IllegalArgumentException) {
            log.error("*** New Invalid argument provided for {}", methodName, e);
            return ResponseEntity.badRequest().body("Invalid argument: " + e.getMessage());
        } else {
            log.error("*** New Unexpected error occurred during {}", methodName, e);
            return ResponseEntity.status(500).body("Unexpected error occurred: " + e.getMessage());
        }
    }

}
