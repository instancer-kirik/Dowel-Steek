module security.models;

import std.stdio;
import std.string;
import std.conv;
import std.datetime;
import std.json;
import std.algorithm;
import std.array;
import std.uuid;

/// Entry types supported by the vault
enum VaultEntryType
{
    Login,
    SecureNote,
    Card,
    Identity
}

/// Security level indicators
enum SecurityLevel
{
    Critical,  // Banking, work accounts
    High,      // Email, social media
    Medium,    // Shopping, forums
    Low        // Newsletters, trial accounts
}

/// Base vault entry with common fields
abstract class BaseVaultEntry
{
    string id;
    string name;
    string notes;
    string[] tags;
    string folderId;
    bool favorite;
    SecurityLevel securityLevel;
    SysTime createdAt;
    SysTime updatedAt;
    SysTime passwordLastChanged;
    bool deleted;
    SysTime deletedAt;

    abstract VaultEntryType getType();
    abstract JSONValue toJSON() const;
    abstract void fromJSON(JSONValue json);

    this(string name = "")
    {
        this.id = randomUUID().toString();
        this.name = name;
        this.createdAt = Clock.currTime();
        this.updatedAt = Clock.currTime();
        this.passwordLastChanged = Clock.currTime();
        this.securityLevel = SecurityLevel.Medium;
    }

    /// Update modification time
    void touch()
    {
        updatedAt = Clock.currTime();
    }

    /// Mark as deleted (soft delete)
    void markDeleted()
    {
        deleted = true;
        deletedAt = Clock.currTime();
        touch();
    }

    /// Restore from deleted
    void restore()
    {
        deleted = false;
        touch();
    }

    /// Get age of password in days
    long getPasswordAge() const
    {
        return (Clock.currTime() - passwordLastChanged).total!"days";
    }

    /// Common JSON fields
    protected JSONValue getBaseJSON() const
    {
        JSONValue json = JSONValue.emptyObject;
        json["id"] = JSONValue(id);
        json["name"] = JSONValue(name);
        json["notes"] = JSONValue(notes);
        json["tags"] = JSONValue(tags);
        json["folderId"] = JSONValue(folderId);
        json["favorite"] = JSONValue(favorite);
        json["securityLevel"] = JSONValue(cast(int)securityLevel);
        json["createdAt"] = JSONValue(createdAt.toISOExtString());
        json["updatedAt"] = JSONValue(updatedAt.toISOExtString());
        json["passwordLastChanged"] = JSONValue(passwordLastChanged.toISOExtString());
        json["deleted"] = JSONValue(deleted);
        if (deleted)
            json["deletedAt"] = JSONValue(deletedAt.toISOExtString());
        return json;
    }

    /// Load common JSON fields
    protected void loadBaseJSON(JSONValue json)
    {
        if ("id" in json) id = json["id"].str;
        if ("name" in json) name = json["name"].str;
        if ("notes" in json) notes = json["notes"].str;
        if ("folderId" in json) folderId = json["folderId"].str;
        if ("favorite" in json) favorite = json["favorite"].boolean;
        if ("securityLevel" in json) securityLevel = cast(SecurityLevel)json["securityLevel"].integer;
        if ("createdAt" in json) createdAt = SysTime.fromISOExtString(json["createdAt"].str);
        if ("updatedAt" in json) updatedAt = SysTime.fromISOExtString(json["updatedAt"].str);
        if ("passwordLastChanged" in json) passwordLastChanged = SysTime.fromISOExtString(json["passwordLastChanged"].str);
        if ("deleted" in json) deleted = json["deleted"].boolean;
        if ("deletedAt" in json && deleted) deletedAt = SysTime.fromISOExtString(json["deletedAt"].str);

        if ("tags" in json)
        {
            tags.length = 0;
            foreach (tag; json["tags"].array)
                tags ~= tag.str;
        }
    }
}

/// Login entry (username/password)
class LoginEntry : BaseVaultEntry
{
    string username;
    string password;
    string email;
    string[] urls;
    string totpSecret;
    string[] passwordHistory;
    bool requireMasterPasswordReprompt;

    override VaultEntryType getType() { return VaultEntryType.Login; }

    this(string name = "", string username = "", string password = "")
    {
        super(name);
        this.username = username;
        this.password = password;
    }

    /// Add URL to the entry
    void addUrl(string url)
    {
        if (!urls.canFind(url))
        {
            urls ~= url;
            touch();
        }
    }

    /// Change password and add to history
    void changePassword(string newPassword)
    {
        if (password.length > 0)
        {
            // Add current password to history
            passwordHistory ~= password ~ "|" ~ passwordLastChanged.toISOExtString();

            // Keep only last 5 passwords
            if (passwordHistory.length > 5)
                passwordHistory = passwordHistory[$ - 5 .. $];
        }

        password = newPassword;
        passwordLastChanged = Clock.currTime();
        touch();
    }

    /// Check if has TOTP
    bool hasTOTP() const
    {
        return totpSecret.length > 0;
    }

    /// Get primary URL
    string getPrimaryUrl() const
    {
        return urls.length > 0 ? urls[0] : "";
    }

    override JSONValue toJSON() const
    {
        JSONValue json = getBaseJSON();
        json["type"] = JSONValue("login");
        json["username"] = JSONValue(username);
        json["password"] = JSONValue(password);
        json["email"] = JSONValue(email);
        json["urls"] = JSONValue(urls);
        json["totpSecret"] = JSONValue(totpSecret);
        json["passwordHistory"] = JSONValue(passwordHistory);
        json["requireMasterPasswordReprompt"] = JSONValue(requireMasterPasswordReprompt);
        return json;
    }

    override void fromJSON(JSONValue json)
    {
        loadBaseJSON(json);
        if ("username" in json) username = json["username"].str;
        if ("password" in json) password = json["password"].str;
        if ("email" in json) email = json["email"].str;
        if ("totpSecret" in json) totpSecret = json["totpSecret"].str;
        if ("requireMasterPasswordReprompt" in json) requireMasterPasswordReprompt = json["requireMasterPasswordReprompt"].boolean;

        if ("urls" in json)
        {
            urls.length = 0;
            foreach (url; json["urls"].array)
                urls ~= url.str;
        }

        if ("passwordHistory" in json)
        {
            passwordHistory.length = 0;
            foreach (hist; json["passwordHistory"].array)
                passwordHistory ~= hist.str;
        }
    }
}

/// Secure note entry
class SecureNoteEntry : BaseVaultEntry
{
    string content;
    bool isMarkdown;

    override VaultEntryType getType() { return VaultEntryType.SecureNote; }

    this(string name = "", string content = "")
    {
        super(name);
        this.content = content;
    }

    override JSONValue toJSON() const
    {
        JSONValue json = getBaseJSON();
        json["type"] = JSONValue("secureNote");
        json["content"] = JSONValue(content);
        json["isMarkdown"] = JSONValue(isMarkdown);
        return json;
    }

    override void fromJSON(JSONValue json)
    {
        loadBaseJSON(json);
        if ("content" in json) content = json["content"].str;
        if ("isMarkdown" in json) isMarkdown = json["isMarkdown"].boolean;
    }
}

/// Credit card entry
class CardEntry : BaseVaultEntry
{
    string cardholderName;
    string brand;
    string number;
    string expiryMonth;
    string expiryYear;
    string securityCode;

    override VaultEntryType getType() { return VaultEntryType.Card; }

    this(string name = "", string cardholderName = "")
    {
        super(name);
        this.cardholderName = cardholderName;
    }

    /// Get masked card number
    string getMaskedNumber() const
    {
        if (number.length < 4)
            return number;
        return "**** **** **** " ~ number[$ - 4 .. $];
    }

    /// Check if card is expired
    bool isExpired() const
    {
        if (expiryMonth.length == 0 || expiryYear.length == 0)
            return false;

        try
        {
            auto now = Clock.currTime();
            int month = expiryMonth.to!int;
            int year = expiryYear.to!int;

            // Handle 2-digit years
            if (year < 100)
                year += 2000;

            return year < now.year || (year == now.year && month < now.month);
        }
        catch (Exception)
        {
            return false;
        }
    }

    override JSONValue toJSON() const
    {
        JSONValue json = getBaseJSON();
        json["type"] = JSONValue("card");
        json["cardholderName"] = JSONValue(cardholderName);
        json["brand"] = JSONValue(brand);
        json["number"] = JSONValue(number);
        json["expiryMonth"] = JSONValue(expiryMonth);
        json["expiryYear"] = JSONValue(expiryYear);
        json["securityCode"] = JSONValue(securityCode);
        return json;
    }

    override void fromJSON(JSONValue json)
    {
        loadBaseJSON(json);
        if ("cardholderName" in json) cardholderName = json["cardholderName"].str;
        if ("brand" in json) brand = json["brand"].str;
        if ("number" in json) number = json["number"].str;
        if ("expiryMonth" in json) expiryMonth = json["expiryMonth"].str;
        if ("expiryYear" in json) expiryYear = json["expiryYear"].str;
        if ("securityCode" in json) securityCode = json["securityCode"].str;
    }
}

/// Identity entry (personal information)
class IdentityEntry : BaseVaultEntry
{
    // Name
    string title;
    string firstName;
    string middleName;
    string lastName;

    // Contact
    string email;
    string phone;

    // Address
    string address1;
    string address2;
    string city;
    string state;
    string postalCode;
    string country;

    // Other
    string company;
    string ssn;
    string username;
    string passportNumber;
    string licenseNumber;

    override VaultEntryType getType() { return VaultEntryType.Identity; }

    this(string name = "", string firstName = "", string lastName = "")
    {
        super(name);
        this.firstName = firstName;
        this.lastName = lastName;
    }

    /// Get full name
    string getFullName() const
    {
        string[] nameParts;
        if (title.length > 0) nameParts ~= title;
        if (firstName.length > 0) nameParts ~= firstName;
        if (middleName.length > 0) nameParts ~= middleName;
        if (lastName.length > 0) nameParts ~= lastName;
        return nameParts.join(" ");
    }

    /// Get full address
    string getFullAddress() const
    {
        string[] addressParts;
        if (address1.length > 0) addressParts ~= address1;
        if (address2.length > 0) addressParts ~= address2;
        if (city.length > 0) addressParts ~= city;
        if (state.length > 0) addressParts ~= state;
        if (postalCode.length > 0) addressParts ~= postalCode;
        if (country.length > 0) addressParts ~= country;
        return addressParts.join(", ");
    }

    override JSONValue toJSON() const
    {
        JSONValue json = getBaseJSON();
        json["type"] = JSONValue("identity");
        json["title"] = JSONValue(title);
        json["firstName"] = JSONValue(firstName);
        json["middleName"] = JSONValue(middleName);
        json["lastName"] = JSONValue(lastName);
        json["email"] = JSONValue(email);
        json["phone"] = JSONValue(phone);
        json["address1"] = JSONValue(address1);
        json["address2"] = JSONValue(address2);
        json["city"] = JSONValue(city);
        json["state"] = JSONValue(state);
        json["postalCode"] = JSONValue(postalCode);
        json["country"] = JSONValue(country);
        json["company"] = JSONValue(company);
        json["ssn"] = JSONValue(ssn);
        json["username"] = JSONValue(username);
        json["passportNumber"] = JSONValue(passportNumber);
        json["licenseNumber"] = JSONValue(licenseNumber);
        return json;
    }

    override void fromJSON(JSONValue json)
    {
        loadBaseJSON(json);
        if ("title" in json) title = json["title"].str;
        if ("firstName" in json) firstName = json["firstName"].str;
        if ("middleName" in json) middleName = json["middleName"].str;
        if ("lastName" in json) lastName = json["lastName"].str;
        if ("email" in json) email = json["email"].str;
        if ("phone" in json) phone = json["phone"].str;
        if ("address1" in json) address1 = json["address1"].str;
        if ("address2" in json) address2 = json["address2"].str;
        if ("city" in json) city = json["city"].str;
        if ("state" in json) state = json["state"].str;
        if ("postalCode" in json) postalCode = json["postalCode"].str;
        if ("country" in json) country = json["country"].str;
        if ("company" in json) company = json["company"].str;
        if ("ssn" in json) ssn = json["ssn"].str;
        if ("username" in json) username = json["username"].str;
        if ("passportNumber" in json) passportNumber = json["passportNumber"].str;
        if ("licenseNumber" in json) licenseNumber = json["licenseNumber"].str;
    }
}

/// Folder/Collection for organizing entries
class VaultFolder
{
    string id;
    string name;
    string parentId;
    SysTime createdAt;
    SysTime updatedAt;

    this(string name = "")
    {
        this.id = randomUUID().toString();
        this.name = name;
        this.createdAt = Clock.currTime();
        this.updatedAt = Clock.currTime();
    }

    JSONValue toJSON() const
    {
        JSONValue json = JSONValue.emptyObject;
        json["id"] = JSONValue(id);
        json["name"] = JSONValue(name);
        json["parentId"] = JSONValue(parentId);
        json["createdAt"] = JSONValue(createdAt.toISOExtString());
        json["updatedAt"] = JSONValue(updatedAt.toISOExtString());
        return json;
    }

    static VaultFolder fromJSON(JSONValue json)
    {
        auto folder = new VaultFolder();
        if ("id" in json) folder.id = json["id"].str;
        if ("name" in json) folder.name = json["name"].str;
        if ("parentId" in json) folder.parentId = json["parentId"].str;
        if ("createdAt" in json) folder.createdAt = SysTime.fromISOExtString(json["createdAt"].str);
        if ("updatedAt" in json) folder.updatedAt = SysTime.fromISOExtString(json["updatedAt"].str);
        return folder;
    }
}

/// TOTP Account for 2FA
class TOTPAccount
{
    string id;
    string issuer;
    string accountName;
    string secret;
    string algorithm = "SHA1";
    uint digits = 6;
    uint period = 30;
    SysTime createdAt;

    this(string issuer = "", string accountName = "", string secret = "")
    {
        this.id = randomUUID().toString();
        this.issuer = issuer;
        this.accountName = accountName;
        this.secret = secret;
        this.createdAt = Clock.currTime();
    }

    /// Generate current TOTP code
    string generateCode()
    {
        import security.authenticator.totp;
        try
        {
            auto generator = TOTPGenerator(secret, cast(TOTPAlgorithm)0, digits, period);
            return generator.generateCode();
        }
        catch (Exception)
        {
            return "ERROR";
        }
    }

    /// Get time remaining for current code
    uint getTimeRemaining()
    {
        auto now = Clock.currTime().toUnixTime();
        return cast(uint)(period - (now % period));
    }

    /// Get progress percentage (0-100)
    uint getProgress()
    {
        return (getTimeRemaining() * 100) / period;
    }

    /// Create from otpauth:// URL
    static TOTPAccount fromOtpAuthUrl(string url)
    {
        import std.uri : decode;
        import std.regex : matchFirst, regex;

        auto account = new TOTPAccount();

        // Parse otpauth://totp/issuer:account?secret=...&issuer=...
        auto match = url.matchFirst(regex(r"otpauth://totp/([^?]+)\?(.+)"));
        if (match.empty)
            throw new Exception("Invalid otpauth URL");

        string label = match[1].decode();
        string params = match[2];

        // Parse label (issuer:account or just account)
        auto colonPos = label.indexOf(':');
        if (colonPos >= 0)
        {
            account.issuer = label[0 .. colonPos];
            account.accountName = label[colonPos + 1 .. $];
        }
        else
        {
            account.accountName = label;
        }

        // Parse parameters
        foreach (param; params.split('&'))
        {
            auto eqPos = param.indexOf('=');
            if (eqPos >= 0)
            {
                string key = param[0 .. eqPos];
                string value = param[eqPos + 1 .. $].decode();

                switch (key)
                {
                    case "secret":
                        account.secret = value;
                        break;
                    case "issuer":
                        account.issuer = value;
                        break;
                    case "algorithm":
                        account.algorithm = value;
                        break;
                    case "digits":
                        account.digits = value.to!uint;
                        break;
                    case "period":
                        account.period = value.to!uint;
                        break;
                    default:
                        break;
                }
            }
        }

        return account;
    }

    /// Convert to otpauth:// URL
    string toOtpAuthUrl() const
    {
        import std.uri : encode;

        string label = issuer.length > 0 ? issuer ~ ":" ~ accountName : accountName;

        return "otpauth://totp/" ~ label.encode() ~
               "?secret=" ~ secret ~
               "&issuer=" ~ issuer.encode() ~
               "&algorithm=" ~ algorithm ~
               "&digits=" ~ digits.to!string ~
               "&period=" ~ period.to!string;
    }

    JSONValue toJSON() const
    {
        JSONValue json = JSONValue.emptyObject;
        json["id"] = JSONValue(id);
        json["issuer"] = JSONValue(issuer);
        json["accountName"] = JSONValue(accountName);
        json["secret"] = JSONValue(secret);
        json["algorithm"] = JSONValue(algorithm);
        json["digits"] = JSONValue(digits);
        json["period"] = JSONValue(period);
        json["createdAt"] = JSONValue(createdAt.toISOExtString());
        return json;
    }

    static TOTPAccount fromJSON(JSONValue json)
    {
        auto account = new TOTPAccount();
        if ("id" in json) account.id = json["id"].str;
        if ("issuer" in json) account.issuer = json["issuer"].str;
        if ("accountName" in json) account.accountName = json["accountName"].str;
        if ("secret" in json) account.secret = json["secret"].str;
        if ("algorithm" in json) account.algorithm = json["algorithm"].str;
        if ("digits" in json) account.digits = cast(uint)json["digits"].integer;
        if ("period" in json) account.period = cast(uint)json["period"].integer;
        if ("createdAt" in json) account.createdAt = SysTime.fromISOExtString(json["createdAt"].str);
        return account;
    }
}

/// Vault search filter
struct VaultFilter
{
    string searchText;
    VaultEntryType[] types;
    string[] tags;
    string folderId;
    bool favoritesOnly;
    bool deletedOnly;
    SecurityLevel minSecurityLevel;
    bool expiredCardsOnly;
    bool oldPasswordsOnly; // > 1 year
    bool weakPasswordsOnly;
    bool noTotpOnly;
}

/// Entry factory for JSON deserialization
class VaultEntryFactory
{
    static BaseVaultEntry fromJSON(JSONValue json)
    {
        if ("type" !in json)
            throw new Exception("Missing entry type");

        string type = json["type"].str;
        BaseVaultEntry entry;

        switch (type)
        {
            case "login":
                entry = new LoginEntry();
                break;
            case "secureNote":
                entry = new SecureNoteEntry();
                break;
            case "card":
                entry = new CardEntry();
                break;
            case "identity":
                entry = new IdentityEntry();
                break;
            default:
                throw new Exception("Unknown entry type: " ~ type);
        }

        entry.fromJSON(json);
        return entry;
    }
}
