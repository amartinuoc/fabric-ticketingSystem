package uoc.tfm.app.controller;

import java.util.List;

import org.hyperledger.fabric.client.GatewayException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.media.ArraySchema;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.extern.slf4j.Slf4j;
import uoc.tfm.app.model.dto.TicketDto;
import uoc.tfm.app.model.dto.TicketStatus;
import uoc.tfm.app.service.FabricGatewayService;
import uoc.tfm.app.util.JsonUtils;

@Slf4j
@RestController
@RequestMapping("/api/v1/fabric/evaluate-transactions/")
@OpenAPIDefinition(info = @Info(title = "Ticketing System UOC TFM API", version = "1.0.0"))
@Tag(name = "Evaluate Transactions")
public class EvaluateTransactionsController {

    private final FabricGatewayService fabricGatewayService;

    public EvaluateTransactionsController(FabricGatewayService fabricGatewayService) {
        this.fabricGatewayService = fabricGatewayService;
    }

    /**
     * Retrieve a ticket from the ledger by its ID
     *
     * @param ticketId the ID of the ticket
     * @return the retrieved ticket
     */
    @Operation(summary = "Retrieve a ticket by its ID", description = "Retrieve a ticket from the ledger by its ID")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully retrieved ticket", content = @Content(schema = @Schema(implementation = TicketDto.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "404", description = "Ticket not found", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    @GetMapping(value = "ticket")
    public ResponseEntity<?> getTicketById(
            @Parameter(name = "ticketId", description = "ID of the ticket") @RequestParam String ticketId) {

        String methodName = "ReadTicket";

        log.info("\n--> Evaluate Transaction: {}] [returns the ticket for ticket ID {}]",
                methodName, ticketId);

        // Validate input parameters
        if (ticketId == null || ticketId.isEmpty()) {
            String msg = "Ticket ID cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }

        // Check if the service is no operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            var result = fabricGatewayService.getContract().evaluateTransaction(methodName, ticketId);
            String prettyResult = JsonUtils.prettyJson(result);
            log.info("*** Result: " + prettyResult);

            // Check if the response is empty
            if (prettyResult.isEmpty() || prettyResult.equals("[ ]") || prettyResult.equals("{ }")) {
                return ResponseEntity.status(404).body("Ticket not found.");
            }

            TicketDto ticketDto = TicketDto.fromJson(prettyResult);

            return ResponseEntity.ok(ticketDto);

        } catch (Exception e) {
            return handleException(e, methodName);
        }
    }

    /**
     * Retrieve all tickets from the ledger without applying any filtering
     *
     * @return the list of all tickets
     */
    @Operation(summary = "Retrieve all tickets", description = "Retrieve all tickets from the ledger without applying any filtering")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully retrieved tickets", content = @Content(array = @ArraySchema(schema = @Schema(implementation = TicketDto.class)))),
            @ApiResponse(responseCode = "204", description = "No tickets found", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    @GetMapping(value = "all-tickets")
    public ResponseEntity<?> getAllTickets() {

        String methodName = "GetAllTickets";

        log.info("\n--> Evaluate Transaction: {}] [returns all the current tickets on the ledger]", methodName);

        // Check if the service is no operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            var result = fabricGatewayService.getContract().evaluateTransaction(methodName);
            String prettyResult = JsonUtils.prettyJson(result);
            List<TicketDto> list = TicketDto.fromJsonList(prettyResult);
            log.info("*** Result: " + prettyResult);

            // Check if the response or list is empty
            if (prettyResult.isEmpty() || prettyResult.equals("[ ]") || list.isEmpty()) {
                return ResponseEntity.noContent().build();
            }

            return ResponseEntity.ok(list);

        } catch (Exception e) {
            return handleException(e, methodName);
        }
    }

    /**
     * Retrieve all tickets from the ledger filtered by project ID
     *
     * @return the list of tickets filtered by project ID
     */
    @Operation(summary = "Retrieve all tickets by project", description = "Retrieve all tickets from the ledger filtered by project ID")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully retrieved tickets", content = @Content(array = @ArraySchema(schema = @Schema(implementation = TicketDto.class)))),
            @ApiResponse(responseCode = "204", description = "No tickets found", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    @GetMapping(value = "tickets-by-project")
    public ResponseEntity<?> getAllTicketsByProject(
            @Parameter(name = "projectId", description = "ID of the project to which the ticket belongs") @RequestParam int projectId) {

        String methodName = "GetAllTicketsByProject";

        log.info("\n--> Evaluate Transaction: {}] [returns all the current tickets on the ledger for project ID {}]",
                methodName, projectId);

        // Check if the service is no operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            var result = fabricGatewayService.getContract().evaluateTransaction(methodName, String.valueOf(projectId));
            String prettyResult = JsonUtils.prettyJson(result);
            List<TicketDto> list = TicketDto.fromJsonList(prettyResult);
            log.info("*** Result : " + prettyResult);

            // Check if the response or list is empty
            if (prettyResult.isEmpty() || prettyResult.equals("[ ]") || list.isEmpty()) {
                return ResponseEntity.noContent().build();
            }

            return ResponseEntity.ok(list);

        } catch (Exception e) {
            return handleException(e, methodName);
        }
    }

    /**
     * Retrieve all tickets from the ledger filtered by status
     *
     * @return the list of tickets filtered by status
     */
    @Operation(summary = "Retrieve all tickets by status", description = "Retrieve all tickets from the ledger filtered by status")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully retrieved tickets", content = @Content(array = @ArraySchema(schema = @Schema(implementation = TicketDto.class)))),
            @ApiResponse(responseCode = "204", description = "No tickets found", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    @GetMapping(value = "tickets-by-status")
    public ResponseEntity<?> getAllTicketsByStatus(
            @Parameter(name = "status", description = "State the ticket is in") @RequestParam TicketStatus status) {

        String methodName = "GetAllTicketsByStatus";

        log.info("\n--> Evaluate Transaction: {} [returns all the current tickets on the ledger by status {}]",
                methodName, status.name());

        // Check if the service is no operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            var result = fabricGatewayService.getContract().evaluateTransaction(methodName, status.name());
            String prettyResult = JsonUtils.prettyJson(result);
            List<TicketDto> list = TicketDto.fromJsonList(prettyResult);
            log.info("*** Result : " + prettyResult);

            // Check if the response or list is empty
            if (prettyResult.isEmpty() || prettyResult.equals("[ ]") || list.isEmpty()) {
                return ResponseEntity.noContent().build();
            }

            return ResponseEntity.ok(list);

        } catch (Exception e) {
            return handleException(e, methodName);
        }
    }

    /**
     * Retrieve all tickets from the ledger filtered by the assigned user
     *
     * @return the list of tickets filtered by the assigned user
     */
    @Operation(summary = "Retrieve all tickets by assigned user", description = "Retrieve all tickets from the ledger filtered by the assigned user")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully retrieved tickets assigned to the specified user", content = @Content(array = @ArraySchema(schema = @Schema(implementation = TicketDto.class)))),
            @ApiResponse(responseCode = "204", description = "No tickets found assigned to the specified user", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "400", description = "Empty or invalid assigned user", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    @GetMapping(value = "tickets-by-assigned")
    public ResponseEntity<?> getAllTicketsByAssigned(
            @Parameter(name = "assigned", description = "Person assigned to the ticket to resolve it") @RequestParam String assigned) {

        String methodName = "GetAllTicketsByAssigned";

        log.info("\n--> Evaluate Transaction: {}] [returns all the current tickets on the ledger assigned to {}]",
                methodName, assigned);

        // Validate input parameters
        if (assigned == null || assigned.isEmpty()) {
            String msg = "Assigned user is empty or invalid.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }

        // Check if the service is no operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            var result = fabricGatewayService.getContract().evaluateTransaction(methodName, assigned);
            String prettyResult = JsonUtils.prettyJson(result);
            List<TicketDto> list = TicketDto.fromJsonList(prettyResult);
            log.info("*** Result : " + prettyResult);

            // Check if the response or list is empty
            if (prettyResult.isEmpty() || prettyResult.equals("[ ]") || list.isEmpty()) {
                return ResponseEntity.noContent().build();
            }

            return ResponseEntity.ok(list);

        } catch (Exception e) {
            return handleException(e, methodName);
        }
    }

    /**
     * Retrieve the transaction history for a specific ticket from the ledger
     *
     * @return the transaction history for the specified ticket
     */
    @Operation(summary = "Retrieve the transaction history for a specific ticket", description = "Retrieve the transaction history for a specific ticket from the ledger")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Successfully retrieved ticket history", content = @Content(schema = @Schema(implementation = String.class))),
            @ApiResponse(responseCode = "204", description = "No history found for the ticket", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "500", description = "Internal server error", content = @Content(schema = @Schema(implementation = Void.class))),
            @ApiResponse(responseCode = "503", description = "Service unavailable", content = @Content(schema = @Schema(implementation = Void.class)))
    })
    @GetMapping(value = "ticket-history")
    public ResponseEntity<?> getTicketHistory(
            @Parameter(name = "ticketId", description = "ID of the ticket") @RequestParam String ticketId) {

        String methodName = "GetTicketHistory";

        log.info("\n--> Evaluate Transaction: {}] [returns the transaction history for ticket ID {}]",
                methodName, ticketId);

        // Validate input parameters
        if (ticketId == null || ticketId.isEmpty()) {
            String msg = "Ticket ID cannot be empty.";
            log.warn("*** Result: " + msg);
            return ResponseEntity.badRequest().body(msg);
        }

        // Check if the service is no operative
        ResponseEntity<?> serviceNonOperative = fabricGatewayService.checkServiceNonOperative();
        if (serviceNonOperative != null) {
            return serviceNonOperative;
        }

        try {
            var result = fabricGatewayService.getContract().evaluateTransaction(methodName, ticketId);
            String prettyResult = JsonUtils.prettyJson(result);

            // Check if the response or list is empty
            if (prettyResult.isEmpty() || prettyResult.equals("[ ]") || prettyResult.equals("{ }")) {
                return ResponseEntity.noContent().build();
            }

            return ResponseEntity.ok(prettyResult);

        } catch (Exception e) {
            return handleException(e, methodName);
        }
    }

    private ResponseEntity<?> handleException(Exception e, String methodName) {
        if (e instanceof GatewayException) {
            GatewayException ge = (GatewayException) e;
            log.error("*** New Error evaluating {} transaction", methodName);
            log.error("Error status code: {}", ge.getStatus().getCode());
            var details = ge.getDetails();
            if (!details.isEmpty()) {
                log.error("Error details:");
                for (var detail : details) {
                    log.error("- address: {}, mspId: {}, message: {}", detail.getAddress(), detail.getMspId(),
                            detail.getMessage());
                }
            } else {
                log.error("Error message: {}", ge.getMessage());
            }
            return ResponseEntity.status(500)
                    .body("Error evaluating " + methodName + " transaction: " + ge.getMessage());
        } else if (e instanceof IllegalArgumentException) {
            log.error("*** New Invalid argument provided for {}", methodName, e);
            return ResponseEntity.badRequest().body("Invalid argument: " + e.getMessage());
        } else {
            log.error("*** New Unexpected error occurred during {}", methodName, e);
            return ResponseEntity.status(500).body("Unexpected error occurred: " + e.getMessage());
        }
    }

}
