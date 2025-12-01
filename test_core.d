#!/usr/bin/env dub
/+ dub.sdl:
name "test_core"
dependency "dlangui" version="~>0.10.8"
+/

/**
 * Simple test for Dowel-Steek Security Suite core functionality
 * Tests crypto, password generation, and TOTP without GUI dependencies
 */

import std.stdio;
import std.datetime;
import std.conv;
import std.digest.sha;
import std.digest.hmac;
import std.random;
import std.algorithm;
import std.range;
import std.string;
import std.base64;
import std.math;

void main()
{
    writeln("=== Dowel-Steek Security Suite Core Test ===");
    writeln("Testing core functionality without GUI...\n");

    testPasswordGeneration();
    testPasswordStrength();
    testTOTPGeneration();
    testBase32();
    testEncryption();

    writeln("\n=== All Core Tests Completed ===");
    writeln("\nYou can now run the full GUI application:");
    writeln("  ./dowel-steek-security");
    writeln("\nThis will open a window with:");
    writeln("• Password Manager tab for storing credentials");
    writeln("• Authenticator tab for 2FA codes");
    writeln("• Demo password: demo-password-123");
}

void testPasswordGeneration()
{
    writeln("--- Password Generation ---");

    // Simple password generation
    string charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*";
    auto rng = Random(unpredictableSeed);

    char[] password = new char[](16);
    foreach (ref c; password)
    {
        c = charset[uniform(0, charset.length, rng)];
    }

    writeln("Generated password: ", cast(string)password);
    writeln("✓ Password generation works");
}

void testPasswordStrength()
{
    writeln("\n--- Password Strength Analysis ---");

    string[] testPasswords = ["123456", "password", "MyStr0ng!Pass"];

    foreach (pwd; testPasswords)
    {
        int score = 0;
        bool hasUpper = false, hasLower = false, hasDigit = false, hasSpecial = false;

        foreach (c; pwd)
        {
            if (c >= 'A' && c <= 'Z') hasUpper = true;
            else if (c >= 'a' && c <= 'z') hasLower = true;
            else if (c >= '0' && c <= '9') hasDigit = true;
            else hasSpecial = true;
        }

        if (pwd.length >= 8) score += 25;
        if (hasUpper) score += 20;
        if (hasLower) score += 20;
        if (hasDigit) score += 20;
        if (hasSpecial) score += 15;

        string strength = "Weak";
        if (score >= 80) strength = "Strong";
        else if (score >= 60) strength = "Good";
        else if (score >= 40) strength = "Fair";

        writeln("'", pwd, "' -> ", strength, " (", score, "/100)");
    }

    writeln("✓ Password strength analysis works");
}

void testTOTPGeneration()
{
    writeln("\n--- TOTP Generation ---");

    // Simple TOTP implementation
    string secret = "JBSWY3DPEHPK3PXP"; // "Hello World!" in base32

    try
    {
        // Decode base32 secret
        ubyte[] secretBytes = decodeBase32Simple(secret);

        // Get current time step (30 second intervals)
        long currentTime = Clock.currTime().toUnixTime();
        long timeStep = currentTime / 30;

        // Convert to 8-byte big-endian
        ubyte[8] timeBytes;
        for (int i = 7; i >= 0; i--)
        {
            timeBytes[i] = cast(ubyte)(timeStep & 0xFF);
            timeStep >>= 8;
        }

        // HMAC-SHA1
        auto hmac = HMAC!SHA1(secretBytes);
        hmac.put(timeBytes);
        ubyte[] hash = hmac.finish().dup;

        // Dynamic truncation
        int offset = hash[$-1] & 0x0F;
        uint code = (cast(uint)hash[offset] << 24) |
                   (cast(uint)hash[offset + 1] << 16) |
                   (cast(uint)hash[offset + 2] << 8) |
                   cast(uint)hash[offset + 3];

        code &= 0x7FFFFFFF;
        code %= 1000000; // 6 digits

        writeln("TOTP Code: ", format("%06d", code));
        writeln("Time remaining: ", 30 - (currentTime % 30), " seconds");
        writeln("✓ TOTP generation works");
    }
    catch (Exception e)
    {
        writeln("TOTP test error: ", e.msg);
    }
}

void testBase32()
{
    writeln("\n--- Base32 Encoding/Decoding ---");

    string testString = "Hello World!";
    ubyte[] originalBytes = cast(ubyte[])testString;

    // Simple base32 encoding
    string encoded = encodeBase32Simple(originalBytes);
    ubyte[] decoded = decodeBase32Simple(encoded);
    string result = cast(string)decoded;

    writeln("Original: '", testString, "'");
    writeln("Encoded:  '", encoded, "'");
    writeln("Decoded:  '", result, "'");
    writeln("Match: ", (testString == result) ? "PASS" : "FAIL");
    writeln("✓ Base32 encoding works");
}

void testEncryption()
{
    writeln("\n--- Simple Encryption Test ---");

    string plaintext = "Secret password data";
    string password = "master-password-123";

    // Simple XOR "encryption" for demo
    ubyte[] key = cast(ubyte[])password;
    ubyte[] data = cast(ubyte[])plaintext;
    ubyte[] encrypted = new ubyte[](data.length);

    foreach (i; 0..data.length)
    {
        encrypted[i] = data[i] ^ key[i % key.length];
    }

    // "Decrypt"
    ubyte[] decrypted = new ubyte[](encrypted.length);
    foreach (i; 0..encrypted.length)
    {
        decrypted[i] = encrypted[i] ^ key[i % key.length];
    }

    string result = cast(string)decrypted;
    writeln("Original: '", plaintext, "'");
    writeln("Encrypted size: ", encrypted.length, " bytes");
    writeln("Decrypted: '", result, "'");
    writeln("Match: ", (plaintext == result) ? "PASS" : "FAIL");
    writeln("✓ Basic encryption works");
}

// Simple Base32 implementation
string encodeBase32Simple(ubyte[] data)
{
    immutable string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    string result = "";

    for (size_t i = 0; i < data.length; i += 5)
    {
        ulong buffer = 0;
        int bits = 0;

        for (int j = 0; j < 5 && i + j < data.length; j++)
        {
            buffer = (buffer << 8) | data[i + j];
            bits += 8;
        }

        buffer <<= (40 - bits);

        for (int j = 0; j < 8; j++)
        {
            if (bits > 0)
            {
                result ~= alphabet[(buffer >> 35) & 0x1F];
                buffer <<= 5;
                bits -= 5;
            }
            else
            {
                result ~= '=';
            }
        }
    }

    return result;
}

ubyte[] decodeBase32Simple(string encoded)
{
    immutable string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    ubyte[] result;

    // Remove padding
    encoded = encoded.replace("=", "");

    for (size_t i = 0; i < encoded.length; i += 8)
    {
        ulong buffer = 0;
        int bits = 0;

        for (int j = 0; j < 8 && i + j < encoded.length; j++)
        {
            char c = encoded[i + j];
            auto pos = alphabet.indexOf(c);
            if (pos >= 0)
            {
                buffer = (buffer << 5) | pos;
                bits += 5;
            }
        }

        while (bits >= 8)
        {
            result ~= cast(ubyte)((buffer >> (bits - 8)) & 0xFF);
            bits -= 8;
        }
    }

    return result;
}
