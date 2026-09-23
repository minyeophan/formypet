package com.formypet.auth.recovery;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;

@Component
@RequiredArgsConstructor
public class RecoveryCrypto {
    private final RecoveryProperties properties;
    private final SecureRandom random=new SecureRandom();
    public String id(){byte[] bytes=new byte[32];random.nextBytes(bytes);return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);}
    public String code(){return String.format(Locale.ROOT,"%06d",random.nextInt(1_000_000));}
    public String digest(String purpose,String value){return HexFormat.of().formatHex(hmac(properties.getHmacSecret(),purpose+"\0"+value));}
    public String token(String id,String requestId){
        return Base64.getUrlEncoder().withoutPadding().encodeToString(hmac(properties.getTokenSecret(),"reset\0"+id+"\0"+requestId));
    }
    public static String hash(String value){
        try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));}
        catch(NoSuchAlgorithmException e){throw new IllegalStateException(e);}
    }
    public static boolean same(String a,String b){
        return a!=null&&b!=null&&MessageDigest.isEqual(a.getBytes(StandardCharsets.UTF_8),b.getBytes(StandardCharsets.UTF_8));
    }
    private byte[] hmac(String key,String value){
        try{var mac=Mac.getInstance("HmacSHA256");mac.init(new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8),"HmacSHA256"));
            return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));}
        catch(GeneralSecurityException e){throw new IllegalStateException("Recovery cryptography unavailable",e);}
    }
}
