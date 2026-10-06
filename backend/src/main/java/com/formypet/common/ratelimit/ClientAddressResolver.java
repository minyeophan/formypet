package com.formypet.common.ratelimit;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.Inet6Address;
import java.net.InetAddress;

/** Uses Railway's edge-provided X-Real-IP only when the service is publicly hosted there. */
@Component
public class ClientAddressResolver {
    private final boolean railwayPublicIngress;

    public ClientAddressResolver(@Value("${RAILWAY_PUBLIC_DOMAIN:}") String railwayPublicDomain) {
        this.railwayPublicIngress = railwayPublicDomain != null && !railwayPublicDomain.isBlank();
    }

    public String resolve(HttpServletRequest request) {
        String remoteAddress = request.getRemoteAddr();
        if (!railwayPublicIngress) return remoteAddress;

        String railwayAddress = request.getHeader("X-Real-IP");
        if (isValidAddress(railwayAddress)) return railwayAddress.trim();
        return remoteAddress;
    }

    private boolean isValidAddress(String value) {
        if (value == null) return false;
        String address = value.trim();
        if (address.isEmpty() || address.length() > 45) return false;

        if (address.matches("[0-9.]+")) {
            String[] octets = address.split("\\.", -1);
            if (octets.length != 4) return false;
            for (String octet : octets) {
                if (octet.isEmpty() || octet.length() > 3) return false;
                try {
                    if (Integer.parseInt(octet) > 255) return false;
                } catch (NumberFormatException invalidOctet) {
                    return false;
                }
            }
            return true;
        }

        if (!address.contains(":") || !address.matches("[0-9A-Fa-f:.]+")) return false;
        try {
            return InetAddress.getByName(address) instanceof Inet6Address;
        } catch (java.net.UnknownHostException invalidAddress) {
            return false;
        }
    }
}
