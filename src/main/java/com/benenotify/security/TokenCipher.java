package com.benenotify.security;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

public final class TokenCipher {

    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final int IV_LENGTH = 12;
    private static final int TAG_BITS = 128;
    private static final SecureRandom RANDOM = new SecureRandom();

    private TokenCipher() {
    }

    public static byte[] encrypt(String plainText, String base64Key) throws Exception {
        byte[] iv = new byte[IV_LENGTH];
        RANDOM.nextBytes(iv);
        Cipher cipher = Cipher.getInstance(ALGORITHM);
        cipher.init(Cipher.ENCRYPT_MODE, key(base64Key), new GCMParameterSpec(TAG_BITS, iv));
        byte[] cipherText = cipher.doFinal(plainText.getBytes(StandardCharsets.UTF_8));
        return ByteBuffer.allocate(iv.length + cipherText.length).put(iv).put(cipherText).array();
    }

    public static String decrypt(byte[] payload, String base64Key) throws Exception {
        ByteBuffer buffer = ByteBuffer.wrap(payload);
        byte[] iv = new byte[IV_LENGTH];
        buffer.get(iv);
        byte[] cipherText = new byte[buffer.remaining()];
        buffer.get(cipherText);
        Cipher cipher = Cipher.getInstance(ALGORITHM);
        cipher.init(Cipher.DECRYPT_MODE, key(base64Key), new GCMParameterSpec(TAG_BITS, iv));
        return new String(cipher.doFinal(cipherText), StandardCharsets.UTF_8);
    }

    private static SecretKeySpec key(String base64Key) {
        byte[] raw = Base64.getDecoder().decode(base64Key);
        if (raw.length != 32) {
            throw new IllegalArgumentException("TOKEN_ENCRYPTION_KEY deve ter 32 bytes codificados em Base64");
        }
        return new SecretKeySpec(raw, "AES");
    }
}
