module security.password_manager.vault;

import std.json;
import std.file;
import std.path;
import std.datetime;
import std.conv;
import std.string;
import std.algorithm;
import std.array;
import std.uuid;
import std.exception;
import security.crypto;

/// Represents a password entry in the vault
struct VaultEntry
{
    string id;
    string title;
    string username;
    string email;
    string password;
    string url;
    string notes;
    string[] tags;
    string category;
    bool favorite;
    SysTime createdAt;
    SysTime modifiedAt;
    SysTime lastUsed;
    int usageCount;

    /// Additional custom fields
    string[string] customFields;

    /// TOTP settings if this entry has 2FA
    TOTPSettings totpSettings;

    this(string title, string username = "", string password = "")
    {
        this.id = randomUUID().toString();
        this.title = title;
        this.username = username;
        this.password = password;
        this.createdAt = Clock.currTime();
        this.modifiedAt = this.createdAt;
        this.usageCount = 0;
        this.favorite = false;
    }

    /// Convert to JSON for storage
    JSONValue toJSON() const
    {
        JSONValue json = JSONValue.emptyObject;
        json["id"] = JSONValue(id);
        json["title"] = JSONValue(title);
        json["username"] = JSONValue(username);
        json["email"] = JSONValue(email);
        json["password"] = JSONValue(password);
        json["url"] = JSONValue(url);
        json["notes"] = JSONValue(notes);
        json["category"] = JSONValue(category);
        json["favorite"] = JSONValue(favorite);
        json["createdAt"] = JSONValue(createdAt.toISOExtString());
        json["modifiedAt"] = JSONValue(modifiedAt.toISOExtString());
        json["lastUsed"] = JSONValue(lastUsed.toISOExtString());
        json["usageCount"] = JSONValue(usageCount);

        // Tags array
        JSONValue[] tagArray;
        foreach (tag; tags)
            tagArray ~= JSONValue(tag);
        json["tags"] = JSONValue(tagArray);

        // Custom fields
        JSONValue customFieldsJson = JSONValue.emptyObject;
        foreach (key, value; customFields)
            customFieldsJson[key] = JSONValue(value);
        json["customFields"] = customFieldsJson;

        // TOTP settings
        if (totpSettings.secret.length > 0)
            json["totpSettings"] = totpSettings.toJSON();

        return json;
    }

    /// Create from JSON
    static VaultEntry fromJSON(JSONValue json)
    {
        VaultEntry entry;

        if ("id" in json) entry.id = json["id"].str;
        if ("title" in json) entry.title = json["title"].str;
        if ("username" in json) entry.username = json["username"].str;
        if ("email" in json) entry.email = json["email"].str;
        if ("password" in json) entry.password = json["password"].str;
        if ("url" in json) entry.url = json["url"].str;
        if ("notes" in json) entry.notes = json["notes"].str;
        if ("category" in json) entry.category = json["category"].str;
        if ("favorite" in json) entry.favorite = json["favorite"].boolean;
        if ("usageCount" in json) entry.usageCount = cast(int)json["usageCount"].integer;

        if ("createdAt" in json)
            entry.createdAt = SysTime.fromISOExtString(json["createdAt"].str);
        if ("modifiedAt" in json)
            entry.modifiedAt = SysTime.fromISOExtString(json["modifiedAt"].str);
        if ("lastUsed" in json)
            entry.lastUsed = SysTime.fromISOExtString(json["lastUsed"].str);

        // Tags
        if ("tags" in json && json["tags"].type == JSONType.array)
        {
            foreach (tagJson; json["tags"].array)
                entry.tags ~= tagJson.str;
        }

        // Custom fields
        if ("customFields" in json && json["customFields"].type == JSONType.object)
        {
            foreach (key, value; json["customFields"].object)
                entry.customFields[key] = value.str;
        }

        // TOTP settings
        if ("totpSettings" in json)
            entry.totpSettings = TOTPSettings.fromJSON(json["totpSettings"]);

        return entry;
    }

    /// Update last used timestamp
    void recordUsage()
    {
        lastUsed = Clock.currTime();
        usageCount++;
        modifiedAt = lastUsed;
    }

    /// Check if entry matches search query
    bool matchesSearch(string query) const
    {
        string lowerQuery = query.toLower();
        return title.toLower().canFind(lowerQuery) ||
               username.toLower().canFind(lowerQuery) ||
               email.toLower().canFind(lowerQuery) ||
               url.toLower().canFind(lowerQuery) ||
               notes.toLower().canFind(lowerQuery) ||
               category.toLower().canFind(lowerQuery) ||
               tags.any!(tag => tag.toLower().canFind(lowerQuery));
    }

    /// Get entry strength score based on password and other factors
    int getSecurityScore() const
    {
        int score = 0;

        // Password strength
        auto analysis = PasswordStrength.analyze(password);
        score += analysis.score;

        // Has 2FA
        if (totpSettings.secret.length > 0)
            score += 20;

        // Recent usage (security through awareness)
        auto daysSinceUsed = (Clock.currTime() - lastUsed).total!"days";
        if (daysSinceUsed < 30)
            score += 5;

        return score;
    }
}

/// TOTP (Time-based One-Time Password) settings
struct TOTPSettings
{
    string secret;
    string issuer;
    string accountName;
    int digits = 6;
    int period = 30;
    string algorithm = "SHA1"; // SHA1, SHA256, SHA512

    /// Convert to JSON
    JSONValue toJSON() const
    {
        JSONValue json = JSONValue.emptyObject;
        json["secret"] = JSONValue(secret);
        json["issuer"] = JSONValue(issuer);
        json["accountName"] = JSONValue(accountName);
        json["digits"] = JSONValue(digits);
        json["period"] = JSONValue(period);
        json["algorithm"] = JSONValue(algorithm);
        return json;
    }

    /// Create from JSON
    static TOTPSettings fromJSON(JSONValue json)
    {
        TOTPSettings settings;

        if ("secret" in json) settings.secret = json["secret"].str;
        if ("issuer" in json) settings.issuer = json["issuer"].str;
        if ("accountName" in json) settings.accountName = json["accountName"].str;
        if ("digits" in json) settings.digits = cast(int)json["digits"].integer;
        if ("period" in json) settings.period = cast(int)json["period"].integer;
        if ("algorithm" in json) settings.algorithm = json["algorithm"].str;

        return settings;
    }

    /// Parse from otpauth:// URL
    static TOTPSettings fromOtpAuthUrl(string url)
    {
        TOTPSettings settings;

        if (!url.startsWith("otpauth://totp/"))
            throw new Exception("Invalid TOTP URL format");

        // Parse URL components
        import std.uri : decodeComponent;

        // Extract account name and issuer from path
        string path = url["otpauth://totp/".length..$];
        auto queryStart = path.indexOf('?');

        string accountPart = queryStart == -1 ? path : path[0..queryStart];
        accountPart = decodeComponent(accountPart);

        auto colonPos = accountPart.indexOf(':');
        if (colonPos != -1)
        {
            settings.issuer = accountPart[0..colonPos];
            settings.accountName = accountPart[colonPos+1..$];
        }
        else
        {
            settings.accountName = accountPart;
        }

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
                            settings.secret = value;
                            break;
                        case "issuer":
                            settings.issuer = value;
                            break;
                        case "digits":
                            settings.digits = value.to!int;
                            break;
                        case "period":
                            settings.period = value.to!int;
                            break;
                        case "algorithm":
                            settings.algorithm = value;
                            break;
                        default:
                            break;
                    }
                }
            }
        }

        return settings;
    }

    /// Generate otpauth:// URL
    string toOtpAuthUrl() const
    {
        import std.uri : encodeComponent;

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

        if (algorithm != "SHA1")
            url ~= "&algorithm=" ~ algorithm;

        return url;
    }
}

/// Search and filter criteria
struct VaultFilter
{
    string searchQuery;
    string category;
    string[] tags;
    bool favoritesOnly;
    bool recentlyUsed; // Within last 30 days
    int minSecurityScore = 0;

    /// Check if entry matches this filter
    bool matches(const VaultEntry entry) const
    {
        // Search query
        if (searchQuery.length > 0 && !entry.matchesSearch(searchQuery))
            return false;

        // Category filter
        if (category.length > 0 && entry.category != category)
            return false;

        // Tags filter (entry must have all specified tags)
        foreach (tag; tags)
        {
            if (!entry.tags.canFind(tag))
                return false;
        }

        // Favorites filter
        if (favoritesOnly && !entry.favorite)
            return false;

        // Recently used filter
        if (recentlyUsed)
        {
            auto daysSinceUsed = (Clock.currTime() - entry.lastUsed).total!"days";
            if (daysSinceUsed > 30)
                return false;
        }

        // Security score filter
        if (entry.getSecurityScore() < minSecurityScore)
            return false;

        return true;
    }
}

/// Exception for vault operations
class VaultException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

/// Main password vault class
class PasswordVault
{
    private VaultEntry[string] _entries;
    private string _filePath;
    private string _masterPassword;
    private bool _isLocked = true;
    private SysTime _lastSaved;
    private bool _isDirty = false;

    /// Vault metadata
    string name = "My Vault";
    SysTime createdAt;
    SysTime modifiedAt;
    int formatVersion = 1;

    this(string filePath)
    {
        _filePath = filePath;
        createdAt = Clock.currTime();
        modifiedAt = createdAt;
    }

    /// Check if vault is locked
    @property bool isLocked() const
    {
        return _isLocked;
    }

    /// Get number of entries
    @property size_t entryCount() const
    {
        return _entries.length;
    }

    /// Get all categories
    @property string[] categories() const
    {
        bool[string] categorySet;
        foreach (entry; _entries.values)
        {
            if (entry.category.length > 0)
                categorySet[entry.category] = true;
        }
        return categorySet.keys.sort.array;
    }

    /// Get all tags
    @property string[] tags() const
    {
        bool[string] tagSet;
        foreach (entry; _entries.values)
        {
            foreach (tag; entry.tags)
                tagSet[tag] = true;
        }
        return tagSet.keys.sort.array;
    }

    /// Unlock vault with master password
    bool unlock(string masterPassword)
    {
        try
        {
            if (exists(_filePath))
            {
                loadFromFile(masterPassword);
            }

            _masterPassword = masterPassword;
            _isLocked = false;
            return true;
        }
        catch (Exception e)
        {
            _isLocked = true;
            return false;
        }
    }

    /// Lock the vault
    void lock()
    {
        if (_isDirty)
            save();

        _isLocked = true;
        _masterPassword = null;

        // Clear sensitive data from memory
        foreach (ref entry; _entries.values)
        {
            CryptoUtils.secureErase(cast(ubyte[])entry.password);
            if (entry.totpSettings.secret.length > 0)
                CryptoUtils.secureErase(cast(ubyte[])entry.totpSettings.secret);
        }
    }

    /// Change master password
    bool changeMasterPassword(string oldPassword, string newPassword)
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        if (!CryptoUtils.constantTimeEquals(_masterPassword, oldPassword))
            return false;

        _masterPassword = newPassword;
        _isDirty = true;
        save();
        return true;
    }

    /// Add new entry
    string addEntry(VaultEntry entry)
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        if (entry.id.length == 0)
            entry.id = randomUUID().toString();

        entry.modifiedAt = Clock.currTime();
        _entries[entry.id] = entry;
        _isDirty = true;

        return entry.id;
    }

    /// Update existing entry
    bool updateEntry(string id, VaultEntry entry)
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        if (id !in _entries)
            return false;

        entry.id = id;
        entry.modifiedAt = Clock.currTime();
        _entries[id] = entry;
        _isDirty = true;

        return true;
    }

    /// Remove entry
    bool removeEntry(string id)
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        if (id !in _entries)
            return false;

        // Secure erase sensitive data
        auto entry = _entries[id];
        CryptoUtils.secureErase(cast(ubyte[])entry.password);
        if (entry.totpSettings.secret.length > 0)
            CryptoUtils.secureErase(cast(ubyte[])entry.totpSettings.secret);

        _entries.remove(id);
        _isDirty = true;

        return true;
    }

    /// Get entry by ID
    VaultEntry* getEntry(string id)
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        if (id !in _entries)
            return null;

        _entries[id].recordUsage();
        _isDirty = true;

        return &_entries[id];
    }

    /// Search entries with filter
    VaultEntry[] searchEntries(VaultFilter filter = VaultFilter.init)
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        VaultEntry[] results;

        foreach (entry; _entries.values)
        {
            if (filter.matches(entry))
                results ~= entry;
        }

        // Sort by relevance (recently used first, then alphabetical)
        results.sort!((a, b) => a.lastUsed > b.lastUsed ||
                               (a.lastUsed == b.lastUsed && a.title < b.title));

        return results;
    }

    /// Get entries by category
    VaultEntry[] getEntriesByCategory(string category)
    {
        VaultFilter filter;
        filter.category = category;
        return searchEntries(filter);
    }

    /// Get favorite entries
    VaultEntry[] getFavoriteEntries()
    {
        VaultFilter filter;
        filter.favoritesOnly = true;
        return searchEntries(filter);
    }

    /// Get recently used entries
    VaultEntry[] getRecentlyUsedEntries()
    {
        VaultFilter filter;
        filter.recentlyUsed = true;
        return searchEntries(filter);
    }

    /// Save vault to file
    void save()
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        saveToFile();
        _isDirty = false;
        _lastSaved = Clock.currTime();
    }

    /// Check if vault needs saving
    @property bool isDirty() const
    {
        return _isDirty;
    }

    /// Export vault to JSON (for backup)
    JSONValue exportToJSON() const
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        JSONValue vault = JSONValue.emptyObject;
        vault["name"] = JSONValue(name);
        vault["createdAt"] = JSONValue(createdAt.toISOExtString());
        vault["modifiedAt"] = JSONValue(modifiedAt.toISOExtString());
        vault["version"] = JSONValue(formatVersion);

        JSONValue[] entriesJson;
        foreach (entry; _entries.values)
            entriesJson ~= entry.toJSON();

        vault["entries"] = JSONValue(entriesJson);

        return vault;
    }

    /// Import vault from JSON (for restore)
    void importFromJSON(JSONValue json)
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        if ("name" in json) name = json["name"].str;
        if ("version" in json) formatVersion = cast(int)json["version"].integer;

        if ("entries" in json && json["entries"].type == JSONType.array)
        {
            _entries.clear();

            foreach (entryJson; json["entries"].array)
            {
                auto entry = VaultEntry.fromJSON(entryJson);
                _entries[entry.id] = entry;
            }
        }

        _isDirty = true;
        modifiedAt = Clock.currTime();
    }

    /// Generate security report
    struct SecurityReport
    {
        int totalEntries;
        int weakPasswords;
        int duplicatePasswords;
        int oldPasswords; // > 1 year
        int without2FA;
        int overallScore;
        VaultEntry[] weakEntries;
    }

    SecurityReport generateSecurityReport()
    {
        if (_isLocked)
            throw new VaultException("Vault is locked");

        SecurityReport report;
        report.totalEntries = cast(int)_entries.length;

        string[string] passwordCounts;
        auto oneYearAgo = Clock.currTime() - dur!"days"(365);

        foreach (entry; _entries.values)
        {
            // Check password strength
            auto analysis = PasswordStrength.analyze(entry.password);
            if (analysis.level <= PasswordStrength.Level.Fair)
            {
                report.weakPasswords++;
                report.weakEntries ~= entry;
            }

            // Check for duplicates
            if (entry.password in passwordCounts)
                report.duplicatePasswords++;
            else
                passwordCounts[entry.password] = entry.id;

            // Check age
            if (entry.modifiedAt < oneYearAgo)
                report.oldPasswords++;

            // Check 2FA
            if (entry.totpSettings.secret.length == 0)
                report.without2FA++;
        }

        // Calculate overall score (0-100)
        if (report.totalEntries > 0)
        {
            int score = 100;
            score -= (report.weakPasswords * 100) / report.totalEntries;
            score -= (report.duplicatePasswords * 50) / report.totalEntries;
            score -= (report.oldPasswords * 10) / report.totalEntries;
            score -= (report.without2FA * 5) / report.totalEntries;

            report.overallScore = max(0, score);
        }

        return report;
    }

    private void loadFromFile(string masterPassword)
    {
        if (!exists(_filePath))
            return;

        ubyte[] encryptedData = cast(ubyte[]) read(_filePath);
        ubyte[] decryptedData = SimpleEncryption.decrypt(encryptedData, masterPassword);

        string jsonStr = cast(string) decryptedData;
        JSONValue json = parseJSON(jsonStr);

        importFromJSON(json);
        _isDirty = false;
    }

    private void saveToFile()
    {
        JSONValue json = exportToJSON();
        string jsonStr = json.toString();

        ubyte[] encryptedData = SimpleEncryption.encrypt(cast(ubyte[]) jsonStr, _masterPassword);

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

        modifiedAt = Clock.currTime();
    }
}
