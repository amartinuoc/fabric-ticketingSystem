package uoc.tfm.app.util;

import java.net.InetSocketAddress;
import java.net.Socket;
public class NetworkUtils {

    public static boolean isEndpointAccessible(String endpointUrl) {
        String[] parts = endpointUrl.split(":");
        String host = parts[0];
        int port = Integer.parseInt(parts[1]);
        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress(host, port), 1000); // Timeout de 1 segundo
            return true;
        } catch (Exception e) {
            return false;
        }
    }

}
