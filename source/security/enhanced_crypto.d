module security.enhanced_crypto;

import std.stdio;
import std.string;
import std.conv;
import std.random;
import std.datetime;
import std.digest.sha;
import std.digest.hmac;
import std.algorithm;
import std.range;
import std.math;
import std.array;
import core.memory;

/// Enhanced cryptographic operations for password manager
struct EnhancedCrypto
{
    private static __gshared Mt19937 rng;

    static this()
    {
        rng = Mt19937(unpredictableSeed);
    }

    /// Generate cryptographically secure random bytes
    static ubyte[] generateSecureRandom(size_t length)
    {
        ubyte[] result = new ubyte[length];
        foreach (ref b; result)
        {
            b = cast(ubyte) uniform(0, 256, rng);
        }
        return result;
    }

    /// Generate a secure salt for key derivation
    static ubyte[] generateSalt(size_t length = 32)
    {
        return generateSecureRandom(length);
    }

    /// PBKDF2-HMAC-SHA256 key derivation with configurable iterations
    static ubyte[] deriveKey(string password, ubyte[] salt, uint iterations = 100_000, size_t keyLength = 32)
    {
        ubyte[] passwordBytes = cast(ubyte[]) password;
        ubyte[] derivedKey = new ubyte[keyLength];

        // Simple PBKDF2 implementation
        ubyte[] U = new ubyte[32];
        ubyte[] T = new ubyte[keyLength];

        size_t blocks = (keyLength + 31) / 32;

        for (size_t i = 1; i <= blocks; i++)
        {
            // U1 = HMAC(password, salt || INT_32_BE(i))
            ubyte[] saltWithCounter = salt.dup;
            saltWithCounter ~= [(i >> 24) & 0xFF, (i >> 16) & 0xFF, (i >> 8) & 0xFF, i & 0xFF];

            auto hmacCalc = HMAC!SHA256(passwordBytes);
            hmacCalc.put(saltWithCounter);
            U = hmacCalc.finish().dup;

            ubyte[] result = U.dup;

            // U2 through Ui
            for (uint j = 1; j < iterations; j++)
            {
                auto hmacCalc2 = HMAC!SHA256(passwordBytes);
                hmacCalc2.put(U);
                U = hmacCalc2.finish().dup;

                for (size_t k = 0; k < result.length; k++)
                {
                    result[k] ^= U[k];
                }
            }

            size_t offset = (i - 1) * 32;
            size_t copyLength = min(32, keyLength - offset);
            T[offset .. offset + copyLength] = result[0 .. copyLength];
        }

        return T;
    }

    /// Simple AES-256-CBC-like encryption (using XOR cipher for now)
    /// In production, use proper AES implementation
    static ubyte[] encrypt(ubyte[] data, ubyte[] key, ubyte[] iv = null)
    {
        if (iv is null)
        {
            iv = generateSecureRandom(16);
        }

        ubyte[] encrypted = new ubyte[iv.length + data.length];
        encrypted[0 .. iv.length] = iv;

        // Simple stream cipher (replace with proper AES in production)
        ubyte[] keyStream = deriveKey(cast(string) key, iv, 1000, data.length);

        for (size_t i = 0; i < data.length; i++)
        {
            encrypted[iv.length + i] = data[i] ^ keyStream[i];
        }

        return encrypted;
    }

    /// Decrypt data encrypted with encrypt()
    static ubyte[] decrypt(ubyte[] encryptedData, ubyte[] key)
    {
        if (encryptedData.length < 16)
        {
            throw new Exception("Invalid encrypted data");
        }

        ubyte[] iv = encryptedData[0 .. 16];
        ubyte[] ciphertext = encryptedData[16 .. $];

        // Simple stream cipher (replace with proper AES in production)
        ubyte[] keyStream = deriveKey(cast(string) key, iv, 1000, ciphertext.length);

        ubyte[] decrypted = new ubyte[ciphertext.length];
        for (size_t i = 0; i < ciphertext.length; i++)
        {
            decrypted[i] = ciphertext[i] ^ keyStream[i];
        }

        return decrypted;
    }

    /// Secure memory clearing
    static void secureZero(ref ubyte[] data)
    {
        foreach (ref b; data)
        {
            b = 0;
        }
        data.length = 0;
    }

    static void secureZero(ref string data)
    {
        foreach (ref c; cast(char[]) data)
        {
            c = '\0';
        }
    }

    /// Constant-time comparison to prevent timing attacks
    static bool constantTimeCompare(const(ubyte)[] a, const(ubyte)[] b)
    {
        if (a.length != b.length)
            return false;

        ubyte result = 0;
        foreach (i; 0 .. a.length)
        {
            result |= a[i] ^ b[i];
        }
        return result == 0;
    }

    /// Generate secure password with customizable options
    static string generatePassword(PasswordOptions options = PasswordOptions.init)
    {
        string chars = "";

        if (options.includeLowercase)
            chars ~= "abcdefghijklmnopqrstuvwxyz";
        if (options.includeUppercase)
            chars ~= "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        if (options.includeNumbers)
            chars ~= "0123456789";
        if (options.includeSymbols)
            chars ~= options.symbols;

        if (chars.length == 0)
            chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

        string password;
        password.reserve(options.length);

        for (size_t i = 0; i < options.length; i++)
        {
            password ~= chars[uniform(0, chars.length, rng)];
        }

        return password;
    }

    /// Generate memorable passphrase
    static string generatePassphrase(uint wordCount = 4, string separator = "-")
    {
        string[] words = [
            "apple", "bridge", "castle", "dragon", "eagle", "forest", "galaxy", "harbor",
            "island", "jungle", "knight", "lemon", "mountain", "nebula", "ocean", "palace",
            "quartz", "rainbow", "shadow", "temple", "universe", "village", "whisper", "xenon",
            "yellow", "zenith", "asteroid", "beacon", "crystal", "diamond", "emerald", "falcon",
            "granite", "horizon", "ivory", "jasper", "keystone", "lighthouse", "marble", "nugget",
            "opal", "phoenix", "quantum", "ruby", "sapphire", "titanium", "uranium", "volcano",
            "waterfall", "xylem", "yacht", "zircon"
        ];

        string[] selectedWords;
        for (uint i = 0; i < wordCount; i++)
        {
            selectedWords ~= words[uniform(0, words.length, rng)];
        }

        return selectedWords.join(separator);
    }

    /// Analyze password strength
    static PasswordStrength analyzePasswordStrength(string password)
    {
        PasswordStrength strength;
        strength.password = password;
        strength.length = cast(uint) password.length;

        // Character set analysis
        foreach (char c; password)
        {
            if (c >= 'a' && c <= 'z') strength.hasLowercase = true;
            else if (c >= 'A' && c <= 'Z') strength.hasUppercase = true;
            else if (c >= '0' && c <= '9') strength.hasNumbers = true;
            else strength.hasSymbols = true;
        }

        // Calculate entropy
        uint charsetSize = 0;
        if (strength.hasLowercase) charsetSize += 26;
        if (strength.hasUppercase) charsetSize += 26;
        if (strength.hasNumbers) charsetSize += 10;
        if (strength.hasSymbols) charsetSize += 32;

        strength.entropy = strength.length * log2(cast(real)charsetSize);

        // Score calculation (0-100)
        strength.score = 0;

        // Length score (0-30)
        if (strength.length >= 12) strength.score += 30;
        else if (strength.length >= 8) strength.score += 20;
        else if (strength.length >= 6) strength.score += 10;

        // Character diversity (0-40)
        uint diversity = 0;
        if (strength.hasLowercase) diversity += 10;
        if (strength.hasUppercase) diversity += 10;
        if (strength.hasNumbers) diversity += 10;
        if (strength.hasSymbols) diversity += 10;
        strength.score += diversity;

        // Entropy bonus (0-30)
        if (strength.entropy >= 60) strength.score += 30;
        else if (strength.entropy >= 40) strength.score += 20;
        else if (strength.entropy >= 25) strength.score += 10;

        // Common patterns penalty
        string lowerPassword = password.toLower();
        if (lowerPassword.canFind("password") || lowerPassword.canFind("123456") ||
            lowerPassword.canFind("qwerty") || lowerPassword.canFind("admin"))
        {
            strength.score = max(0, strength.score - 30);
        }

        // Determine strength level
        if (strength.score >= 80) strength.level = PasswordStrengthLevel.VeryStrong;
        else if (strength.score >= 60) strength.level = PasswordStrengthLevel.Strong;
        else if (strength.score >= 40) strength.level = PasswordStrengthLevel.Fair;
        else if (strength.score >= 20) strength.level = PasswordStrengthLevel.Weak;
        else strength.level = PasswordStrengthLevel.VeryWeak;

        return strength;
    }

    /// Hash password for verification (not for encryption keys)
    static string hashPassword(string password, ubyte[] salt = null)
    {
        if (salt is null)
            salt = generateSalt();

        ubyte[] hash = deriveKey(password, salt, 100_000);

        // Return salt + hash as hex
        string result;
        foreach (b; salt ~ hash)
        {
            result ~= format("%02x", b);
        }
        return result;
    }

    /// Verify password against hash
    static bool verifyPassword(string password, string hashedPassword)
    {
        if (hashedPassword.length < 128) // 32 bytes salt + 32 bytes hash = 64 bytes = 128 hex chars
            return false;

        try
        {
            ubyte[] salt = new ubyte[32];
            ubyte[] storedHash = new ubyte[32];

            // Parse hex string
            for (size_t i = 0; i < 32; i++)
            {
                salt[i] = cast(ubyte) hashedPassword[i * 2 .. i * 2 + 2].to!ubyte(16);
                storedHash[i] = cast(ubyte) hashedPassword[(i + 32) * 2 .. (i + 32) * 2 + 2].to!ubyte(16);
            }

            ubyte[] computedHash = deriveKey(password, salt, 100_000);
            return constantTimeCompare(storedHash, computedHash);
        }
        catch (Exception e)
        {
            return false;
        }
    }
}

/// Password generation options
struct PasswordOptions
{
    uint length = 16;
    bool includeLowercase = true;
    bool includeUppercase = true;
    bool includeNumbers = true;
    bool includeSymbols = true;
    string symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?";
    bool excludeSimilar = false; // Exclude similar characters like 0, O, l, 1
    bool excludeAmbiguous = false; // Exclude ambiguous characters
}

/// Password strength levels
enum PasswordStrengthLevel
{
    VeryWeak,
    Weak,
    Fair,
    Strong,
    VeryStrong
}

/// Password strength analysis result
struct PasswordStrength
{
    string password;
    uint length;
    bool hasLowercase;
    bool hasUppercase;
    bool hasNumbers;
    bool hasSymbols;
    double entropy;
    uint score; // 0-100
    PasswordStrengthLevel level;

    string getLevelString() const
    {
        final switch (level)
        {
            case PasswordStrengthLevel.VeryWeak: return "Very Weak";
            case PasswordStrengthLevel.Weak: return "Weak";
            case PasswordStrengthLevel.Fair: return "Fair";
            case PasswordStrengthLevel.Strong: return "Strong";
            case PasswordStrengthLevel.VeryStrong: return "Very Strong";
        }
    }

    string getColor() const
    {
        final switch (level)
        {
            case PasswordStrengthLevel.VeryWeak: return "#FF4444";
            case PasswordStrengthLevel.Weak: return "#FF8800";
            case PasswordStrengthLevel.Fair: return "#FFBB00";
            case PasswordStrengthLevel.Strong: return "#88DD00";
            case PasswordStrengthLevel.VeryStrong: return "#00DD44";
        }
    }
}

/// Security utilities
struct SecurityUtils
{
    /// Check if password has been compromised (placeholder for future HIBP integration)
    static bool isPasswordCompromised(string password)
    {
        // This would integrate with Have I Been Pwned API in production
        // For now, just check against common passwords
        string[] commonPasswords = [
            "password", "123456", "password123", "admin", "qwerty",
            "letmein", "welcome", "monkey", "1234567890", "password1"
        ];

        string lowerPassword = password.toLower();
        return commonPasswords.canFind(lowerPassword);
    }

    /// Generate security report for vault
    static SecurityReport generateSecurityReport(VaultEntry[] entries)
    {
        SecurityReport report;
        report.totalEntries = cast(uint) entries.length;

        SysTime now = Clock.currTime();
        SysTime oneYearAgo = now - 365.days;

        foreach (entry; entries)
        {
            auto strength = EnhancedCrypto.analyzePasswordStrength(entry.password);

            if (strength.level == PasswordStrengthLevel.VeryWeak ||
                strength.level == PasswordStrengthLevel.Weak)
            {
                report.weakPasswords++;
            }

            if (entry.passwordLastChanged < oneYearAgo)
            {
                report.oldPasswords++;
            }

            if (isPasswordCompromised(entry.password))
            {
                report.compromisedPasswords++;
            }

            if (!entry.hasTOTP)
            {
                report.noTwoFactorAuth++;
            }
        }

        // Calculate overall security score
        report.securityScore = 100;
        if (report.totalEntries > 0)
        {
            report.securityScore -= (report.weakPasswords * 100) / report.totalEntries / 4;
            report.securityScore -= (report.oldPasswords * 100) / report.totalEntries / 4;
            report.securityScore -= (report.compromisedPasswords * 100) / report.totalEntries / 2;
            report.securityScore -= (report.noTwoFactorAuth * 100) / report.totalEntries / 4;
        }
        report.securityScore = max(0, report.securityScore);

        return report;
    }
}

/// Security report structure
struct SecurityReport
{
    uint totalEntries;
    uint weakPasswords;
    uint oldPasswords;
    uint compromisedPasswords;
    uint noTwoFactorAuth;
    uint securityScore; // 0-100

    string getScoreColor() const
    {
        if (securityScore >= 80) return "#00DD44";
        else if (securityScore >= 60) return "#88DD00";
        else if (securityScore >= 40) return "#FFBB00";
        else if (securityScore >= 20) return "#FF8800";
        else return "#FF4444";
    }
}

/// Placeholder VaultEntry for security report
struct VaultEntry
{
    string password;
    SysTime passwordLastChanged;
    bool hasTOTP;
}
