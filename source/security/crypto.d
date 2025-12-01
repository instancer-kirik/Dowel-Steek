module security.crypto;

import std.digest.sha;
import std.digest.hmac;
import std.random;
import std.conv;
import std.string;
import std.base64;
import std.algorithm;
import std.range;
import std.datetime;
import std.file;
import std.path;
import std.json;
import std.exception;
import core.stdc.string : memset;

/// Exception for cryptographic operations
class CryptoException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Secure random number generation
struct SecureRandom
{
    private static Random rng;

    static this()
    {
        rng = Random(unpredictableSeed);
    }

    /// Generate random bytes
    static ubyte[] bytes(size_t length)
    {
        ubyte[] result = new ubyte[](length);
        foreach (ref b; result)
        {
            b = cast(ubyte) uniform(0, 256, rng);
        }
        return result;
    }

    /// Generate random string with specified charset
    static string randomString(size_t length, string charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    {
        char[] result = new char[](length);
        foreach (ref c; result)
        {
            c = charset[uniform(0, charset.length, rng)];
        }
        return cast(string) result;
    }
}

/// Key derivation using PBKDF2-HMAC-SHA256
struct KeyDerivation
{
    /// Derive key from password using PBKDF2
    static ubyte[] pbkdf2(string password, ubyte[] salt, uint iterations = 100000, size_t keyLength = 32)
    {
        if (salt.length < 16)
            throw new CryptoException("Salt must be at least 16 bytes");

        if (iterations < 10000)
            throw new CryptoException("Iterations must be at least 10000");

        ubyte[] key = new ubyte[](keyLength);
        ubyte[] passwordBytes = cast(ubyte[]) password;

        // Simple PBKDF2 implementation
        ubyte[] block = new ubyte[](32); // SHA256 output size

        for (uint i = 1; i * 32 <= keyLength; i++)
        {
            // Initial iteration
            auto hmac = HMAC!SHA256(passwordBytes);
            hmac.put(salt);
            hmac.put(cast(ubyte[]) [
                cast(ubyte)(i >> 24),
                cast(ubyte)(i >> 16),
                cast(ubyte)(i >> 8),
                cast(ubyte)(i)
            ]);
            ubyte[] u = hmac.finish().dup;
            block[] = u[];

            // Remaining iterations
            for (uint j = 1; j < iterations; j++)
            {
                hmac = HMAC!SHA256(passwordBytes);
                hmac.put(u);
                u = hmac.finish().dup;

                foreach (k; 0..block.length)
                    block[k] ^= u[k];
            }

            // Copy to output
            size_t start = (i - 1) * 32;
            size_t end = min(start + 32, keyLength);
            key[start..end] = block[0..(end-start)];
        }

        return key;
    }

    /// Generate salt
    static ubyte[] generateSalt(size_t length = 32)
    {
        return SecureRandom.bytes(length);
    }
}

/// Simple AES-like encryption (XOR with derived key stream)
/// NOTE: This is a simplified implementation for demonstration
/// In production, use a proper AES library like OpenSSL
struct SimpleEncryption
{
    /// Encrypt data with password
    static ubyte[] encrypt(ubyte[] data, string password)
    {
        ubyte[] salt = KeyDerivation.generateSalt();
        ubyte[] key = KeyDerivation.pbkdf2(password, salt);
        ubyte[] nonce = SecureRandom.bytes(16);

        // Simple stream cipher using key
        ubyte[] encrypted = new ubyte[](data.length);
        ubyte[] keystream = generateKeystream(key, nonce, data.length);

        foreach (i; 0..data.length)
        {
            encrypted[i] = data[i] ^ keystream[i];
        }

        // Combine salt + nonce + encrypted data
        ubyte[] result = salt ~ nonce ~ encrypted;
        return result;
    }

    /// Decrypt data with password
    static ubyte[] decrypt(ubyte[] encryptedData, string password)
    {
        if (encryptedData.length < 48) // salt(32) + nonce(16)
            throw new CryptoException("Invalid encrypted data format");

        ubyte[] salt = encryptedData[0..32];
        ubyte[] nonce = encryptedData[32..48];
        ubyte[] encrypted = encryptedData[48..$];

        ubyte[] key = KeyDerivation.pbkdf2(password, salt);
        ubyte[] keystream = generateKeystream(key, nonce, encrypted.length);

        ubyte[] decrypted = new ubyte[](encrypted.length);
        foreach (i; 0..encrypted.length)
        {
            decrypted[i] = encrypted[i] ^ keystream[i];
        }

        return decrypted;
    }

    private static ubyte[] generateKeystream(ubyte[] key, ubyte[] nonce, size_t length)
    {
        ubyte[] keystream = new ubyte[](length);

        for (size_t i = 0; i < length; i += 32)
        {
            auto hmac = HMAC!SHA256(key);
            hmac.put(nonce);
            hmac.put(cast(ubyte[]) [
                cast(ubyte)(i >> 24),
                cast(ubyte)(i >> 16),
                cast(ubyte)(i >> 8),
                cast(ubyte)(i)
            ]);
            ubyte[] block = hmac.finish().dup;

            size_t copyLen = min(32, length - i);
            keystream[i..i+copyLen] = block[0..copyLen];
        }

        return keystream;
    }
}

/// Secure string operations
struct SecureString
{
    private ubyte[] _data;
    private bool _cleared = false;

    this(string str)
    {
        _data = cast(ubyte[]) str.dup;
    }

    this(ubyte[] data)
    {
        _data = data.dup;
    }

    ~this()
    {
        clear();
    }

    /// Get the string value (use carefully)
    @property string value()
    {
        if (_cleared)
            throw new CryptoException("SecureString has been cleared");
        return cast(string) _data;
    }

    /// Get raw data
    @property ubyte[] data()
    {
        if (_cleared)
            throw new CryptoException("SecureString has been cleared");
        return _data;
    }

    /// Clear the string from memory
    void clear()
    {
        if (!_cleared && _data.length > 0)
        {
            memset(_data.ptr, 0, _data.length);
            _cleared = true;
        }
    }

    /// Check if string is cleared
    @property bool cleared() const
    {
        return _cleared;
    }
}

/// Password strength checker
struct PasswordStrength
{
    enum Level
    {
        VeryWeak,
        Weak,
        Fair,
        Good,
        Strong,
        VeryStrong
    }

    struct Analysis
    {
        Level level;
        int score;
        string[] weaknesses;
        string[] suggestions;
    }

    static Analysis analyze(string password)
    {
        Analysis result;
        result.score = 0;

        // Length check
        if (password.length >= 12)
            result.score += 25;
        else if (password.length >= 8)
            result.score += 10;
        else
            result.weaknesses ~= "Password is too short";

        // Character variety
        bool hasLower = false, hasUpper = false, hasDigit = false, hasSpecial = false;

        foreach (c; password)
        {
            if (c >= 'a' && c <= 'z') hasLower = true;
            else if (c >= 'A' && c <= 'Z') hasUpper = true;
            else if (c >= '0' && c <= '9') hasDigit = true;
            else hasSpecial = true;
        }

        if (hasLower) result.score += 10;
        else result.weaknesses ~= "Missing lowercase letters";

        if (hasUpper) result.score += 10;
        else result.weaknesses ~= "Missing uppercase letters";

        if (hasDigit) result.score += 10;
        else result.weaknesses ~= "Missing numbers";

        if (hasSpecial) result.score += 15;
        else result.weaknesses ~= "Missing special characters";

        // Common patterns check
        string lower = password.toLower();
        if (lower.canFind("password") || lower.canFind("123456") || lower.canFind("qwerty"))
        {
            result.score -= 20;
            result.weaknesses ~= "Contains common patterns";
        }

        // Repetition check
        if (hasRepeatedChars(password))
        {
            result.score -= 10;
            result.weaknesses ~= "Contains repeated characters";
        }

        // Determine level
        if (result.score < 30) result.level = Level.VeryWeak;
        else if (result.score < 50) result.level = Level.Weak;
        else if (result.score < 70) result.level = Level.Fair;
        else if (result.score < 85) result.level = Level.Good;
        else if (result.score < 95) result.level = Level.Strong;
        else result.level = Level.VeryStrong;

        // Generate suggestions
        if (result.weaknesses.length > 0)
        {
            result.suggestions ~= "Use at least 12 characters";
            result.suggestions ~= "Mix uppercase, lowercase, numbers and symbols";
            result.suggestions ~= "Avoid common words and patterns";
            result.suggestions ~= "Use a unique password for each account";
        }

        return result;
    }

    private static bool hasRepeatedChars(string password)
    {
        int consecutiveCount = 1;
        char lastChar = 0;

        foreach (c; password)
        {
            if (c == lastChar)
            {
                consecutiveCount++;
                if (consecutiveCount >= 3)
                    return true;
            }
            else
            {
                consecutiveCount = 1;
                lastChar = c;
            }
        }

        return false;
    }
}

/// Password generation
struct PasswordGenerator
{
    enum CharsetType
    {
        Lowercase = 1,
        Uppercase = 2,
        Numbers = 4,
        Symbols = 8,
        All = 15
    }

    struct Options
    {
        size_t length = 16;
        CharsetType charsets = CharsetType.All;
        bool excludeSimilar = true; // Exclude 0, O, l, I, etc.
        bool excludeAmbiguous = true; // Exclude {}[]()\/|`~
    }

    static string generate(Options options = Options.init)
    {
        string charset = "";

        if (options.charsets & CharsetType.Lowercase)
        {
            charset ~= options.excludeSimilar ? "abcdefghijkmnopqrstuvwxyz" : "abcdefghijklmnopqrstuvwxyz";
        }

        if (options.charsets & CharsetType.Uppercase)
        {
            charset ~= options.excludeSimilar ? "ABCDEFGHJKLMNPQRSTUVWXYZ" : "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        }

        if (options.charsets & CharsetType.Numbers)
        {
            charset ~= options.excludeSimilar ? "23456789" : "0123456789";
        }

        if (options.charsets & CharsetType.Symbols)
        {
            string symbols = options.excludeAmbiguous ? "!@#$%^&*-_=+;:,.<>?" : "!@#$%^&*()_-+={}[]|\\:;\"'<>,.?/~`";
            charset ~= symbols;
        }

        if (charset.length == 0)
            throw new CryptoException("No character sets selected for password generation");

        return SecureRandom.randomString(options.length, charset);
    }

    /// Generate memorable passphrase
    static string generatePassphrase(size_t wordCount = 4, string separator = "-")
    {
        // Simple word list for demonstration
        string[] words = [
            "apple", "bridge", "clock", "dance", "eagle", "forest", "guitar", "house",
            "island", "jungle", "kitten", "light", "mountain", "nature", "ocean", "piano",
            "queen", "river", "sunset", "tiger", "umbrella", "village", "water", "yellow"
        ];

        string[] selectedWords = new string[](wordCount);
        foreach (i; 0..wordCount)
        {
            selectedWords[i] = words[uniform(0, words.length, SecureRandom.rng)];
        }

        return selectedWords.join(separator);
    }
}

/// Utility functions
struct CryptoUtils
{
    /// Constant-time string comparison
    static bool constantTimeEquals(string a, string b)
    {
        if (a.length != b.length)
            return false;

        ubyte result = 0;
        foreach (i; 0..a.length)
        {
            result |= cast(ubyte)(a[i] ^ b[i]);
        }

        return result == 0;
    }

    /// Secure erase of memory
    static void secureErase(ubyte[] data)
    {
        if (data.length > 0)
            memset(data.ptr, 0, data.length);
    }

    /// Convert bytes to hex string
    static string toHex(ubyte[] data)
    {
        char[] result = new char[](data.length * 2);
        foreach (i, b; data)
        {
            result[i * 2] = "0123456789abcdef"[b >> 4];
            result[i * 2 + 1] = "0123456789abcdef"[b & 0xF];
        }
        return cast(string) result;
    }

    /// Convert hex string to bytes
    static ubyte[] fromHex(string hex)
    {
        if (hex.length % 2 != 0)
            throw new CryptoException("Invalid hex string length");

        ubyte[] result = new ubyte[](hex.length / 2);
        foreach (i; 0..result.length)
        {
            string byteStr = hex[i * 2..i * 2 + 2];
            result[i] = cast(ubyte) byteStr.to!int(16);
        }
        return result;
    }
}
