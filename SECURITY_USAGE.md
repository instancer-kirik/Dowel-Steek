# Dowel-Steek Security Suite Usage Guide

## Overview

The Dowel-Steek Security Suite is a comprehensive password manager and TOTP authenticator built with D and DlangUI. It provides secure storage for passwords and generates time-based one-time passwords for two-factor authentication.

## Features

### Password Manager
- **Secure Storage**: Passwords encrypted with PBKDF2 + AES-like encryption
- **Password Generation**: Customizable strong password generation
- **Organization**: Categories, tags, favorites, and search functionality
- **Security Analysis**: Password strength checking and security reports
- **Import/Export**: Backup and restore functionality
- **Auto-fill Ready**: Copy passwords and usernames to clipboard

### TOTP Authenticator
- **2FA Codes**: Generate time-based one-time passwords
- **QR Code Support**: Add accounts by scanning QR codes or pasting otpauth:// URLs
- **Multiple Algorithms**: Supports SHA1, SHA256, SHA512
- **Real-time Updates**: Codes update automatically with progress indicators
- **Backup/Restore**: Export and import authenticator data securely

## Building and Running

### Prerequisites
- DMD compiler (D language)
- DUB package manager
- SDL2 development libraries
- FreeType library (for font rendering)

### Building
```bash
# Clone the repository
cd Dowel-Steek

# Build the security application
dub build --config=security_app

# Run the application
./dowel-steek-security
```

### Alternative Configurations
```bash
# Build individual components
dub build --config=desktop          # Main desktop environment
dub build --config=chatgpt_viewer   # ChatGPT conversation viewer
dub build --config=bridge_editor    # 3D bridge editor
```

## Usage Examples

### Password Manager

#### Creating Your First Vault
1. Launch the security suite
2. Click "Unlock" or go to File → Unlock Vault
3. Enter a strong master password
4. The vault will be created automatically at `~/.dowel-steek/vault.dsv`

#### Adding Password Entries
```d
// Programmatic example (for testing)
import security.password_manager.vault;

auto entry = VaultEntry("GitHub");
entry.username = "myusername";
entry.email = "user@example.com";
entry.password = "super-secure-password";
entry.url = "https://github.com";
entry.category = "Development";
entry.tags = ["code", "work"];
entry.notes = "Main development account";

vault.addEntry(entry);
```

#### Password Generation
```d
import security.crypto;

// Generate a strong password
auto options = PasswordGenerator.Options();
options.length = 16;
options.charsets = PasswordGenerator.CharsetType.All;
options.excludeSimilar = true;

string password = PasswordGenerator.generate(options);
writeln("Generated password: ", password);

// Generate a memorable passphrase
string passphrase = PasswordGenerator.generatePassphrase(4, "-");
writeln("Passphrase: ", passphrase);
```

#### Security Analysis
```d
import security.crypto;

// Analyze password strength
auto analysis = PasswordStrength.analyze("MyPassword123!");
writefln("Strength: %s (Score: %d)", analysis.level, analysis.score);

foreach (weakness; analysis.weaknesses)
    writeln("Weakness: ", weakness);

foreach (suggestion; analysis.suggestions)
    writeln("Suggestion: ", suggestion);
```

### TOTP Authenticator

#### Adding TOTP Accounts
```d
import security.authenticator.totp;

// Add account manually
auto account = TOTPAccount("Google", "user@gmail.com", "JBSWY3DPEHPK3PXP");
authenticator.addAccount(account);

// Add from QR code URL
string qrUrl = "otpauth://totp/Google:user@gmail.com?secret=JBSWY3DPEHPK3PXP&issuer=Google";
authenticator.addAccountFromUrl(qrUrl);
```

#### Generating TOTP Codes
```d
// Generate current code
auto account = authenticator.getAccount(accountId);
string code = account.generateCode();
writeln("Current code: ", code);

// Check remaining time
int remaining = account.getRemainingSeconds();
writefln("Code expires in %d seconds", remaining);

// Validate a code (useful for testing)
bool valid = account.validateCode("123456");
writeln("Code is valid: ", valid);
```

## File Locations

### Default Storage Locations
- Vault file: `~/.dowel-steek/vault.dsv`
- Authenticator file: `~/.dowel-steek/authenticator.dsa`
- Backup files: `~/.dowel-steek/backups/`
- Configuration: `~/.dowel-steek/config.json`

### File Formats
- Vault files (`.dsv`): Encrypted JSON containing password entries
- Authenticator files (`.dsa`): Encrypted JSON containing TOTP accounts
- Backup files: Plain JSON exports (for manual backup only)

## Security Features

### Encryption
- **Algorithm**: PBKDF2-HMAC-SHA256 for key derivation
- **Key Stretching**: 100,000 iterations minimum
- **Salt**: 32-byte random salt per file
- **Nonce**: 16-byte random nonce per encryption

### Memory Protection
- Secure string handling with memory clearing
- Constant-time password comparison
- Automatic memory cleanup on vault lock

### Best Practices Enforced
- Minimum password requirements
- Duplicate password detection
- Password age tracking
- 2FA recommendations
- Regular security reports

## Testing

### Unit Tests
```bash
# Run all tests
dub test

# Run specific test modules
dub test --config=unittest -- --filter="crypto"
dub test --config=unittest -- --filter="vault"
dub test --config=unittest -- --filter="totp"
```

### Manual Testing Script
```d
#!/usr/bin/env dub
/+ dub.sdl:
dependency "dowel-steek-suite" path="."
+/

import std.stdio;
import security.crypto;
import security.password_manager.vault;
import security.authenticator.totp;

void main()
{
    writeln("=== Dowel-Steek Security Suite Test ===");
    
    // Test password generation
    testPasswordGeneration();
    
    // Test TOTP generation
    testTOTPGeneration();
    
    // Test vault operations
    testVaultOperations();
    
    writeln("\n=== All Tests Completed ===");
}

void testPasswordGeneration()
{
    writeln("\n--- Testing Password Generation ---");
    
    auto options = PasswordGenerator.Options();
    options.length = 12;
    
    string password = PasswordGenerator.generate(options);
    writeln("Generated password: ", password);
    
    auto analysis = PasswordStrength.analyze(password);
    writefln("Strength: %s (Score: %d)", analysis.level, analysis.score);
}

void testTOTPGeneration()
{
    writeln("\n--- Testing TOTP Generation ---");
    
    // Test with a known secret
    string secret = "JBSWY3DPEHPK3PXP"; // "Hello World" in base32
    auto generator = TOTPGenerator(secret);
    
    string code = generator.generateCode();
    writeln("TOTP code: ", code);
    writeln("Remaining seconds: ", generator.getRemainingSeconds());
    
    // Test validation
    bool valid = generator.validateCode(code);
    writeln("Code validation: ", valid);
}

void testVaultOperations()
{
    writeln("\n--- Testing Vault Operations ---");
    
    // Create temporary vault
    string testPath = "/tmp/test_vault.dsv";
    auto vault = new PasswordVault(testPath);
    
    // Test unlock with new vault
    bool unlocked = vault.unlock("test-password-123");
    writeln("Vault unlock: ", unlocked);
    
    if (unlocked)
    {
        // Add test entry
        auto entry = VaultEntry("Test Service");
        entry.username = "testuser";
        entry.password = "test-password";
        entry.url = "https://example.com";
        
        string entryId = vault.addEntry(entry);
        writeln("Added entry with ID: ", entryId);
        
        // Search entries
        auto entries = vault.searchEntries();
        writefln("Found %d entries", entries.length);
        
        // Generate security report
        auto report = vault.generateSecurityReport();
        writefln("Security score: %d/100", report.overallScore);
        
        vault.save();
        writeln("Vault saved successfully");
    }
    
    // Clean up test file
    import std.file;
    if (exists(testPath))
        remove(testPath);
}
```

### Running the Test
```bash
# Make the test script executable and run it
chmod +x test_security.d
./test_security.d
```

## GUI Usage

### Keyboard Shortcuts
- `Ctrl+N`: New entry/account
- `Ctrl+F`: Focus search box
- `Ctrl+C`: Copy password/code
- `Ctrl+L`: Lock vault/authenticator
- `F5`: Refresh list
- `Delete`: Delete selected entry/account

### Context Menus
- Right-click entries for quick actions
- Copy username, password, or URL
- Mark as favorite
- Edit or delete entries

### Drag and Drop
- Drag entries between categories
- Drag text to create new entries
- Export entries by dragging to file manager

## Import/Export

### Supported Formats
- **Bitwarden JSON**: Import existing Bitwarden vaults
- **1Password CSV**: Import 1Password exports
- **Generic CSV**: Standard username/password/url format
- **TOTP URI**: Standard otpauth:// URLs for authenticator

### Export Commands
```bash
# Export vault (GUI menu: File → Export)
# Creates encrypted backup with timestamp
# Example: vault_backup_2024-01-01_12-00-00.json

# Import vault (GUI menu: File → Import)
# Supports merging with existing entries
```

## Troubleshooting

### Common Issues

1. **"Failed to create main window"**
   - Install SDL2 development packages
   - Check display environment variables

2. **"Invalid password" on unlock**
   - Ensure correct master password
   - Check file permissions on vault files

3. **TOTP codes not generating**
   - Verify secret is valid base32
   - Check system time synchronization

4. **GUI not responding**
   - Close and restart application
   - Check for corrupted configuration files

### Debug Mode
```bash
# Run with debug logging
DLANGUI_DEBUG=1 ./dowel-steek-security

# Enable verbose crypto debugging
DEBUG_CRYPTO=1 ./dowel-steek-security
```

### Recovery Options
- Vault recovery from backup files
- Manual secret extraction (for emergencies)
- Password reset (requires backup of entries)

## Contributing

### Development Setup
```bash
git clone https://github.com/your-repo/dowel-steek
cd Dowel-Steek
dub upgrade
dub build --config=security_app
```

### Code Style
- Follow D language conventions
- Document all public APIs
- Include unit tests for new features
- Use meaningful variable names
- Keep functions focused and small

### Security Considerations
- All cryptographic operations must be reviewed
- Sensitive data should be cleared from memory
- Input validation required for all user data
- Constant-time comparisons for passwords/secrets

## License

This software is proprietary to the Dowel-Steek project. See LICENSE file for details.

## Support

For issues and questions:
- Check the troubleshooting section above
- Review the source code documentation
- Create an issue in the project repository