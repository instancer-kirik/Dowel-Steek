module security.authenticator.totp;

import std.digest.sha;
import std.digest.hmac;
import std.datetime;
import std.conv;
import std.string;
import std.algorithm;
import std.range;
import std.base64;
import std.math;
import std.exception;
import std.json;
import std.uri;
import std.file;
import core.bitop;

/// Exception for TOTP operations
class TOTPException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// TOTP Algorithm type
enum TOTPAlgorithm
{
    SHA1,
    SHA256,
    SHA512
}

/// Base32 encoding/decoding for TOTP secrets
struct Base32
{
    private static immutable string BASE32_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    /// Decode base32 string to bytes
    static ubyte[] decode(string input)
    {
        if (input.length == 0)
            return [];

        // Remove padding and convert to uppercase
        string cleaned = input.toUpper().replace("=", "");

        if (cleaned.length == 0)
            return [];

        // Calculate output length
        size_t outputLength = (cleaned.length * 5) / 8;
        ubyte[] result = new ubyte[](outputLength);

        size_t bits = 0;
        uint buffer = 0;
        size_t index = 0;

        foreach (c; cleaned)
        {
            auto pos = BASE32_CHARS.indexOf(c);
            if (pos == -1)
                throw new TOTPException("Invalid base32 character: " ~ c);

            buffer = (buffer << 5) | cast(uint)pos;
            bits += 5;

            if (bits >= 8)
            {
                if (index < result.length)
                {
                    result[index++] = cast(ubyte)(buffer >> (bits - 8));
                    bits -= 8;
                }
            }
        }

        return result[0..index];
    }

    /// Encode bytes to base32 string
    static string encode(ubyte[] data)
    {
        if (data.length == 0)
            return "";

        char[] result;
        size_t bits = 0;
        uint buffer = 0;

        foreach (b; data)
        {
            buffer = (buffer << 8) | b;
            bits += 8;

            while (bits >= 5)
            {
                result ~= BASE32_CHARS[(buffer >> (bits - 5)) & 0x1F];
                bits -= 5;
            }
        }

        if (bits > 0)
        {
            result ~= BASE32_CHARS[(buffer << (5 - bits)) & 0x1F];
        }

        // Add padding
        while (result.length % 8 != 0)
        {
            result ~= '=';
        }

        return cast(string)result;
    }
}

/// TOTP code generator
struct TOTPGenerator
{
    private string _secret;
    private TOTPAlgorithm _algorithm;
    private int _digits;
    private int _period;

    this(string secret, TOTPAlgorithm algorithm = TOTPAlgorithm.SHA1, int digits = 6, int period = 30)
    {
        if (secret.length == 0)
            throw new TOTPException("Secret cannot be empty");

        if (digits < 4 || digits > 10)
            throw new TOTPException("Digits must be between 4 and 10");

        if (period <= 0)
            throw new TOTPException("Period must be positive");

        _secret = secret;
        _algorithm = algorithm;
        _digits = digits;
        _period = period;
    }

    /// Generate TOTP code for current time
    string generateCode()
    {
        return generateCodeAtTime(Clock.currTime().toUnixTime());
    }

    /// Generate TOTP code for specific timestamp
    string generateCodeAtTime(long timestamp)
    {
        long timeStep = timestamp / _period;
        return generateCodeForTimeStep(timeStep);
    }

    /// Generate TOTP code for specific time step
    string generateCodeForTimeStep(long timeStep)
    {
        // Convert secret from base32
        ubyte[] secretBytes = Base32.decode(_secret);

        // Convert time step to 8-byte big-endian
        ubyte[8] timeBytes;
        for (int i = 7; i >= 0; i--)
        {
            timeBytes[i] = cast(ubyte)(timeStep & 0xFF);
            timeStep >>= 8;
        }

        // Calculate HMAC
        ubyte[] hash = calculateHMAC(secretBytes, timeBytes);

        // Dynamic truncation
        uint code = dynamicTruncate(hash);

        // Format code with leading zeros
        uint modulo = cast(uint)pow(10, _digits);
        code %= modulo;

        return format("%0*d", _digits, code);
    }

    /// Validate TOTP code with time window tolerance
    bool validateCode(string code, int windowSize = 1)
    {
        long currentTime = Clock.currTime().toUnixTime();
        long currentTimeStep = currentTime / _period;

        // Check current time step and adjacent windows
        for (int i = -windowSize; i <= windowSize; i++)
        {
            string expectedCode = generateCodeForTimeStep(currentTimeStep + i);
            if (constantTimeEquals(code, expectedCode))
                return true;
        }

        return false;
    }

    /// Get remaining seconds until next code
    int getRemainingSeconds()
    {
        long currentTime = Clock.currTime().toUnixTime();
        return cast(int)(_period - (currentTime % _period));
    }

    /// Get progress percentage (0.0 to 1.0) until next code
    double getProgress()
    {
        long currentTime = Clock.currTime().toUnixTime();
        long elapsed = currentTime % _period;
        return cast(double)elapsed / _period;
    }

    private ubyte[] calculateHMAC(ubyte[] key, ubyte[8] data)
    {
        final switch (_algorithm)
        {
            case TOTPAlgorithm.SHA1:
                auto hmac = HMAC!SHA1(key);
                hmac.put(data);
                return hmac.finish().dup;

            case TOTPAlgorithm.SHA256:
                auto hmac = HMAC!SHA256(key);
                hmac.put(data);
                return hmac.finish().dup;

            case TOTPAlgorithm.SHA512:
                auto hmac = HMAC!SHA512(key);
                hmac.put(data);
                return hmac.finish().dup;
        }
    }

    private uint dynamicTruncate(ubyte[] hash)
    {
        // Get offset from last 4 bits of hash
        int offset = hash[$-1] & 0x0F;

        // Extract 4 bytes starting at offset
        uint code = (cast(uint)hash[offset] << 24) |
                   (cast(uint)hash[offset + 1] << 16) |
                   (cast(uint)hash[offset + 2] << 8) |
                   cast(uint)hash[offset + 3];

        // Clear most significant bit
        code &= 0x7FFFFFFF;

        return code;
    }

    private bool constantTimeEquals(string a, string b)
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
}

/// TOTP account information
struct TOTPAccount
{
    string id;
    string issuer;
    string accountName;
    string secret;
    TOTPAlgorithm algorithm;
    int digits;
    int period;
    string iconUrl;
    string[] tags;
    bool favorite;
    SysTime createdAt;
    SysTime lastUsed;
    int usageCount;

    this(string issuer, string accountName, string secret)
    {
        import std.uuid;

        this.id = randomUUID().toString();
        this.issuer = issuer;
        this.accountName = accountName;
        this.secret = secret;
        this.algorithm = TOTPAlgorithm.SHA1;
        this.digits = 6;
        this.period = 30;
        this.createdAt = Clock.currTime();
        this.usageCount = 0;
        this.favorite = false;
    }

    /// Generate current TOTP code
    string generateCode()
    {
        auto generator = TOTPGenerator(secret, algorithm, digits, period);
        lastUsed = Clock.currTime();
        usageCount++;
        return generator.generateCode();
    }

    /// Validate TOTP code
    bool validateCode(string code, int windowSize = 1)
    {
        auto generator = TOTPGenerator(secret, algorithm, digits, period);
        return generator.validateCode(code, windowSize);
    }

    /// Get remaining seconds until next code
    int getRemainingSeconds()
    {
        auto generator = TOTPGenerator(secret, algorithm, digits, period);
        return generator.getRemainingSeconds();
    }

    /// Get progress until next code
    double getProgress()
    {
        auto generator = TOTPGenerator(secret, algorithm, digits, period);
        return generator.getProgress();
    }

    /// Convert to JSON
    JSONValue toJSON() const
    {
        JSONValue json = JSONValue.emptyObject;
        json["id"] = JSONValue(id);
        json["issuer"] = JSONValue(issuer);
        json["accountName"] = JSONValue(accountName);
        json["secret"] = JSONValue(secret);
        json["algorithm"] = JSONValue(algorithmToString(algorithm));
        json["digits"] = JSONValue(digits);
        json["period"] = JSONValue(period);
        json["iconUrl"] = JSONValue(iconUrl);
        json["favorite"] = JSONValue(favorite);
        json["createdAt"] = JSONValue(createdAt.toISOExtString());
        json["lastUsed"] = JSONValue(lastUsed.toISOExtString());
        json["usageCount"] = JSONValue(usageCount);

        JSONValue[] tagArray;
        foreach (tag; tags)
            tagArray ~= JSONValue(tag);
        json["tags"] = JSONValue(tagArray);

        return json;
    }

    /// Create from JSON
    static TOTPAccount fromJSON(JSONValue json)
    {
        TOTPAccount account;

        if ("id" in json) account.id = json["id"].str;
        if ("issuer" in json) account.issuer = json["issuer"].str;
        if ("accountName" in json) account.accountName = json["accountName"].str;
        if ("secret" in json) account.secret = json["secret"].str;
        if ("algorithm" in json) account.algorithm = algorithmFromString(json["algorithm"].str);
        if ("digits" in json) account.digits = cast(int)json["digits"].integer;
        if ("period" in json) account.period = cast(int)json["period"].integer;
        if ("iconUrl" in json) account.iconUrl = json["iconUrl"].str;
        if ("favorite" in json) account.favorite = json["favorite"].boolean;
        if ("usageCount" in json) account.usageCount = cast(int)json["usageCount"].integer;

        if ("createdAt" in json)
            account.createdAt = SysTime.fromISOExtString(json["createdAt"].str);
        if ("lastUsed" in json)
            account.lastUsed = SysTime.fromISOExtString(json["lastUsed"].str);

        if ("tags" in json && json["tags"].type == JSONType.array)
        {
            foreach (tagJson; json["tags"].array)
                account.tags ~= tagJson.str;
        }

        return account;
    }

    /// Parse from otpauth:// URL
    static TOTPAccount fromOtpAuthUrl(string url)
    {
        if (!url.startsWith("otpauth://totp/"))
            throw new TOTPException("Invalid TOTP URL format");

        // Remove protocol
        string path = url["otpauth://totp/".length..$];

        // Split path and query
        auto queryStart = path.indexOf('?');
        string accountPart = queryStart == -1 ? path : path[0..queryStart];

        // Decode account part
        accountPart = decodeComponent(accountPart);

        TOTPAccount account;

        // Parse issuer and account name
        auto colonPos = accountPart.indexOf(':');
        if (colonPos != -1)
        {
            account.issuer = accountPart[0..colonPos];
            account.accountName = accountPart[colonPos+1..$];
        }
        else
        {
            account.accountName = accountPart;
        }

        // Set defaults
        account.algorithm = TOTPAlgorithm.SHA1;
        account.digits = 6;
        account.period = 30;

        // Parse query parameters
        if (queryStart != -1)
        {
            string query = path[queryStart+1..$];
            auto params = query.split("&");

            foreach (param; params)
            {
                auto parts = param.split("=");
                if (parts.length == 2)
                {
                    string key = decodeComponent(parts[0]);
                    string value = decodeComponent(parts[1]);

                    switch (key)
                    {
                        case "secret":
                            account.secret = value;
                            break;
                        case "issuer":
                            account.issuer = value;
                            break;
                        case "digits":
                            account.digits = value.to!int;
                            break;
                        case "period":
                            account.period = value.to!int;
                            break;
                        case "algorithm":
                            account.algorithm = algorithmFromString(value);
                            break;
                        case "image":
                            account.iconUrl = value;
                            break;
                        default:
                            break;
                    }
                }
            }
        }

        if (account.secret.length == 0)
            throw new TOTPException("Missing secret in TOTP URL");

        // Generate ID and set creation time
        import std.uuid;
        account.id = randomUUID().toString();
        account.createdAt = Clock.currTime();

        return account;
    }

    /// Generate otpauth:// URL
    string toOtpAuthUrl() const
    {
        string url = "otpauth://totp/";

        if (issuer.length > 0)
            url ~= encodeComponent(issuer ~ ":" ~ accountName);
        else
            url ~= encodeComponent(accountName);

        url ~= "?secret=" ~ encodeComponent(secret);

        if (issuer.length > 0)
            url ~= "&issuer=" ~ encodeComponent(issuer);

        if (digits != 6)
            url ~= "&digits=" ~ digits.to!string;

        if (period != 30)
            url ~= "&period=" ~ period.to!string;

        if (algorithm != TOTPAlgorithm.SHA1)
            url ~= "&algorithm=" ~ algorithmToString(algorithm);

        if (iconUrl.length > 0)
            url ~= "&image=" ~ encodeComponent(iconUrl);

        return url;
    }

    /// Check if account matches search query
    bool matchesSearch(string query) const
    {
        string lowerQuery = query.toLower();
        return issuer.toLower().canFind(lowerQuery) ||
               accountName.toLower().canFind(lowerQuery) ||
               tags.any!(tag => tag.toLower().canFind(lowerQuery));
    }
}

/// Convert algorithm enum to string
private string algorithmToString(TOTPAlgorithm algorithm)
{
    final switch (algorithm)
    {
        case TOTPAlgorithm.SHA1: return "SHA1";
        case TOTPAlgorithm.SHA256: return "SHA256";
        case TOTPAlgorithm.SHA512: return "SHA512";
    }
}

/// Convert string to algorithm enum
private TOTPAlgorithm algorithmFromString(string str)
{
    switch (str.toUpper())
    {
        case "SHA1": return TOTPAlgorithm.SHA1;
        case "SHA256": return TOTPAlgorithm.SHA256;
        case "SHA512": return TOTPAlgorithm.SHA512;
        default: return TOTPAlgorithm.SHA1;
    }
}

/// TOTP authenticator manager
class TOTPAuthenticator
{
    private TOTPAccount[string] _accounts;
    private string _filePath;
    private string _password;
    private bool _isLocked = true;

    this(string filePath)
    {
        _filePath = filePath;
    }

    /// Check if authenticator is locked
    @property bool isLocked() const
    {
        return _isLocked;
    }

    /// Get number of accounts
    @property size_t accountCount() const
    {
        return _accounts.length;
    }

    /// Get all issuers
    @property string[] issuers() const
    {
        bool[string] issuerSet;
        foreach (account; _accounts.values)
        {
            if (account.issuer.length > 0)
                issuerSet[account.issuer] = true;
        }
        return issuerSet.keys.sort.array;
    }

    /// Unlock authenticator
    bool unlock(string password)
    {
        try
        {
            if (exists(_filePath))
            {
                loadFromFile(password);
            }

            _password = password;
            _isLocked = false;
            return true;
        }
        catch (Exception e)
        {
            _isLocked = true;
            return false;
        }
    }

    /// Lock the authenticator
    void lock()
    {
        save();
        _isLocked = true;
        _password = null;

        // Clear secrets from memory
        foreach (ref account; _accounts.values)
        {
            import security.crypto : CryptoUtils;
            CryptoUtils.secureErase(cast(ubyte[])account.secret);
        }
    }

    /// Add new account
    string addAccount(TOTPAccount account)
    {
        if (_isLocked)
            throw new TOTPException("Authenticator is locked");

        if (account.id.length == 0)
        {
            import std.uuid;
            account.id = randomUUID().toString();
        }

        _accounts[account.id] = account;
        save();

        return account.id;
    }

    /// Add account from otpauth URL
    string addAccountFromUrl(string otpAuthUrl)
    {
        auto account = TOTPAccount.fromOtpAuthUrl(otpAuthUrl);
        return addAccount(account);
    }

    /// Remove account
    bool removeAccount(string id)
    {
        if (_isLocked)
            throw new TOTPException("Authenticator is locked");

        if (id !in _accounts)
            return false;

        // Secure erase secret
        import security.crypto : CryptoUtils;
        CryptoUtils.secureErase(cast(ubyte[])_accounts[id].secret);

        _accounts.remove(id);
        save();

        return true;
    }

    /// Get account by ID
    TOTPAccount* getAccount(string id)
    {
        if (_isLocked)
            throw new TOTPException("Authenticator is locked");

        if (id !in _accounts)
            return null;

        return &_accounts[id];
    }

    /// Get all accounts
    TOTPAccount[] getAllAccounts()
    {
        if (_isLocked)
            throw new TOTPException("Authenticator is locked");

        return _accounts.values.sort!((a, b) => a.issuer < b.issuer ||
                                              (a.issuer == b.issuer && a.accountName < b.accountName)).array;
    }

    /// Search accounts
    TOTPAccount[] searchAccounts(string query)
    {
        if (_isLocked)
            throw new TOTPException("Authenticator is locked");

        TOTPAccount[] results;
        foreach (account; _accounts.values)
        {
            if (account.matchesSearch(query))
                results ~= account;
        }

        return results.sort!((a, b) => a.issuer < b.issuer).array;
    }

    /// Get favorite accounts
    TOTPAccount[] getFavoriteAccounts()
    {
        if (_isLocked)
            throw new TOTPException("Authenticator is locked");

        TOTPAccount[] results;
        foreach (account; _accounts.values)
        {
            if (account.favorite)
                results ~= account;
        }

        return results.sort!((a, b) => a.lastUsed > b.lastUsed).array;
    }

    /// Export to JSON (for backup)
    JSONValue exportToJSON() const
    {
        if (_isLocked)
            throw new TOTPException("Authenticator is locked");

        JSONValue json = JSONValue.emptyObject;
        json["version"] = JSONValue(1);
        json["exportTime"] = JSONValue(Clock.currTime().toISOExtString());

        JSONValue[] accountsJson;
        foreach (account; _accounts.values)
            accountsJson ~= account.toJSON();

        json["accounts"] = JSONValue(accountsJson);

        return json;
    }

    /// Import from JSON (for restore)
    void importFromJSON(JSONValue json)
    {
        if (_isLocked)
            throw new TOTPException("Authenticator is locked");

        if ("accounts" in json && json["accounts"].type == JSONType.array)
        {
            foreach (accountJson; json["accounts"].array)
            {
                auto account = TOTPAccount.fromJSON(accountJson);
                _accounts[account.id] = account;
            }
        }

        save();
    }

    /// Save to file
    void save()
    {
        if (_isLocked)
            throw new TOTPException("Authenticator is locked");

        saveToFile();
    }

    private void loadFromFile(string password)
    {
        import security.crypto : SimpleEncryption;
        import std.file : read, exists;

        if (!exists(_filePath))
            return;

        ubyte[] encryptedData = cast(ubyte[]) read(_filePath);
        ubyte[] decryptedData = SimpleEncryption.decrypt(encryptedData, password);

        string jsonStr = cast(string) decryptedData;
        JSONValue json = parseJSON(jsonStr);

        if ("accounts" in json && json["accounts"].type == JSONType.array)
        {
            _accounts.clear();
            foreach (accountJson; json["accounts"].array)
            {
                auto account = TOTPAccount.fromJSON(accountJson);
                _accounts[account.id] = account;
            }
        }
    }

    private void saveToFile()
    {
        import security.crypto : SimpleEncryption;
        import std.file : write, exists, remove, rename, mkdirRecurse;
        import std.path : dirName;

        JSONValue json = exportToJSON();
        string jsonStr = json.toString();

        ubyte[] encryptedData = SimpleEncryption.encrypt(cast(ubyte[]) jsonStr, _password);

        // Ensure directory exists
        string dir = dirName(_filePath);
        if (!exists(dir))
            mkdirRecurse(dir);

        // Atomic write with backup
        string tempPath = _filePath ~ ".tmp";
        string backupPath = _filePath ~ ".bak";

        write(tempPath, encryptedData);

        if (exists(_filePath))
        {
            if (exists(backupPath))
                remove(backupPath);
            rename(_filePath, backupPath);
        }

        rename(tempPath, _filePath);
    }
}
