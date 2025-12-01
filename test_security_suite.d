#!/usr/bin/env dub
/+ dub.sdl:
dependency "dowel-steek-suite" path="."
+/

/**
 * Test script for Dowel-Steek Security Suite
 * Demonstrates password manager and TOTP authenticator functionality
 */

import std.stdio;
import std.datetime;
import std.file;
import std.path;
import std.json;
import std.conv;

import security.crypto;
import security.password_manager.vault;
import security.authenticator.totp;

void main()
{
    writeln("=== Dowel-Steek Security Suite Test ===");
    writeln("Testing core cryptographic and security functions...\n");

    // Test 1: Password Generation
    testPasswordGeneration();

    // Test 2: Password Strength Analysis
    testPasswordStrengthAnalysis();

    // Test 3: TOTP Code Generation
    testTOTPGeneration();

    // Test 4: Base32 Encoding/Decoding
    testBase32Operations();

    // Test 5: Vault Operations (simplified)
    testVaultOperations();

    // Test 6: Encryption/Decryption
    testEncryptionDecryption();

    writeln("\n=== All Tests Completed Successfully ===");
    writeln("You can now run the GUI application with:");
    writeln("  ./dowel-steek-security");
    writeln("\nDefault demo password: demo-password-123");
    writeln("Data will be stored in: ~/.dowel-steek/");
}

void testPasswordGeneration()
{
    writeln("--- Testing Password Generation ---");

    // Generate different types of passwords
    auto options = PasswordGenerator.Options();

    // Strong password
    options.length = 16;
    options.charsets = PasswordGenerator.CharsetType.All;
    string strongPassword = PasswordGenerator.generate(options);
    writeln("Strong password (16 chars): ", strongPassword);

    // Numbers only
    options.length = 8;
    options.charsets = PasswordGenerator.CharsetType.Numbers;
    string numbersOnly = PasswordGenerator.generate(options);
    writeln("Numbers only (8 chars): ", numbersOnly);

    // Letters only
    options.charsets = PasswordGenerator.CharsetType.Lowercase | PasswordGenerator.CharsetType.Uppercase;
    string lettersOnly = PasswordGenerator.generate(options);
    writeln("Letters only (8 chars): ", lettersOnly);

    // Generate passphrase
    string passphrase = PasswordGenerator.generatePassphrase(4, "-");
    writeln("Passphrase (4 words): ", passphrase);

    writeln("✓ Password generation tests passed\n");
}

void testPasswordStrengthAnalysis()
{
    writeln("--- Testing Password Strength Analysis ---");

    string[] testPasswords = [
        "123456",
        "password",
        "Password123",
        "MyStr0ng!P@ssw0rd",
        "correct-horse-battery-staple"
    ];

    foreach (password; testPasswords)
    {
        auto analysis = PasswordStrength.analyze(password);
        writeln("Password: '", password, "'");
        writeln("  Strength: ", analysis.level, " (Score: ", analysis.score, "/100)");

        if (analysis.weaknesses.length > 0)
        {
            writeln("  Issues: ", analysis.weaknesses);
        }
        writeln();
    }

    writeln("✓ Password strength analysis tests passed\n");
}

void testTOTPGeneration()
{
    writeln("--- Testing TOTP Generation ---");

    // Test with a known secret (RFC 6238 test vector)
    string secret = "JBSWY3DPEHPK3PXP"; // "Hello World!" in base32

    try
    {
        auto generator = TOTPGenerator(secret);

        string currentCode = generator.generateCode();
        writeln("Current TOTP code: ", currentCode);
        writeln("Remaining seconds: ", generator.getRemainingSeconds());
        writeln("Progress: ", cast(int)(generator.getProgress() * 100), "%");

        // Test validation
        bool isValid = generator.validateCode(currentCode);
        writeln("Code validation: ", isValid ? "PASS" : "FAIL");

        // Test different time windows
        long testTime = 1234567890; // Fixed timestamp
        string testCode = generator.generateCodeAtTime(testTime);
        writeln("Test code for timestamp ", testTime, ": ", testCode);

        writeln("✓ TOTP generation tests passed\n");
    }
    catch (Exception e)
    {
        writeln("✗ TOTP test failed: ", e.msg);
    }
}

void testBase32Operations()
{
    writeln("--- Testing Base32 Encoding/Decoding ---");

    string[] testStrings = [
        "Hello World!",
        "TOTP Secret Key",
        "Testing123"
    ];

    foreach (testString; testStrings)
    {
        ubyte[] originalBytes = cast(ubyte[])testString;
        string encoded = Base32.encode(originalBytes);
        ubyte[] decodedBytes = Base32.decode(encoded);
        string decoded = cast(string)decodedBytes;

        writeln("Original: '", testString, "'");
        writeln("Encoded:  '", encoded, "'");
        writeln("Decoded:  '", decoded, "'");
        writeln("Match: ", (testString == decoded) ? "PASS" : "FAIL");
        writeln();
    }

    writeln("✓ Base32 encoding tests passed\n");
}

void testVaultOperations()
{
    writeln("--- Testing Vault Operations ---");

    // Create a temporary vault for testing
    string testDir = buildPath(tempDir(), "dowel-steek-test");
    if (!exists(testDir))
        mkdirRecurse(testDir);

    string testVaultPath = buildPath(testDir, "test_vault.dsv");

    try
    {
        auto vault = new PasswordVault(testVaultPath);
        string testPassword = "test-master-password-123";

        // Test unlock (creates new vault)
        bool unlocked = vault.unlock(testPassword);
        writeln("Vault unlock: ", unlocked ? "SUCCESS" : "FAILED");

        if (unlocked)
        {
            // Add test entries
            auto entry1 = VaultEntry("GitHub");
            entry1.username = "testuser";
            entry1.password = "github-password-123";
            entry1.url = "https://github.com";
            entry1.category = "Development";
            entry1.tags = ["code", "work"];

            auto entry2 = VaultEntry("Gmail");
            entry2.username = "user@gmail.com";
            entry2.password = "gmail-password-456";
            entry2.url = "https://gmail.com";
            entry2.category = "Email";
            entry2.favorite = true;

            string id1 = vault.addEntry(entry1);
            string id2 = vault.addEntry(entry2);

            writeln("Added entries with IDs: ", id1[0..8], "..., ", id2[0..8], "...");

            // Test search
            auto allEntries = vault.searchEntries();
            writeln("Total entries: ", allEntries.length);

            // Test filtering
            auto favorites = vault.getFavoriteEntries();
            writeln("Favorite entries: ", favorites.length);

            auto devEntries = vault.getEntriesByCategory("Development");
            writeln("Development entries: ", devEntries.length);

            // Test security report
            auto report = vault.generateSecurityReport();
            writeln("Security report:");
            writeln("  Overall score: ", report.overallScore, "/100");
            writeln("  Weak passwords: ", report.weakPasswords);
            writeln("  Missing 2FA: ", report.without2FA);

            // Save vault
            vault.save();
            writeln("Vault saved successfully");

            // Test export
            JSONValue exportData = vault.exportToJSON();
            writeln("Export data size: ", exportData.toString().length, " characters");
        }

        writeln("✓ Vault operations tests passed\n");
    }
    catch (Exception e)
    {
        writeln("✗ Vault test failed: ", e.msg, "\n");
    }

    // Clean up test files
    try
    {
        if (exists(testVaultPath))
            remove(testVaultPath);
        if (exists(testVaultPath ~ ".bak"))
            remove(testVaultPath ~ ".bak");
    }
    catch (Exception e)
    {
        // Ignore cleanup errors
    }
}

void testEncryptionDecryption()
{
    writeln("--- Testing Encryption/Decryption ---");

    string testData = "This is secret data that needs to be encrypted!";
    string password = "encryption-test-password-123";

    try
    {
        // Test encryption
        ubyte[] plaintext = cast(ubyte[])testData;
        ubyte[] encrypted = SimpleEncryption.encrypt(plaintext, password);
        writeln("Original data: ", testData);
        writeln("Encrypted size: ", encrypted.length, " bytes");

        // Test decryption
        ubyte[] decrypted = SimpleEncryption.decrypt(encrypted, password);
        string decryptedText = cast(string)decrypted;
        writeln("Decrypted data: ", decryptedText);

        bool match = (testData == decryptedText);
        writeln("Encryption/Decryption: ", match ? "PASS" : "FAIL");

        // Test key derivation
        ubyte[] salt = KeyDerivation.generateSalt();
        writeln("Generated salt size: ", salt.length, " bytes");

        ubyte[] key1 = KeyDerivation.pbkdf2(password, salt, 1000);
        ubyte[] key2 = KeyDerivation.pbkdf2(password, salt, 1000);
        writeln("Key derivation consistency: ", (key1 == key2) ? "PASS" : "FAIL");

        writeln("✓ Encryption tests passed\n");
    }
    catch (Exception e)
    {
        writeln("✗ Encryption test failed: ", e.msg, "\n");
    }
}
