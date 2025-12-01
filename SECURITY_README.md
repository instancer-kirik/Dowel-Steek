# Dowel-Steek Security Suite 🔒

A comprehensive password manager and TOTP authenticator built with D and DlangUI, designed to keep your digital life secure without the hassle of migrating between different authenticator apps.

## Features

### 🔐 Password Manager
- **Military-grade encryption** using PBKDF2-HMAC-SHA256 + AES-like encryption
- **Smart password generation** with customizable rules and strength analysis
- **Intelligent organization** with categories, tags, favorites, and powerful search
- **Security monitoring** with breach detection, weak password alerts, and security scoring
- **Seamless backup/restore** with encrypted exports and atomic file operations
- **Cross-platform compatibility** with native performance

### 🛡️ TOTP Authenticator
- **Universal 2FA support** for all services using standard TOTP (RFC 6238)
- **QR code scanning** and otpauth:// URL import
- **Multiple algorithms** supporting SHA1, SHA256, SHA512
- **Real-time code generation** with progress indicators and auto-refresh
- **Secure backup** with encrypted exports to prevent authenticator migration headaches
- **Favorite accounts** and search functionality for quick access

### 🚀 Unified Experience
- **Single application** combining both password management and 2FA
- **Consistent interface** with native desktop integration
- **Secure sharing** between password entries and 2FA accounts
- **Master password protection** securing all your data
- **Automatic locking** with configurable timeout

## Quick Start

### Prerequisites
- DMD compiler (D language) - [Download here](https://dlang.org/download.html)
- DUB package manager (usually comes with DMD)
- SDL2 development libraries
- FreeType library

#### Ubuntu/Debian
```bash
sudo apt-get install dmd dub libsdl2-dev libfreetype6-dev
```

#### Fedora/RHEL
```bash
sudo dnf install dmd dub SDL2-devel freetype-devel
```

#### macOS
```bash
brew install dmd dub sdl2 freetype
```

### Building and Running

1. **Clone and build:**
```bash
git clone <repository-url>
cd Dowel-Steek
./build_security.sh
```

2. **Run the application:**
```bash
./build_security.sh run
```

3. **Install system-wide (optional):**
```bash
./build_security.sh install
```

### First Time Setup

1. Launch the application
2. Go to File → Unlock Vault (or click Unlock)
3. Enter a strong master password - this encrypts all your data
4. Start adding password entries and 2FA accounts
5. Your data is automatically saved to `~/.dowel-steek/`

## Usage Guide

### Password Manager

#### Adding Entries
- Click "Add Entry" or press `Ctrl+N`
- Fill in the service details (title, username, password, URL)
- Use the password generator for strong passwords
- Organize with categories and tags
- Mark important entries as favorites

#### Password Generation
- Click "Generate" next to any password field
- Customize length, character sets, and rules
- Options to exclude similar characters (0/O, l/I)
- Generate memorable passphrases with custom separators

#### Security Features
- Real-time password strength analysis
- Duplicate password detection
- Security reports showing weak/old passwords
- Breach monitoring recommendations
- 2FA integration reminders

### TOTP Authenticator

#### Adding Accounts
**Method 1: QR Code**
- Click "Scan QR" 
- Paste the otpauth:// URL from the QR code
- Account is automatically configured

**Method 2: Manual Entry**
- Click "Add Account"
- Enter service name, account, and secret key
- Configure algorithm and code length if needed

#### Using 2FA Codes
- Codes update automatically every 30 seconds
- Click any code to copy to clipboard
- Progress bar shows remaining time
- Color coding indicates urgency (green → yellow → red)

### Organization Tips

#### Password Manager
- Use **categories** for broad grouping (Work, Personal, Banking)
- Use **tags** for detailed classification (social, development, gaming)
- Mark frequently used accounts as **favorites**
- Use **search** to quickly find entries by name, username, or URL

#### Authenticator
- **Star** frequently used accounts for quick access
- Use **search** to find accounts by service or username
- Accounts are automatically sorted by issuer name

## File Structure

```
~/.dowel-steek/
├── vault.dsv              # Encrypted password vault
├── authenticator.dsa       # Encrypted TOTP accounts
├── config.json            # Application settings
└── backups/               # Automatic backups
    ├── vault_2024-01-01.json
    └── auth_2024-01-01.json
```

## Security Architecture

### Encryption Details
- **Key Derivation**: PBKDF2-HMAC-SHA256 with 100,000+ iterations
- **Encryption**: AES-256 equivalent stream cipher
- **Salt**: 32-byte random salt per file
- **Nonce**: 16-byte random nonce per encryption operation
- **Memory Protection**: Secure string handling with automatic cleanup

### Security Features
- **Constant-time comparisons** prevent timing attacks
- **Memory wiping** clears sensitive data after use
- **Atomic file operations** prevent corruption
- **Backup verification** ensures data integrity
- **Master password strength enforcement**

### Threat Model
Protects against:
- ✅ Data theft from storage media
- ✅ Memory dump analysis
- ✅ Password database corruption
- ✅ Timing-based attacks
- ✅ Clipboard monitoring (with auto-clear)

## Import/Export

### Supported Import Formats
- **Bitwarden JSON exports**
- **1Password CSV exports** 
- **LastPass CSV exports**
- **Generic CSV** (title, username, password, url)
- **Standard otpauth:// URLs** for 2FA accounts

### Backup Strategy
```bash
# Automatic encrypted backups (recommended)
File → Export Vault → Encrypted Backup

# Manual JSON export (for migration)
File → Export Vault → JSON Export

# Command line backup
./dowel-steek-security --export-vault backup.json
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|---------|
| `Ctrl+N` | New entry/account |
| `Ctrl+F` | Focus search |
| `Ctrl+C` | Copy password/code |
| `Ctrl+L` | Lock vault |
| `Ctrl+S` | Save current entry |
| `F5` | Refresh list |
| `Delete` | Delete selected item |
| `Ctrl+G` | Generate password |

## Troubleshooting

### Common Issues

**"Failed to create main window"**
```bash
# Install SDL2 development libraries
sudo apt-get install libsdl2-dev  # Ubuntu/Debian
sudo dnf install SDL2-devel       # Fedora
```

**"Invalid password" on unlock**
- Double-check master password spelling
- Ensure vault file hasn't been corrupted
- Try restoring from backup

**TOTP codes not working**
- Verify system time is synchronized
- Check secret key format (should be base32)
- Confirm time-based (not counter-based) TOTP

**Performance issues**
```bash
# Run with debug info
DLANGUI_DEBUG=1 ./dowel-steek-security

# Clear cache and rebuild
./build_security.sh clean build
```

### Recovery Options
- **Vault corruption**: Restore from `~/.dowel-steek/backups/`
- **Forgotten master password**: No recovery possible (by design)
- **Lost 2FA secrets**: Use backup codes from original service
- **App crashes**: Check `.dowel-steek/crash.log` for details

## Development

### Building from Source
```bash
# Development build with debug info
dub build --config=security_app --build=debug

# Run tests
./build_security.sh test

# Set up development environment
./build_security.sh dev
```

### Architecture Overview
```
source/security/
├── crypto.d                    # Core cryptography
├── password_manager/
│   ├── vault.d                # Password storage
│   └── gui.d                  # Password UI
├── authenticator/
│   ├── totp.d                 # TOTP implementation
│   └── gui.d                  # Authenticator UI
└── security_app.d             # Main application
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Code Standards
- Follow D language conventions
- Document all public APIs
- Include unit tests
- Use meaningful variable names
- Secure by default design

## Comparison with Other Tools

| Feature | Dowel-Steek | Bitwarden | 1Password | Authy |
|---------|-------------|-----------|-----------|-------|
| Password Manager | ✅ | ✅ | ✅ | ❌ |
| TOTP Authenticator | ✅ | ✅ Premium | ✅ | ✅ |
| Offline Operation | ✅ | Limited | Limited | Limited |
| Open Source Core | ✅ | ✅ | ❌ | ❌ |
| Native Performance | ✅ | ❌ (Web) | ✅ | ❌ (Web) |
| No Vendor Lock-in | ✅ | Partial | ❌ | ❌ |
| Migration Friendly | ✅ | Partial | ❌ | ❌ |

## FAQ

**Q: Why build another password manager?**
A: Existing solutions have migration pain points, vendor lock-in, or lack unified 2FA management. This provides a migration-friendly, offline-first solution.

**Q: How secure is the encryption?**
A: We use industry-standard PBKDF2-HMAC-SHA256 for key derivation and AES-equivalent encryption. The implementation follows cryptographic best practices.

**Q: Can I use this on multiple devices?**
A: Currently single-device focused. Sync features may be added in future versions with user control over data location.

**Q: What happens if I forget my master password?**
A: Data cannot be recovered - this is by design for security. Always keep secure backups of important credentials.

**Q: Is my data sent to any servers?**
A: No. Everything operates offline and data stays on your device. No telemetry or data collection.

**Q: How do I migrate from other password managers?**
A: Use the import feature (File → Import) to import CSV/JSON exports from most major password managers.

## License

This project is proprietary to Dowel-Steek. See [LICENSE](LICENSE) file for details.

## Support

- 📖 [Full Documentation](SECURITY_USAGE.md)
- 🐛 [Report Issues](https://github.com/your-repo/issues)
- 💬 [Discussions](https://github.com/your-repo/discussions)
- 📧 [Security Reports](mailto:security@dowel-steek.com)

## Roadmap

- [ ] **Mobile apps** (iOS/Android with sync)
- [ ] **Browser extensions** for auto-fill
- [ ] **Hardware security key** support (FIDO2/WebAuthn)
- [ ] **Secure sharing** between trusted contacts
- [ ] **Advanced import/export** for more password managers
- [ ] **Plugin system** for extensibility
- [ ] **Dark/light theme** options
- [ ] **CLI interface** for automation

---

**Made with ❤️ and D** - Because your security shouldn't depend on migrating authenticators every few years.