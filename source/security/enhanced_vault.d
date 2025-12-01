module security.enhanced_vault;

import std.stdio;
import std.file;
import std.path;
import std.datetime;
import std.conv;
import std.string;
import std.algorithm;
import std.array;
import std.json;
import std.digest.sha;
import std.uuid;

import security.enhanced_crypto;
import security.models;

/// Enhanced password vault with Bitwarden-level features
class EnhancedVault
{
    private BaseVaultEntry[] _entries;
    private VaultFolder[] _folders;
    private TOTPAccount[] _totpAccounts;
    private string _vaultPath;
    private string _masterPasswordHash;
    private ubyte[] _vaultKey;
    private bool _isLocked = true;
    private VaultSettings _settings;

    // Vault statistics
    private VaultStatistics _stats;

    this(string vaultPath)
    {
        _vaultPath = vaultPath;
        _settings = VaultSettings();
        loadVault();
    }

    /// Check if vault is locked
    bool isLocked() const
    {
        return _isLocked;
    }

    /// Unlock vault with master password
    bool unlock(string masterPassword)
    {
        try
        {
            if (_masterPasswordHash.length == 0)
            {
                // First time setup
                return initializeVault(masterPassword);
            }

            // Verify master password
            if (!EnhancedCrypto.verifyPassword(masterPassword, _masterPasswordHash))
            {
                return false;
            }

            // Derive vault key
            ubyte[] salt = getSaltFromFile();
            _vaultKey = EnhancedCrypto.deriveKey(masterPassword, salt, _settings.kdfIterations);

            // Load and decrypt vault data
            if (loadEncryptedData())
            {
                _isLocked = false;
                updateStatistics();
                return true;
            }

            return false;
        }
        catch (Exception e)
        {
            writeln("Unlock error: ", e.msg);
            return false;
        }
    }

    /// Lock vault and clear sensitive data
    void lock()
    {
        _isLocked = true;

        // Clear sensitive data from memory
        if (_vaultKey.length > 0)
        {
            EnhancedCrypto.secureZero(_vaultKey);
        }

        // Clear entry passwords from memory
        foreach (entry; _entries)
        {
            if (auto loginEntry = cast(LoginEntry)entry)
            {
                EnhancedCrypto.secureZero(loginEntry.password);
            }
        }

        // Clear TOTP secrets
        foreach (account; _totpAccounts)
        {
            EnhancedCrypto.secureZero(account.secret);
        }
    }

    /// Initialize new vault
    private bool initializeVault(string masterPassword)
    {
        try
        {
            // Generate salt and hash master password
            ubyte[] salt = EnhancedCrypto.generateSalt();
            _masterPasswordHash = EnhancedCrypto.hashPassword(masterPassword);

            // Derive vault key
            _vaultKey = EnhancedCrypto.deriveKey(masterPassword, salt, _settings.kdfIterations);

            // Save salt to file
            saveSaltToFile(salt);

            // Initialize empty vault
            _entries = [];
            _folders = [];
            _totpAccounts = [];

            // Create default folders
            createDefaultFolders();

            // Save vault
            saveVault();

            _isLocked = false;
            updateStatistics();
            return true;
        }
        catch (Exception e)
        {
            writeln("Vault initialization error: ", e.msg);
            return false;
        }
    }

    /// Create default folders
    private void createDefaultFolders()
    {
        _folders ~= new VaultFolder("Personal");
        _folders ~= new VaultFolder("Work");
        _folders ~= new VaultFolder("Banking");
        _folders ~= new VaultFolder("Social Media");
        _folders ~= new VaultFolder("Shopping");
        _folders ~= new VaultFolder("Utilities");
    }

    /// Add new entry to vault
    void addEntry(BaseVaultEntry entry)
    {
        if (_isLocked) return;

        _entries ~= entry;
        updateStatistics();
        saveVault();
    }

    /// Update existing entry
    void updateEntry(BaseVaultEntry entry)
    {
        if (_isLocked) return;

        for (size_t i = 0; i < _entries.length; i++)
        {
            if (_entries[i].id == entry.id)
            {
                entry.touch();
                _entries[i] = entry;
                updateStatistics();
                saveVault();
                break;
            }
        }
    }

    /// Delete entry (soft delete)
    void deleteEntry(string entryId)
    {
        if (_isLocked) return;

        foreach (entry; _entries)
        {
            if (entry.id == entryId)
            {
                entry.markDeleted();
                updateStatistics();
                saveVault();
                break;
            }
        }
    }

    /// Permanently delete entry
    void permanentlyDeleteEntry(string entryId)
    {
        if (_isLocked) return;

        _entries = _entries.filter!(e => e.id != entryId).array;
        updateStatistics();
        saveVault();
    }

    /// Restore deleted entry
    void restoreEntry(string entryId)
    {
        if (_isLocked) return;

        foreach (entry; _entries)
        {
            if (entry.id == entryId && entry.deleted)
            {
                entry.restore();
                updateStatistics();
                saveVault();
                break;
            }
        }
    }

    /// Get all entries (excluding deleted)
    BaseVaultEntry[] getEntries()
    {
        if (_isLocked) return [];
        return _entries.filter!(e => !e.deleted).array;
    }

    /// Get deleted entries
    BaseVaultEntry[] getDeletedEntries()
    {
        if (_isLocked) return [];
        return _entries.filter!(e => e.deleted).array;
    }

    /// Search entries
    BaseVaultEntry[] searchEntries(VaultFilter filter)
    {
        if (_isLocked) return [];

        BaseVaultEntry[] results = _entries.dup;

        // Filter deleted entries unless specifically requested
        if (!filter.deletedOnly)
        {
            results = results.filter!(e => !e.deleted).array;
        }
        else
        {
            results = results.filter!(e => e.deleted).array;
        }

        // Text search
        if (filter.searchText.length > 0)
        {
            string searchLower = filter.searchText.toLower();
            results = results.filter!(e =>
                e.name.toLower().canFind(searchLower) ||
                e.notes.toLower().canFind(searchLower) ||
                (cast(LoginEntry)e && (
                    (cast(LoginEntry)e).username.toLower().canFind(searchLower) ||
                    (cast(LoginEntry)e).email.toLower().canFind(searchLower)
                ))
            ).array;
        }

        // Type filter
        if (filter.types.length > 0)
        {
            results = results.filter!(e => filter.types.canFind(e.getType())).array;
        }

        // Tags filter
        if (filter.tags.length > 0)
        {
            results = results.filter!(e =>
                filter.tags.any!(tag => e.tags.canFind(tag))
            ).array;
        }

        // Folder filter
        if (filter.folderId.length > 0)
        {
            results = results.filter!(e => e.folderId == filter.folderId).array;
        }

        // Favorites filter
        if (filter.favoritesOnly)
        {
            results = results.filter!(e => e.favorite).array;
        }

        // Security level filter
        results = results.filter!(e => e.securityLevel >= filter.minSecurityLevel).array;

        // Additional filters
        if (filter.oldPasswordsOnly)
        {
            results = results.filter!(e => e.getPasswordAge() > 365).array;
        }

        if (filter.weakPasswordsOnly)
        {
            results = results.filter!((e) {
                if (auto loginEntry = cast(LoginEntry)e)
                {
                    auto strength = EnhancedCrypto.analyzePasswordStrength(loginEntry.password);
                    return strength.level <= PasswordStrengthLevel.Fair;
                }
                return false;
            }).array;
        }

        if (filter.noTotpOnly)
        {
            results = results.filter!((e) {
                if (auto loginEntry = cast(LoginEntry)e)
                {
                    return !loginEntry.hasTOTP();
                }
                return false;
            }).array;
        }

        if (filter.expiredCardsOnly)
        {
            results = results.filter!((e) {
                if (auto cardEntry = cast(CardEntry)e)
                {
                    return cardEntry.isExpired();
                }
                return false;
            }).array;
        }

        return results;
    }

    /// Get entry by ID
    BaseVaultEntry getEntry(string entryId)
    {
        if (_isLocked) return null;

        foreach (entry; _entries)
        {
            if (entry.id == entryId)
                return entry;
        }
        return null;
    }

    /// Add folder
    void addFolder(VaultFolder folder)
    {
        if (_isLocked) return;
        _folders ~= folder;
        saveVault();
    }

    /// Get all folders
    VaultFolder[] getFolders()
    {
        if (_isLocked) return [];
        return _folders.dup;
    }

    /// Add TOTP account
    void addTOTPAccount(TOTPAccount account)
    {
        if (_isLocked) return;
        _totpAccounts ~= account;
        saveVault();
    }

    /// Get all TOTP accounts
    TOTPAccount[] getTOTPAccounts()
    {
        if (_isLocked) return [];
        return _totpAccounts.dup;
    }

    /// Get TOTP account by ID
    TOTPAccount getTOTPAccount(string accountId)
    {
        if (_isLocked) return null;

        foreach (account; _totpAccounts)
        {
            if (account.id == accountId)
                return account;
        }
        return null;
    }

    /// Generate security report
    SecurityReport generateSecurityReport() const
    {
        if (_isLocked) return SecurityReport();

        // Convert to VaultEntry format for security utils
        VaultEntry[] entries;
        foreach (entry; _entries)
        {
            if (auto loginEntry = cast(LoginEntry)entry)
            {
                VaultEntry ve;
                ve.password = loginEntry.password;
                ve.passwordLastChanged = loginEntry.passwordLastChanged;
                ve.hasTOTP = loginEntry.hasTOTP();
                entries ~= ve;
            }
        }

        return SecurityUtils.generateSecurityReport(entries);
    }

    /// Get vault statistics
    VaultStatistics getStatistics() const
    {
        return _stats;
    }

    /// Get vault settings
    VaultSettings getVaultSettings()
    {
        return _settings;
    }

    /// Update vault statistics
    private void updateStatistics()
    {
        if (_isLocked) return;

        _stats = VaultStatistics();
        _stats.totalEntries = cast(uint)_entries.filter!(e => !e.deleted).array.length;
        _stats.deletedEntries = cast(uint)_entries.filter!(e => e.deleted).array.length;
        _stats.totalFolders = cast(uint)_folders.length;
        _stats.totalTOTPAccounts = cast(uint)_totpAccounts.length;

        // Count by type
        foreach (entry; _entries)
        {
            if (entry.deleted) continue;

            final switch (entry.getType())
            {
                case VaultEntryType.Login:
                    _stats.loginEntries++;
                    break;
                case VaultEntryType.SecureNote:
                    _stats.secureNoteEntries++;
                    break;
                case VaultEntryType.Card:
                    _stats.cardEntries++;
                    break;
                case VaultEntryType.Identity:
                    _stats.identityEntries++;
                    break;
            }

            if (entry.favorite)
                _stats.favoriteEntries++;
        }

        // Security analysis
        auto securityReport = generateSecurityReport();
        _stats.weakPasswords = securityReport.weakPasswords;
        _stats.oldPasswords = securityReport.oldPasswords;
        _stats.compromisedPasswords = securityReport.compromisedPasswords;
        _stats.securityScore = securityReport.securityScore;
    }

    /// Import from JSON (Bitwarden compatible)
    bool importFromJSON(string jsonPath)
    {
        if (_isLocked) return false;

        try
        {
            string content = readText(jsonPath);
            JSONValue json = parseJSON(content);

            if ("items" in json)
            {
                foreach (item; json["items"].array)
                {
                    try
                    {
                        auto entry = VaultEntryFactory.fromJSON(item);
                        if (entry)
                        {
                            _entries ~= entry;
                        }
                    }
                    catch (Exception e)
                    {
                        writeln("Failed to import entry: ", e.msg);
                    }
                }
            }

            updateStatistics();
            saveVault();
            return true;
        }
        catch (Exception e)
        {
            writeln("Import error: ", e.msg);
            return false;
        }
    }

    /// Export to JSON (Bitwarden compatible)
    bool exportToJSON(string jsonPath) const
    {
        if (_isLocked) return false;

        try
        {
            JSONValue exportData = JSONValue.emptyObject;
            exportData["encrypted"] = JSONValue(false);
            exportData["folders"] = JSONValue.emptyArray;
            exportData["items"] = JSONValue.emptyArray;

            // Export folders
            foreach (folder; _folders)
            {
                exportData["folders"].array ~= folder.toJSON();
            }

            // Export entries
            foreach (entry; _entries)
            {
                if (!entry.deleted)
                {
                    exportData["items"].array ~= entry.toJSON();
                }
            }

            std.file.write(jsonPath, exportData.toPrettyString());
            return true;
        }
        catch (Exception e)
        {
            writeln("Export error: ", e.msg);
            return false;
        }
    }

    /// Change master password
    bool changeMasterPassword(string currentPassword, string newPassword)
    {
        if (_isLocked) return false;

        // Verify current password
        if (!EnhancedCrypto.verifyPassword(currentPassword, _masterPasswordHash))
        {
            return false;
        }

        try
        {
            // Generate new salt and hash
            ubyte[] newSalt = EnhancedCrypto.generateSalt();
            _masterPasswordHash = EnhancedCrypto.hashPassword(newPassword);

            // Derive new vault key
            ubyte[] newVaultKey = EnhancedCrypto.deriveKey(newPassword, newSalt, _settings.kdfIterations);

            // Save new salt
            saveSaltToFile(newSalt);

            // Clear old key and use new one
            EnhancedCrypto.secureZero(_vaultKey);
            _vaultKey = newVaultKey;

            // Re-encrypt and save vault
            saveVault();
            return true;
        }
        catch (Exception e)
        {
            writeln("Password change error: ", e.msg);
            return false;
        }
    }

    /// Clean up deleted entries older than specified days
    void cleanupDeletedEntries(uint daysOld = 30)
    {
        if (_isLocked) return;

        SysTime cutoffDate = Clock.currTime() - daysOld.days;
        size_t originalCount = _entries.length;

        _entries = _entries.filter!(e =>
            !e.deleted || e.deletedAt > cutoffDate
        ).array;

        if (_entries.length < originalCount)
        {
            updateStatistics();
            saveVault();
        }
    }

    /// Backup vault to specified path
    bool createBackup(string backupPath) const
    {
        if (_isLocked) return false;

        try
        {
            copy(_vaultPath, backupPath);
            return true;
        }
        catch (Exception e)
        {
            writeln("Backup error: ", e.msg);
            return false;
        }
    }

    /// Save vault to disk
    private void saveVault()
    {
        if (_isLocked) return;

        try
        {
            // Create vault data JSON
            JSONValue vaultData = JSONValue.emptyObject;
            vaultData["masterPasswordHash"] = JSONValue(_masterPasswordHash);
            vaultData["settings"] = _settings.toJSON();
            vaultData["entries"] = JSONValue.emptyArray;
            vaultData["folders"] = JSONValue.emptyArray;
            vaultData["totpAccounts"] = JSONValue.emptyArray;

            // Add entries
            foreach (entry; _entries)
            {
                vaultData["entries"].array ~= entry.toJSON();
            }

            // Add folders
            foreach (folder; _folders)
            {
                vaultData["folders"].array ~= folder.toJSON();
            }

            // Add TOTP accounts
            foreach (account; _totpAccounts)
            {
                vaultData["totpAccounts"].array ~= account.toJSON();
            }

            // Encrypt vault data
            string jsonString = vaultData.toString();
            ubyte[] encryptedData = EnhancedCrypto.encrypt(cast(ubyte[])jsonString, _vaultKey);

            // Write to file atomically
            string tempPath = _vaultPath ~ ".tmp";
            std.file.write(tempPath, encryptedData);
            rename(tempPath, _vaultPath);
        }
        catch (Exception e)
        {
            writeln("Save error: ", e.msg);
        }
    }

    /// Load vault from disk
    private void loadVault()
    {
        if (!exists(_vaultPath))
        {
            // New vault
            _masterPasswordHash = "";
            return;
        }

        try
        {
            // Load metadata (unencrypted part)
            // For now, we'll store master password hash separately
            string hashPath = _vaultPath ~ ".hash";
            if (exists(hashPath))
            {
                _masterPasswordHash = readText(hashPath).strip();
            }
        }
        catch (Exception e)
        {
            writeln("Load error: ", e.msg);
        }
    }

    /// Load and decrypt vault data
    private bool loadEncryptedData()
    {
        try
        {
            ubyte[] encryptedData = cast(ubyte[])std.file.read(_vaultPath);
            ubyte[] decryptedData = EnhancedCrypto.decrypt(encryptedData, _vaultKey);

            string jsonString = cast(string)decryptedData;
            JSONValue vaultData = parseJSON(jsonString);

            // Load settings
            if ("settings" in vaultData)
            {
                _settings = VaultSettings.fromJSON(vaultData["settings"]);
            }

            // Load entries
            _entries.length = 0;
            if ("entries" in vaultData)
            {
                foreach (entryJson; vaultData["entries"].array)
                {
                    try
                    {
                        auto entry = VaultEntryFactory.fromJSON(entryJson);
                        if (entry)
                        {
                            _entries ~= entry;
                        }
                    }
                    catch (Exception e)
                    {
                        writeln("Failed to load entry: ", e.msg);
                    }
                }
            }

            // Load folders
            _folders.length = 0;
            if ("folders" in vaultData)
            {
                foreach (folderJson; vaultData["folders"].array)
                {
                    _folders ~= VaultFolder.fromJSON(folderJson);
                }
            }

            // Load TOTP accounts
            _totpAccounts.length = 0;
            if ("totpAccounts" in vaultData)
            {
                foreach (accountJson; vaultData["totpAccounts"].array)
                {
                    _totpAccounts ~= TOTPAccount.fromJSON(accountJson);
                }
            }

            return true;
        }
        catch (Exception e)
        {
            writeln("Decrypt error: ", e.msg);
            return false;
        }
    }

    /// Save salt to file
    private void saveSaltToFile(ubyte[] salt)
    {
        string saltPath = _vaultPath ~ ".salt";
        std.file.write(saltPath, salt);

        // Also save master password hash
        string hashPath = _vaultPath ~ ".hash";
        std.file.write(hashPath, _masterPasswordHash);
    }

    /// Get salt from file
    private ubyte[] getSaltFromFile()
    {
        string saltPath = _vaultPath ~ ".salt";
        if (exists(saltPath))
        {
            return cast(ubyte[])std.file.read(saltPath);
        }
        throw new Exception("Salt file not found");
    }
}

/// Vault settings
struct VaultSettings
{
    uint kdfIterations = 100_000;
    uint vaultTimeout = 900; // 15 minutes in seconds
    bool clearClipboard = true;
    uint clipboardClearSeconds = 30;
    bool enableTwoFactor = false;
    bool requireMasterPasswordReprompt = false;

    JSONValue toJSON() const
    {
        JSONValue json = JSONValue.emptyObject;
        json["kdfIterations"] = JSONValue(kdfIterations);
        json["vaultTimeout"] = JSONValue(vaultTimeout);
        json["clearClipboard"] = JSONValue(clearClipboard);
        json["clipboardClearSeconds"] = JSONValue(clipboardClearSeconds);
        json["enableTwoFactor"] = JSONValue(enableTwoFactor);
        json["requireMasterPasswordReprompt"] = JSONValue(requireMasterPasswordReprompt);
        return json;
    }

    static VaultSettings fromJSON(JSONValue json)
    {
        VaultSettings settings;
        if ("kdfIterations" in json) settings.kdfIterations = cast(uint)json["kdfIterations"].integer;
        if ("vaultTimeout" in json) settings.vaultTimeout = cast(uint)json["vaultTimeout"].integer;
        if ("clearClipboard" in json) settings.clearClipboard = json["clearClipboard"].boolean;
        if ("clipboardClearSeconds" in json) settings.clipboardClearSeconds = cast(uint)json["clipboardClearSeconds"].integer;
        if ("enableTwoFactor" in json) settings.enableTwoFactor = json["enableTwoFactor"].boolean;
        if ("requireMasterPasswordReprompt" in json) settings.requireMasterPasswordReprompt = json["requireMasterPasswordReprompt"].boolean;
        return settings;
    }
}

/// Vault statistics
struct VaultStatistics
{
    uint totalEntries;
    uint loginEntries;
    uint secureNoteEntries;
    uint cardEntries;
    uint identityEntries;
    uint favoriteEntries;
    uint deletedEntries;
    uint totalFolders;
    uint totalTOTPAccounts;

    // Security metrics
    uint weakPasswords;
    uint oldPasswords;
    uint compromisedPasswords;
    uint securityScore;

    string getScoreColor() const
    {
        if (securityScore >= 80) return "#4CAF50";
        else if (securityScore >= 60) return "#8BC34A";
        else if (securityScore >= 40) return "#FF9800";
        else if (securityScore >= 20) return "#FF5722";
        else return "#F44336";
    }
}
