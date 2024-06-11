package uoc.tfm.app.service;

import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.http.ResponseEntity;

import lombok.extern.slf4j.Slf4j;
import uoc.tfm.app.util.NetworkUtils;
import io.grpc.Grpc;
import io.grpc.ManagedChannel;
import io.grpc.TlsChannelCredentials;

import org.hyperledger.fabric.client.CommitException;
import org.hyperledger.fabric.client.CommitStatusException;
import org.hyperledger.fabric.client.Contract;
import org.hyperledger.fabric.client.EndorseException;
import org.hyperledger.fabric.client.Gateway;
import org.hyperledger.fabric.client.SubmitException;
import org.hyperledger.fabric.client.identity.Identities;
import org.hyperledger.fabric.client.identity.Identity;
import org.hyperledger.fabric.client.identity.Signer;
import org.hyperledger.fabric.client.identity.Signers;
import org.hyperledger.fabric.client.identity.X509Identity;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.InvalidKeyException;
import java.security.cert.CertificateException;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

@Slf4j
@Service
public class FabricGatewayService {

    @Value("${fabric.connection.retry.time}")
    private int retryTime;

    @Value("${fabric.msp.id}")
    private String mspId;

    @Value("${fabric.channel.name}")
    private String channelName;

    @Value("${fabric.chaincode.name}")
    private String chaincodeName;

    @Value("${fabric.crypto.path:}")
    private String cryptoPath;

    @Value("${fabric.peer.endpoint}")
    private String peerEndpoint;

    @Value("${fabric.override.auth}")
    private String overrideAuth;

    @Value("${fabric.init.Ledger}")
    private boolean isInitLedger;

    private ManagedChannel channel;
    private Gateway gateway;
    private Contract contract;

    @Autowired
    private ResourceLoader resourceLoader;

    private ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    private AtomicBoolean isConnecting = new AtomicBoolean(false);

    @PostConstruct
    public void init() {
        try {
            Resource resourceCryptoDir = resourceLoader.getResource("classpath:" + cryptoPath);

            if (!resourceCryptoDir.exists()) {
                log.error("Error initializing FabricGatewayService: '{}' is non-existent",
                        resourceCryptoDir.toString());
                log.warn("FabricGatewayService is finish!");
                return;
            }

            Path cryptoDir = Paths.get(resourceCryptoDir.getURI());
            Path certDirPath = cryptoDir.resolve("users/User1@orgclient.uoctfm.com/msp/signcerts");
            Path keyDirPath = cryptoDir.resolve("users/User1@orgclient.uoctfm.com/msp/keystore");
            Path tlsCertPath = cryptoDir.resolve("peers/peer0.orgclient.uoctfm.com/tls/ca.crt");

            log.debug("Crypto directory path: {}", cryptoDir);
            log.debug("Certificate directory path: {}", certDirPath);
            log.debug("Key directory path: {}", keyDirPath);
            log.debug("TLS certificate path: {}", tlsCertPath);

            connectGateway(certDirPath, keyDirPath, tlsCertPath);

        } catch (Exception e) {
            log.error("Error initializing FabricGatewayService", e);
            log.warn("FabricGatewayService is finish!");
            cleanup();
        }
    }

    private void connectGateway(Path certDirPath, Path keyDirPath, Path tlsCertPath) {
        if (isConnecting.get()) {
            return;
        }
        isConnecting.set(true);

        scheduler.scheduleWithFixedDelay(() -> {
            try {

                if (!NetworkUtils.isEndpointAccessible(peerEndpoint)) {
                    log.error("Error initializing FabricGatewayService: peer '{}' is non-accesible", peerEndpoint);
                    log.warn("FabricGatewayService is not initied! Continue trying in {} sec ...", retryTime);
                } else {
                    channel = newGrpcConnection(tlsCertPath);
                    Gateway.Builder builder = Gateway.newInstance()
                            .identity(newIdentity(certDirPath))
                            .signer(newSigner(keyDirPath))
                            .connection(channel)
                            .evaluateOptions(options -> options.withDeadlineAfter(5, TimeUnit.SECONDS))
                            .endorseOptions(options -> options.withDeadlineAfter(15, TimeUnit.SECONDS))
                            .submitOptions(options -> options.withDeadlineAfter(5, TimeUnit.SECONDS))
                            .commitStatusOptions(options -> options.withDeadlineAfter(1, TimeUnit.MINUTES));

                    gateway = builder.connect();

                    if (gateway != null) {
                        log.info("##### FabricGatewayService is working #####");

                        var network = gateway.getNetwork(channelName);
                        contract = network.getContract(chaincodeName);

                        log.debug("Gateway - Channel : {}", network.getName());
                        log.debug("Gateway - Identity: {} ({})", mspId, gateway.getIdentity());
                        log.debug("Gateway - Peer Endpoint: {}", peerEndpoint);
                        log.debug("Gateway - OverrideAuth: {}", overrideAuth);
                        log.debug("Gateway - Chaincode Name: {}", contract.getChaincodeName());

                        if (isInitLedger)
                            initLedger();

                        isConnecting.set(false);
                        scheduler.shutdown();
                        log.debug("Scheduler to retry FabricGatewayService connections is now shutdown!");

                    } else {
                        log.error("Gateway object is null.");
                        log.warn("FabricGatewayService is not initied! Continue trying in {} sec ...", retryTime);
                    }
                }

            } catch (Exception e) {
                log.error("Error connecting FabricGatewayService", e);
                log.warn("FabricGatewayService is not initied! Continue trying in {} sec ...", retryTime);
                cleanup();
            }

        }, 0, retryTime, TimeUnit.SECONDS);
    }

    @PreDestroy
    public void cleanup() {
        try {
            if (channel != null) {
                channel.shutdownNow().awaitTermination(5, TimeUnit.SECONDS);
            }
            if (gateway != null) {
                gateway.close();
            }
        } catch (InterruptedException e) {
            log.error("Error during FabricGatewayService cleanup", e);
        }
    }

    private ManagedChannel newGrpcConnection(Path tlsCertPath) throws IOException {
        try (InputStream tlsCertStream = Files.newInputStream(tlsCertPath)) {
            var credentials = TlsChannelCredentials.newBuilder()
                    .trustManager(tlsCertStream)
                    .build();
            return Grpc.newChannelBuilder(peerEndpoint, credentials)
                    .overrideAuthority(overrideAuth)
                    .build();
        }
    }

    private Identity newIdentity(Path certDirPath) throws IOException, CertificateException {
        try (var certReader = Files.newBufferedReader(getFirstFilePath(certDirPath))) {
            var certificate = Identities.readX509Certificate(certReader);
            return new X509Identity(mspId, certificate);
        }
    }

    private Signer newSigner(Path keyDirPath) throws IOException, InvalidKeyException {
        try (var keyReader = Files.newBufferedReader(getFirstFilePath(keyDirPath))) {
            var privateKey = Identities.readPrivateKey(keyReader);
            return Signers.newPrivateKeySigner(privateKey);
        }
    }

    private Path getFirstFilePath(Path dirPath) throws IOException {
        try (var keyFiles = Files.list(dirPath)) {
            return keyFiles.findFirst().orElseThrow();
        }
    }

    /**
     * This type of transaction would typically only be run once by an application
     * the first time it was started after its initial deployment.
     */
    private void initLedger() {

        String name = "InitLedger";
        log.info("\n--> Submit Transaction: {} [creates the initial set of tickets on the ledger]", name);

        try {
            contract.submitTransaction(name);
            log.info("*** Transaction committed successfully");

        } catch (EndorseException | SubmitException | CommitStatusException e) {
            log.error("*** New Error submitting {} transaction", name);
            log.error("Error transaction ID: {}", e.getTransactionId());
            log.error("Error status code: {}", e.getStatus().getCode());
            var details = e.getDetails();
            if (!details.isEmpty()) {
                log.error("Error details:");
                for (var detail : details) {
                    log.error("- address: {}, mspId: {}, message: {}", detail.getAddress(), detail.getMspId(),
                            detail.getMessage());
                }
            } else {
                log.error("Error message: {}", e.getMessage());
            }
            // e.printStackTrace(System.out);
        } catch (CommitException e) {
            log.error("*** New Error submitting {} transaction", name);
            log.error("Error transaction ID: {}", e.getTransactionId());
            log.error("Error status code: {}", e.getCode());
            log.error("Error message: {}", e.getMessage());
            // e.printStackTrace(System.out);
        }
    }

    public Gateway getGateway() {
        return gateway;
    }

    public String getChannelName() {
        return channelName;
    }

    public String getChaincodeName() {
        return chaincodeName;
    }

    public Contract getContract() {
        return contract;
    }

    public boolean isOperative() {
        return gateway != null && contract != null;
    }

    public ResponseEntity<?> checkServiceNonOperative() {
        if (!this.isOperative()) {
            log.error("FabricGatewayService is not operative.");
            return ResponseEntity.status(503).body("FabricGatewayService is not operative.");
        }
        return null;
    }

}
