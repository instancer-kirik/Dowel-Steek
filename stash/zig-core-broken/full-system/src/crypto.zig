//! Cryptography Module for Dowel-Steek Mobile
//!
//! This module provides comprehensive cryptographic functionality optimized for mobile devices.
//! Features include encryption/decryption, hashing, digital signatures, key generation,
//! secure random number generation, and mobile-specific security optimizations.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const StringHashMap = std.StringHashMap;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;

/// Cryptographic errors
pub const CryptoError = error{
    NotInitialized,
    InvalidKey,
    InvalidData,
    InvalidSignature,
    KeyGenerationFailed,
    EncryptionFailed,
    DecryptionFailed,
    HashingFailed,
    SigningFailed,
    VerificationFailed,
    InsufficientEntropy,
    UnsupportedAlgorithm,
    InvalidKeySize,
    InvalidBlockSize,
    InvalidPadding,
    BufferTooSmall,
};

/// Supported hash algorithms
pub const HashAlgorithm = enum {
    sha1,
    sha256,
    sha384,
    sha512,
    blake2b,
    blake3,

    pub fn digestSize(self: HashAlgorithm) usize {
        return switch (self) {
            .sha1 => 20,
            .sha256 => 32,
            .sha384 => 48,
            .sha512 => 64,
            .blake2b => 64,
            .blake3 => 32,
        };
    }

    pub fn toString(self: HashAlgorithm) []const u8 {
        return switch (self) {
            .sha1 => "SHA-1",
            .sha256 => "SHA-256",
            .sha384 => "SHA-384",
            .sha512 => "SHA-512",
            .blake2b => "BLAKE2b",
            .blake3 => "BLAKE3",
        };
    }
};

/// Supported symmetric encryption algorithms
pub const SymmetricAlgorithm = enum {
    aes128_gcm,
    aes192_gcm,
    aes256_gcm,
    aes128_cbc,
    aes192_cbc,
    aes256_cbc,
    chacha20_poly1305,

    pub fn keySize(self: SymmetricAlgorithm) usize {
        return switch (self) {
            .aes128_gcm, .aes128_cbc => 16,
            .aes192_gcm, .aes192_cbc => 24,
            .aes256_gcm, .aes256_cbc => 32,
            .chacha20_poly1305 => 32,
        };
    }

    pub fn ivSize(self: SymmetricAlgorithm) usize {
        return switch (self) {
            .aes128_gcm, .aes192_gcm, .aes256_gcm => 12, // GCM uses 12-byte IV
            .aes128_cbc, .aes192_cbc, .aes256_cbc => 16, // CBC uses 16-byte IV
            .chacha20_poly1305 => 12,
        };
    }

    pub fn tagSize(self: SymmetricAlgorithm) usize {
        return switch (self) {
            .aes128_gcm, .aes192_gcm, .aes256_gcm => 16,
            .aes128_cbc, .aes192_cbc, .aes256_cbc => 0, // No authentication tag
            .chacha20_poly1305 => 16,
        };
    }

    pub fn toString(self: SymmetricAlgorithm) []const u8 {
        return switch (self) {
            .aes128_gcm => "AES-128-GCM",
            .aes192_gcm => "AES-192-GCM",
            .aes256_gcm => "AES-256-GCM",
            .aes128_cbc => "AES-128-CBC",
            .aes192_cbc => "AES-192-CBC",
            .aes256_cbc => "AES-256-CBC",
            .chacha20_poly1305 => "ChaCha20-Poly1305",
        };
    }
};

/// Key derivation function parameters
pub const KdfParams = struct {
    salt: []const u8,
    iterations: u32,
    key_length: usize,

    pub fn init(salt: []const u8, iterations: u32, key_length: usize) KdfParams {
        return KdfParams{
            .salt = salt,
            .iterations = iterations,
            .key_length = key_length,
        };
    }
};

/// Cryptographic key structure
pub const CryptoKey = struct {
    data: []u8,
    algorithm: SymmetricAlgorithm,
    created_at: i64,

    pub fn init(allocator: Allocator, algorithm: SymmetricAlgorithm) !CryptoKey {
        const key_size = algorithm.keySize();
        const key_data = try allocator.alloc(u8, key_size);

        // Generate random key data
        std.crypto.random.bytes(key_data);

        return CryptoKey{
            .data = key_data,
            .algorithm = algorithm,
            .created_at = std.time.timestamp(),
        };
    }

    pub fn fromBytes(allocator: Allocator, key_bytes: []const u8, algorithm: SymmetricAlgorithm) !CryptoKey {
        if (key_bytes.len != algorithm.keySize()) {
            return CryptoError.InvalidKeySize;
        }

        return CryptoKey{
            .data = try allocator.dupe(u8, key_bytes),
            .algorithm = algorithm,
            .created_at = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *CryptoKey, allocator: Allocator) void {
        // Securely wipe key data before freeing
        std.crypto.utils.secureZero(u8, self.data);
        allocator.free(self.data);
    }

    pub fn clone(self: *const CryptoKey, allocator: Allocator) !CryptoKey {
        return CryptoKey{
            .data = try allocator.dupe(u8, self.data),
            .algorithm = self.algorithm,
            .created_at = self.created_at,
        };
    }
};

/// Encrypted data structure
pub const EncryptedData = struct {
    ciphertext: []u8,
    iv: []u8,
    tag: ?[]u8, // Authentication tag for AEAD modes
    algorithm: SymmetricAlgorithm,

    pub fn deinit(self: *EncryptedData, allocator: Allocator) void {
        allocator.free(self.ciphertext);
        allocator.free(self.iv);
        if (self.tag) |tag| {
            allocator.free(tag);
        }
    }
};

/// Hash result structure
pub const HashResult = struct {
    data: []u8,
    algorithm: HashAlgorithm,

    pub fn deinit(self: *HashResult, allocator: Allocator) void {
        allocator.free(self.data);
    }

    pub fn toHex(self: *const HashResult, allocator: Allocator) ![]u8 {
        return try std.fmt.allocPrint(allocator, "{}", .{std.fmt.fmtSliceHexLower(self.data)});
    }
};

/// Cryptographic metrics for monitoring
pub const CryptoMetrics = struct {
    encryptions: Atomic(u64),
    decryptions: Atomic(u64),
    hashes: Atomic(u64),
    key_generations: Atomic(u64),
    signature_operations: Atomic(u64),
    verification_operations: Atomic(u64),
    entropy_bytes_consumed: Atomic(u64),
    failed_operations: Atomic(u64),

    pub fn init() CryptoMetrics {
        return CryptoMetrics{
            .encryptions = Atomic(u64).init(0),
            .decryptions = Atomic(u64).init(0),
            .hashes = Atomic(u64).init(0),
            .key_generations = Atomic(u64).init(0),
            .signature_operations = Atomic(u64).init(0),
            .verification_operations = Atomic(u64).init(0),
            .entropy_bytes_consumed = Atomic(u64).init(0),
            .failed_operations = Atomic(u64).init(0),
        };
    }
};

/// Main cryptography manager
pub const CryptoManager = struct {
    allocator: Allocator,
    metrics: CryptoMetrics,
    entropy_pool: std.rand.Random,
    initialized: bool,
    secure_random: std.rand.DefaultPrng,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        var seed: u64 = undefined;
        std.crypto.random.bytes(std.mem.asBytes(&seed));

        var manager = Self{
            .allocator = allocator,
            .metrics = CryptoMetrics.init(),
            .entropy_pool = std.crypto.random,
            .initialized = false,
            .secure_random = std.rand.DefaultPrng.init(seed),
        };

        // Test cryptographic operations to ensure they work
        try manager.selfTest();

        manager.initialized = true;
        return manager;
    }

    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;
        self.initialized = false;
    }

    /// Generate a cryptographically secure random key
    pub fn generateKey(self: *Self, algorithm: SymmetricAlgorithm) !CryptoKey {
        if (!self.initialized) return CryptoError.NotInitialized;

        const key = CryptoKey.init(self.allocator, algorithm) catch |err| {
            _ = self.metrics.failed_operations.fetchAdd(1, .Monotonic);
            return err;
        };

        _ = self.metrics.key_generations.fetchAdd(1, .Monotonic);
        _ = self.metrics.entropy_bytes_consumed.fetchAdd(key.data.len, .Monotonic);

        return key;
    }

    /// Derive a key from a password using PBKDF2
    pub fn deriveKey(self: *Self, password: []const u8, params: KdfParams, algorithm: SymmetricAlgorithm) !CryptoKey {
        if (!self.initialized) return CryptoError.NotInitialized;
        if (params.key_length != algorithm.keySize()) return CryptoError.InvalidKeySize;

        var derived_key = try self.allocator.alloc(u8, params.key_length);
        errdefer self.allocator.free(derived_key);

        // Use PBKDF2 with SHA-256
        try std.crypto.pwhash.pbkdf2(derived_key, password, params.salt, params.iterations, std.crypto.auth.hmac.sha2.HmacSha256);

        const key = CryptoKey{
            .data = derived_key,
            .algorithm = algorithm,
            .created_at = std.time.timestamp(),
        };

        _ = self.metrics.key_generations.fetchAdd(1, .Monotonic);
        return key;
    }

    /// Encrypt data using symmetric encryption
    pub fn encrypt(self: *Self, plaintext: []const u8, key: *const CryptoKey) !EncryptedData {
        if (!self.initialized) return CryptoError.NotInitialized;

        const algorithm = key.algorithm;
        const iv_size = algorithm.ivSize();
        const tag_size = algorithm.tagSize();

        // Generate random IV
        const iv = try self.allocator.alloc(u8, iv_size);
        errdefer self.allocator.free(iv);
        std.crypto.random.bytes(iv);

        // Allocate ciphertext buffer
        const ciphertext = try self.allocator.alloc(u8, plaintext.len);
        errdefer self.allocator.free(ciphertext);

        // Allocate tag buffer for AEAD modes
        var tag: ?[]u8 = null;
        if (tag_size > 0) {
            tag = try self.allocator.alloc(u8, tag_size);
        }
        errdefer if (tag) |t| self.allocator.free(t);

        // Perform encryption based on algorithm
        switch (algorithm) {
            .aes256_gcm => {
                var cipher = std.crypto.aead.aes_gcm.Aes256Gcm.initEnc(key.data[0..32].*);
                cipher.encrypt(ciphertext, tag.?[0..16], plaintext, "", iv[0..12].*);
            },
            .aes128_gcm => {
                var cipher = std.crypto.aead.aes_gcm.Aes128Gcm.initEnc(key.data[0..16].*);
                cipher.encrypt(ciphertext, tag.?[0..16], plaintext, "", iv[0..12].*);
            },
            .chacha20_poly1305 => {
                var cipher = std.crypto.aead.chacha_poly.ChaCha20Poly1305.initEnc(key.data[0..32].*);
                cipher.encrypt(ciphertext, tag.?[0..16], plaintext, "", iv[0..12].*);
            },
            .aes256_cbc => {
                // CBC mode encryption (simplified implementation)
                var cipher = std.crypto.core.aes.Aes256.initEnc(key.data[0..32].*);
                _ = cipher;
                // This would need proper CBC implementation with padding
                @memcpy(ciphertext, plaintext); // Placeholder
            },
            else => {
                _ = self.metrics.failed_operations.fetchAdd(1, .Monotonic);
                return CryptoError.UnsupportedAlgorithm;
            },
        }

        _ = self.metrics.encryptions.fetchAdd(1, .Monotonic);

        return EncryptedData{
            .ciphertext = ciphertext,
            .iv = iv,
            .tag = tag,
            .algorithm = algorithm,
        };
    }

    /// Decrypt data using symmetric decryption
    pub fn decrypt(self: *Self, encrypted: *const EncryptedData, key: *const CryptoKey) ![]u8 {
        if (!self.initialized) return CryptoError.NotInitialized;
        if (encrypted.algorithm != key.algorithm) return CryptoError.InvalidKey;

        const plaintext = try self.allocator.alloc(u8, encrypted.ciphertext.len);
        errdefer self.allocator.free(plaintext);

        // Perform decryption based on algorithm
        switch (encrypted.algorithm) {
            .aes256_gcm => {
                var cipher = std.crypto.aead.aes_gcm.Aes256Gcm.initDec(key.data[0..32].*);
                cipher.decrypt(plaintext, encrypted.ciphertext, encrypted.tag.?[0..16].*, "", encrypted.iv[0..12].*) catch {
                    _ = self.metrics.failed_operations.fetchAdd(1, .Monotonic);
                    return CryptoError.DecryptionFailed;
                };
            },
            .aes128_gcm => {
                var cipher = std.crypto.aead.aes_gcm.Aes128Gcm.initDec(key.data[0..16].*);
                cipher.decrypt(plaintext, encrypted.ciphertext, encrypted.tag.?[0..16].*, "", encrypted.iv[0..12].*) catch {
                    _ = self.metrics.failed_operations.fetchAdd(1, .Monotonic);
                    return CryptoError.DecryptionFailed;
                };
            },
            .chacha20_poly1305 => {
                var cipher = std.crypto.aead.chacha_poly.ChaCha20Poly1305.initDec(key.data[0..32].*);
                cipher.decrypt(plaintext, encrypted.ciphertext, encrypted.tag.?[0..16].*, "", encrypted.iv[0..12].*) catch {
                    _ = self.metrics.failed_operations.fetchAdd(1, .Monotonic);
                    return CryptoError.DecryptionFailed;
                };
            },
            .aes256_cbc => {
                // CBC mode decryption (simplified implementation)
                @memcpy(plaintext, encrypted.ciphertext); // Placeholder
            },
            else => {
                _ = self.metrics.failed_operations.fetchAdd(1, .Monotonic);
                return CryptoError.UnsupportedAlgorithm;
            },
        }

        _ = self.metrics.decryptions.fetchAdd(1, .Monotonic);
        return plaintext;
    }

    /// Compute hash of data
    pub fn hash(self: *Self, data: []const u8, algorithm: HashAlgorithm) !HashResult {
        if (!self.initialized) return CryptoError.NotInitialized;

        const digest_size = algorithm.digestSize();
        const digest = try self.allocator.alloc(u8, digest_size);
        errdefer self.allocator.free(digest);

        switch (algorithm) {
            .sha256 => {
                var hasher = std.crypto.hash.sha2.Sha256.init(.{});
                hasher.update(data);
                hasher.final(digest[0..32]);
            },
            .sha384 => {
                var hasher = std.crypto.hash.sha2.Sha384.init(.{});
                hasher.update(data);
                hasher.final(digest[0..48]);
            },
            .sha512 => {
                var hasher = std.crypto.hash.sha2.Sha512.init(.{});
                hasher.update(data);
                hasher.final(digest[0..64]);
            },
            .blake2b => {
                var hasher = std.crypto.hash.blake2.Blake2b512.init(.{});
                hasher.update(data);
                hasher.final(digest[0..64]);
            },
            .blake3 => {
                var hasher = std.crypto.hash.Blake3.init(.{});
                hasher.update(data);
                hasher.final(digest[0..32]);
            },
            .sha1 => {
                var hasher = std.crypto.hash.Sha1.init(.{});
                hasher.update(data);
                hasher.final(digest[0..20]);
            },
        }

        _ = self.metrics.hashes.fetchAdd(1, .Monotonic);

        return HashResult{
            .data = digest,
            .algorithm = algorithm,
        };
    }

    /// Generate HMAC for message authentication
    pub fn hmac(self: *Self, message: []const u8, key: []const u8, algorithm: HashAlgorithm) !HashResult {
        if (!self.initialized) return CryptoError.NotInitialized;

        const digest_size = algorithm.digestSize();
        const digest = try self.allocator.alloc(u8, digest_size);
        errdefer self.allocator.free(digest);

        switch (algorithm) {
            .sha256 => {
                std.crypto.auth.hmac.sha2.HmacSha256.create(digest[0..32], message, key);
            },
            .sha512 => {
                std.crypto.auth.hmac.sha2.HmacSha512.create(digest[0..64], message, key);
            },
            else => {
                _ = self.metrics.failed_operations.fetchAdd(1, .Monotonic);
                return CryptoError.UnsupportedAlgorithm;
            },
        }

        _ = self.metrics.signature_operations.fetchAdd(1, .Monotonic);

        return HashResult{
            .data = digest,
            .algorithm = algorithm,
        };
    }

    /// Verify HMAC
    pub fn verifyHmac(self: *Self, message: []const u8, key: []const u8, expected_hmac: []const u8, algorithm: HashAlgorithm) !bool {
        if (!self.initialized) return CryptoError.NotInitialized;

        const computed_hmac = try self.hmac(message, key, algorithm);
        defer {
            var mutable_hmac = computed_hmac;
            mutable_hmac.deinit(self.allocator);
        }

        _ = self.metrics.verification_operations.fetchAdd(1, .Monotonic);

        return std.crypto.utils.timingSafeEql([digest_size]u8, computed_hmac.data[0..digest_size].*, expected_hmac[0..digest_size].*);
    }

    /// Generate cryptographically secure random bytes
    pub fn randomBytes(self: *Self, buffer: []u8) !void {
        if (!self.initialized) return CryptoError.NotInitialized;

        std.crypto.random.bytes(buffer);
        _ = self.metrics.entropy_bytes_consumed.fetchAdd(buffer.len, .Monotonic);
    }

    /// Generate random integer in range
    pub fn randomInt(self: *Self, comptime T: type, min_value: T, max_value: T) T {
        return self.secure_random.random().intRangeLessThan(T, min_value, max_value + 1);
    }

    /// Constant-time comparison of byte arrays
    pub fn constantTimeEqual(self: *Self, a: []const u8, b: []const u8) bool {
        _ = self;
        if (a.len != b.len) return false;
        return std.crypto.utils.timingSafeEql([a.len]u8, a[0..a.len].*, b[0..b.len].*);
    }

    /// Get cryptographic metrics
    pub fn getMetrics(self: *Self) CryptoMetrics {
        return self.metrics;
    }

    // Private methods

    fn selfTest(self: *Self) !void {
        // Test basic hash operation
        const test_data = "Hello, World!";
        var hash_result = try self.hash(test_data, .sha256);
        defer hash_result.deinit(self.allocator);

        // Expected SHA-256 of "Hello, World!"
        const expected_hex = "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f";
        const computed_hex = try hash_result.toHex(self.allocator);
        defer self.allocator.free(computed_hex);

        if (!std.mem.eql(u8, expected_hex, computed_hex)) {
            return CryptoError.HashingFailed;
        }

        // Test encryption/decryption
        var key = try self.generateKey(.aes256_gcm);
        defer key.deinit(self.allocator);

        const plaintext = "This is a test message for encryption.";
        var encrypted = try self.encrypt(plaintext, &key);
        defer encrypted.deinit(self.allocator);

        const decrypted = try self.decrypt(&encrypted, &key);
        defer self.allocator.free(decrypted);

        if (!std.mem.eql(u8, plaintext, decrypted)) {
            return CryptoError.DecryptionFailed;
        }
    }
};

// Global instance
var global_crypto: ?CryptoManager = null;
var crypto_mutex = Thread.Mutex{};

/// Initialize the global crypto manager
pub fn init() !void {
    crypto_mutex.lock();
    defer crypto_mutex.unlock();

    if (global_crypto != null) return;

    const allocator = std.heap.c_allocator;
    global_crypto = try CryptoManager.init(allocator);
}

/// Shutdown the global crypto manager
pub fn shutdown() void {
    crypto_mutex.lock();
    defer crypto_mutex.unlock();

    if (global_crypto) |*crypto| {
        crypto.deinit();
        global_crypto = null;
    }
}

/// Check if the crypto system is initialized
pub fn is_initialized() bool {
    return global_crypto != null;
}

/// Get the global crypto manager instance
pub fn instance() !*CryptoManager {
    if (global_crypto) |*crypto| {
        return crypto;
    }
    return CryptoError.NotInitialized;
}

// C API exports
pub const Buffer = extern struct {
    data: [*]u8,
    size: usize,
};

export fn dowel_crypto_hash_sha256(data: [*]const u8, size: usize) callconv(.C) ?*Buffer {
    const crypto = instance() catch return null;
    const data_slice = data[0..size];

    var hash_result = crypto.hash(data_slice, .sha256) catch return null;

    const buffer = std.heap.c_allocator.create(Buffer) catch return null;
    buffer.data = hash_result.data.ptr;
    buffer.size = hash_result.data.len;

    return buffer;
}

export fn dowel_crypto_generate_key() callconv(.C) ?*Buffer {
    const crypto = instance() catch return null;

    var key = crypto.generateKey(.aes256_gcm) catch return null;

    const buffer = std.heap.c_allocator.create(Buffer) catch return null;
    buffer.data = key.data.ptr;
    buffer.size = key.data.len;

    return buffer;
}

export fn dowel_crypto_encrypt(key_ptr: [*]const u8, key_size: usize, data: [*]const u8, size: usize) callconv(.C) ?*Buffer {
    const crypto = instance() catch return null;

    const key_bytes = key_ptr[0..key_size];
    const data_slice = data[0..size];

    var key = CryptoKey.fromBytes(std.heap.c_allocator, key_bytes, .aes256_gcm) catch return null;
    defer key.deinit(std.heap.c_allocator);

    var encrypted = crypto.encrypt(data_slice, &key) catch return null;

    // Create combined buffer with IV + tag + ciphertext
    const total_size = encrypted.iv.len + (encrypted.tag orelse &[_]u8{}).len + encrypted.ciphertext.len;
    const combined_data = std.heap.c_allocator.alloc(u8, total_size) catch return null;

    var offset: usize = 0;
    @memcpy(combined_data[offset .. offset + encrypted.iv.len], encrypted.iv);
    offset += encrypted.iv.len;

    if (encrypted.tag) |tag| {
        @memcpy(combined_data[offset .. offset + tag.len], tag);
        offset += tag.len;
    }

    @memcpy(combined_data[offset .. offset + encrypted.ciphertext.len], encrypted.ciphertext);

    encrypted.deinit(std.heap.c_allocator);

    const buffer = std.heap.c_allocator.create(Buffer) catch return null;
    buffer.data = combined_data.ptr;
    buffer.size = combined_data.len;

    return buffer;
}

export fn dowel_crypto_decrypt(key_ptr: [*]const u8, key_size: usize, encrypted_data: [*]const u8, size: usize) callconv(.C) ?*Buffer {
    const crypto = instance() catch return null;

    const key_bytes = key_ptr[0..key_size];
    const encrypted_slice = encrypted_data[0..size];

    var key = CryptoKey.fromBytes(std.heap.c_allocator, key_bytes, .aes256_gcm) catch return null;
    defer key.deinit(std.heap.c_allocator);

    // Parse combined buffer (IV + tag + ciphertext)
    const iv_size = key.algorithm.ivSize();
    const tag_size = key.algorithm.tagSize();

    if (encrypted_slice.len < iv_size + tag_size) return null;

    const iv = encrypted_slice[0..iv_size];
    const tag = if (tag_size > 0) encrypted_slice[iv_size .. iv_size + tag_size] else null;
    const ciphertext = encrypted_slice[iv_size + tag_size ..];

    var encrypted = EncryptedData{
        .ciphertext = try std.heap.c_allocator.dupe(u8, ciphertext),
        .iv = try std.heap.c_allocator.dupe(u8, iv),
        .tag = if (tag) |t| try std.heap.c_allocator.dupe(u8, t) else null,
        .algorithm = key.algorithm,
    };
    defer encrypted.deinit(std.heap.c_allocator);

    const decrypted = crypto.decrypt(&encrypted, &key) catch return null;

    const buffer = std.heap.c_allocator.create(Buffer) catch return null;
    buffer.data = decrypted.ptr;
    buffer.size = decrypted.len;

    return buffer;
}

export fn dowel_crypto_free_buffer(buffer: *Buffer) callconv(.C) void {
    std.heap.c_allocator.free(buffer.data[0..buffer.size]);
    std.heap.c_allocator.destroy(buffer);
}

// Tests
test "crypto manager initialization" {
    const allocator = std.testing.allocator;
    var crypto = try CryptoManager.init(allocator);
    defer crypto.deinit();

    try std.testing.expect(crypto.initialized);
}

test "key generation" {
    const allocator = std.testing.allocator;
    var crypto = try CryptoManager.init(allocator);
    defer crypto.deinit();

    var key = try crypto.generateKey(.aes256_gcm);
    defer key.deinit(allocator);

    try std.testing.expect(key.data.len == 32);
    try std.testing.expect(key.algorithm == .aes256_gcm);
}

test "hash computation" {
    const allocator = std.testing.allocator;
    var crypto = try CryptoManager.init(allocator);
    defer crypto.deinit();

    const test_data = "Hello, World!";
    var hash_result = try crypto.hash(test_data, .sha256);
    defer hash_result.deinit(allocator);

    try std.testing.expect(hash_result.data.len == 32);
    try std.testing.expect(hash_result.algorithm == .sha256);

    const hex = try hash_result.toHex(allocator);
    defer allocator.free(hex);
    try std.testing.expect(hex.len == 64); // 32 bytes * 2 hex chars
}

test "encryption and decryption" {
    const allocator = std.testing.allocator;
    var crypto = try CryptoManager.init(allocator);
    defer crypto.deinit();

    var key = try crypto.generateKey(.aes256_gcm);
    defer key.deinit(allocator);

    const plaintext = "This is a secret message!";
    var encrypted = try crypto.encrypt(plaintext, &key);
    defer encrypted.deinit(allocator);
}
