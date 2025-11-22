//! Mobile Notifications Module
//! Handles push notifications, local notifications, and notification management
//! Optimized for battery life and user experience on mobile devices.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Error types for notification operations
pub const NotificationError = error{
    NotificationServiceUnavailable,
    PermissionDenied,
    InvalidNotificationId,
    PayloadTooLarge,
    InvalidPriority,
    ChannelNotFound,
    TokenRegistrationFailed,
    NetworkError,
    QuotaExceeded,
    InvalidFormat,
    ServiceTemporarilyUnavailable,
    OutOfMemory,
};

/// Notification priority levels
pub const NotificationPriority = enum(u8) {
    min = 0,
    low = 1,
    default = 2,
    high = 3,
    max = 4,

    pub fn toString(self: NotificationPriority) []const u8 {
        return switch (self) {
            .min => "min",
            .low => "low",
            .default => "default",
            .high => "high",
            .max => "max",
        };
    }
};

/// Notification visibility settings
pub const NotificationVisibility = enum(u8) {
    private = 0, // Show on all lockscreens, but conceal sensitive content
    public = 1, // Show on all lockscreens in their entirety
    secret = 2, // Don't reveal any content on lockscreen
};

/// Notification category for better system integration
pub const NotificationCategory = enum {
    alarm,
    call,
    email,
    err,
    event,
    message,
    navigation,
    progress,
    promo,
    recommendation,
    reminder,
    service,
    social,
    status,
    system,
    transport,

    pub fn toString(self: NotificationCategory) []const u8 {
        return switch (self) {
            .alarm => "alarm",
            .call => "call",
            .email => "email",
            .err => "error",
            .event => "event",
            .message => "message",
            .navigation => "navigation",
            .progress => "progress",
            .promo => "promo",
            .recommendation => "recommendation",
            .reminder => "reminder",
            .service => "service",
            .social => "social",
            .status => "status",
            .system => "system",
            .transport => "transport",
        };
    }
};

/// Notification action button
pub const NotificationAction = struct {
    id: []const u8,
    title: []const u8,
    icon: ?[]const u8 = null,
    requires_auth: bool = false,
    is_destructive: bool = false,
    input_placeholder: ?[]const u8 = null, // For text input actions
};

/// Rich media attachment
pub const NotificationAttachment = struct {
    id: []const u8,
    url: []const u8,
    type: enum { image, video, audio, file },
    thumbnail_url: ?[]const u8 = null,
    size: ?u64 = null,
    filename: ?[]const u8 = null,
};

/// Progress indicator for ongoing notifications
pub const NotificationProgress = struct {
    current: u32,
    max: u32,
    indeterminate: bool = false,
};

/// Notification channel for categorizing notifications
pub const NotificationChannel = struct {
    id: []const u8,
    name: []const u8,
    description: ?[]const u8 = null,
    importance: NotificationPriority,
    enable_badge: bool = true,
    enable_lights: bool = true,
    enable_sound: bool = true,
    enable_vibration: bool = true,
    light_color: u32 = 0xFF0000FF, // ARGB color
    sound_uri: ?[]const u8 = null,
    vibration_pattern: ?[]const u64 = null, // Milliseconds pattern
    lock_screen_visibility: NotificationVisibility = .private,
    can_bypass_dnd: bool = false, // Do Not Disturb bypass
    group_id: ?[]const u8 = null,
};

/// Main notification structure
pub const Notification = struct {
    const Self = @This();

    // Core identification
    id: []const u8,
    app_id: []const u8,
    channel_id: []const u8,

    // Content
    title: []const u8,
    body: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    icon: ?[]const u8 = null,
    large_icon: ?[]const u8 = null,
    image: ?[]const u8 = null,

    // Behavior
    priority: NotificationPriority = .default,
    category: NotificationCategory = .message,
    visibility: NotificationVisibility = .private,
    auto_cancel: bool = true,
    ongoing: bool = false,
    sticky: bool = false,

    // Timing
    timestamp: i64, // Unix timestamp in milliseconds
    timeout: ?i64 = null, // Auto-dismiss timeout in milliseconds
    schedule_time: ?i64 = null, // Future delivery time

    // Interaction
    actions: []const NotificationAction = &[_]NotificationAction{},
    reply_action: ?NotificationAction = null,
    click_action: ?[]const u8 = null, // Deep link or intent
    delete_action: ?[]const u8 = null,

    // Rich content
    attachments: []const NotificationAttachment = &[_]NotificationAttachment{},
    progress: ?NotificationProgress = null,

    // Grouping
    group_key: ?[]const u8 = null,
    group_summary: bool = false,
    sort_key: ?[]const u8 = null,

    // Platform-specific data
    custom_data: std.StringHashMap([]const u8),

    // Badge and count
    badge_count: ?u32 = null,
    number: ?u32 = null,

    pub fn init(allocator: Allocator, id: []const u8, app_id: []const u8, channel_id: []const u8, title: []const u8) !Self {
        return Self{
            .id = try allocator.dupe(u8, id),
            .app_id = try allocator.dupe(u8, app_id),
            .channel_id = try allocator.dupe(u8, channel_id),
            .title = try allocator.dupe(u8, title),
            .timestamp = std.time.milliTimestamp(),
            .custom_data = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.id);
        allocator.free(self.app_id);
        allocator.free(self.channel_id);
        allocator.free(self.title);
        if (self.body) |body| allocator.free(body);
        if (self.summary) |summary| allocator.free(summary);

        // Free actions
        for (self.actions) |action| {
            allocator.free(action.id);
            allocator.free(action.title);
            if (action.icon) |icon| allocator.free(icon);
            if (action.input_placeholder) |placeholder| allocator.free(placeholder);
        }
        allocator.free(self.actions);

        // Free attachments
        for (self.attachments) |attachment| {
            allocator.free(attachment.id);
            allocator.free(attachment.url);
            if (attachment.thumbnail_url) |thumb| allocator.free(thumb);
            if (attachment.filename) |filename| allocator.free(filename);
        }
        allocator.free(self.attachments);

        // Free custom data
        var iterator = self.custom_data.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.custom_data.deinit();
    }
};

/// Push notification registration token
pub const PushToken = struct {
    token: []const u8,
    service: enum { fcm, apns, custom },
    timestamp: i64,
    app_id: []const u8,
};

/// Notification statistics
pub const NotificationStats = struct {
    total_sent: u64,
    total_delivered: u64,
    total_clicked: u64,
    total_dismissed: u64,
    delivery_rate: f32,
    click_through_rate: f32,
    battery_impact: f32, // mAh consumed
    last_updated: i64,
};

/// Notification event types
pub const NotificationEvent = enum {
    delivered,
    clicked,
    dismissed,
    action_clicked,
    reply_sent,
    failed_delivery,
};

/// Notification event data
pub const NotificationEventData = struct {
    notification_id: []const u8,
    app_id: []const u8,
    event: NotificationEvent,
    timestamp: i64,
    action_id: ?[]const u8 = null,
    reply_text: ?[]const u8 = null,
    error_code: ?u32 = null,
    error_message: ?[]const u8 = null,
};

/// Notification callback function
pub const NotificationCallback = *const fn (event: NotificationEventData, userdata: ?*anyopaque) void;

/// Do Not Disturb settings
pub const DoNotDisturbSettings = struct {
    enabled: bool,
    allow_alarms: bool,
    allow_priority_interruptions: bool,
    allow_calls: bool,
    allow_messages: bool,
    allow_events: bool,
    quiet_hours_start: ?u16 = null, // Minutes from midnight (e.g., 22*60 for 10 PM)
    quiet_hours_end: ?u16 = null, // Minutes from midnight (e.g., 8*60 for 8 AM)
    weekend_mode: bool = false,
};

/// Main notification manager
pub const NotificationManager = struct {
    const Self = @This();
    const MAX_NOTIFICATIONS = 1000;
    const MAX_CHANNELS = 100;

    allocator: Allocator,
    notifications: std.ArrayList(Notification),
    channels: std.ArrayList(NotificationChannel),
    pending_notifications: std.ArrayList(Notification), // Scheduled notifications
    notification_history: std.ArrayList(NotificationEventData),
    push_tokens: std.ArrayList(PushToken),

    // Settings
    dnd_settings: DoNotDisturbSettings,
    global_enabled: bool,
    badge_enabled: bool,
    sound_enabled: bool,
    vibration_enabled: bool,

    // Statistics
    stats: NotificationStats,

    // Callbacks
    event_callback: ?NotificationCallback,
    callback_userdata: ?*anyopaque,

    // Platform-specific handlers
    platform_init: ?*const fn () NotificationError!void,
    platform_deinit: ?*const fn () void,
    platform_create_channel: ?*const fn (channel: *const NotificationChannel) NotificationError!void,
    platform_show_notification: ?*const fn (notification: *const Notification) NotificationError!void,
    platform_cancel_notification: ?*const fn (id: []const u8) NotificationError!void,
    platform_register_push_token: ?*const fn (token: []const u8, service: []const u8) NotificationError!void,
    platform_request_permissions: ?*const fn () NotificationError!bool,

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .notifications = std.ArrayList(Notification).init(allocator),
            .channels = std.ArrayList(NotificationChannel).init(allocator),
            .pending_notifications = std.ArrayList(Notification).init(allocator),
            .notification_history = std.ArrayList(NotificationEventData).init(allocator),
            .push_tokens = std.ArrayList(PushToken).init(allocator),
            .dnd_settings = DoNotDisturbSettings{ .enabled = false, .allow_alarms = true, .allow_priority_interruptions = true, .allow_calls = true, .allow_messages = false, .allow_events = false },
            .global_enabled = true,
            .badge_enabled = true,
            .sound_enabled = true,
            .vibration_enabled = true,
            .stats = std.mem.zeroes(NotificationStats),
            .event_callback = null,
            .callback_userdata = null,
            .platform_init = null,
            .platform_deinit = null,
            .platform_create_channel = null,
            .platform_show_notification = null,
            .platform_cancel_notification = null,
            .platform_register_push_token = null,
            .platform_request_permissions = null,
        };
    }

    pub fn deinit(self: *Self) void {
        // Cleanup all notifications
        for (self.notifications.items) |*notification| {
            notification.deinit(self.allocator);
        }
        self.notifications.deinit();

        // Cleanup channels
        for (self.channels.items) |*channel| {
            self.allocator.free(channel.id);
            self.allocator.free(channel.name);
            if (channel.description) |desc| self.allocator.free(desc);
            if (channel.sound_uri) |uri| self.allocator.free(uri);
            if (channel.vibration_pattern) |pattern| self.allocator.free(pattern);
            if (channel.group_id) |group| self.allocator.free(group);
        }
        self.channels.deinit();

        // Cleanup pending notifications
        for (self.pending_notifications.items) |*notification| {
            notification.deinit(self.allocator);
        }
        self.pending_notifications.deinit();

        // Cleanup history
        for (self.notification_history.items) |*event| {
            self.allocator.free(event.notification_id);
            self.allocator.free(event.app_id);
            if (event.action_id) |action| self.allocator.free(action);
            if (event.reply_text) |reply| self.allocator.free(reply);
            if (event.error_message) |error_msg| self.allocator.free(error_msg);
        }
        self.notification_history.deinit();

        // Cleanup push tokens
        for (self.push_tokens.items) |*token| {
            self.allocator.free(token.token);
            self.allocator.free(token.app_id);
        }
        self.push_tokens.deinit();

        // Platform cleanup
        if (self.platform_deinit) |platform_deinit| {
            platform_deinit();
        }
    }

    /// Initialize notification system
    pub fn initialize(self: *Self) NotificationError!void {
        // Platform-specific initialization
        if (self.platform_init) |platform_init| {
            try platform_init();
        }

        // Create default notification channel
        const default_channel = NotificationChannel{
            .id = try self.allocator.dupe(u8, "default"),
            .name = try self.allocator.dupe(u8, "Default"),
            .description = try self.allocator.dupe(u8, "Default notification channel"),
            .importance = .default,
        };

        try self.createNotificationChannel(default_channel);

        self.stats.last_updated = std.time.milliTimestamp();
    }

    /// Create a notification channel
    pub fn createNotificationChannel(self: *Self, channel: NotificationChannel) NotificationError!void {
        if (self.channels.items.len >= MAX_CHANNELS) {
            return NotificationError.QuotaExceeded;
        }

        // Check for duplicate channel ID
        for (self.channels.items) |existing_channel| {
            if (std.mem.eql(u8, existing_channel.id, channel.id)) {
                return; // Channel already exists, ignore
            }
        }

        try self.channels.append(channel);

        // Platform-specific channel creation
        if (self.platform_create_channel) |platform_create_channel| {
            try platform_create_channel(&channel);
        }
    }

    /// Show a notification
    pub fn showNotification(self: *Self, notification: Notification) NotificationError!void {
        if (!self.global_enabled) return;
        if (self.notifications.items.len >= MAX_NOTIFICATIONS) {
            return NotificationError.QuotaExceeded;
        }

        // Check Do Not Disturb settings
        if (self.shouldSuppressNotification(&notification)) {
            return; // Silently suppress
        }

        // Validate channel exists
        var channel_found = false;
        for (self.channels.items) |channel| {
            if (std.mem.eql(u8, channel.id, notification.channel_id)) {
                channel_found = true;
                break;
            }
        }
        if (!channel_found) {
            return NotificationError.ChannelNotFound;
        }

        // Store notification
        try self.notifications.append(notification);

        // Show at platform level
        if (self.platform_show_notification) |platform_show_notification| {
            try platform_show_notification(&notification);
        }

        // Update statistics
        self.stats.total_sent += 1;
        self.stats.last_updated = std.time.milliTimestamp();

        // Trigger event callback
        if (self.event_callback) |callback| {
            const event = NotificationEventData{
                .notification_id = notification.id,
                .app_id = notification.app_id,
                .event = .delivered,
                .timestamp = std.time.milliTimestamp(),
            };
            callback(event, self.callback_userdata);
        }
    }

    /// Schedule a notification for future delivery
    pub fn scheduleNotification(self: *Self, notification: Notification, delivery_time: i64) NotificationError!void {
        var scheduled_notification = notification;
        scheduled_notification.schedule_time = delivery_time;

        try self.pending_notifications.append(scheduled_notification);
    }

    /// Cancel a notification
    pub fn cancelNotification(self: *Self, notification_id: []const u8) NotificationError!void {
        // Remove from active notifications
        for (self.notifications.items, 0..) |notification, i| {
            if (std.mem.eql(u8, notification.id, notification_id)) {
                var removed_notification = self.notifications.orderedRemove(i);
                removed_notification.deinit(self.allocator);
                break;
            }
        }

        // Remove from pending notifications
        for (self.pending_notifications.items, 0..) |notification, i| {
            if (std.mem.eql(u8, notification.id, notification_id)) {
                var removed_notification = self.pending_notifications.orderedRemove(i);
                removed_notification.deinit(self.allocator);
                break;
            }
        }

        // Cancel at platform level
        if (self.platform_cancel_notification) |platform_cancel_notification| {
            try platform_cancel_notification(notification_id);
        }
    }

    /// Cancel all notifications from an app
    pub fn cancelAllFromApp(self: *Self, app_id: []const u8) NotificationError!void {
        var i: usize = 0;
        while (i < self.notifications.items.len) {
            if (std.mem.eql(u8, self.notifications.items[i].app_id, app_id)) {
                var removed_notification = self.notifications.orderedRemove(i);
                try self.cancelNotification(removed_notification.id);
                removed_notification.deinit(self.allocator);
            } else {
                i += 1;
            }
        }
    }

    /// Get active notifications
    pub fn getActiveNotifications(self: *Self) []const Notification {
        return self.notifications.items;
    }

    /// Get notifications from specific app
    pub fn getNotificationsFromApp(self: *Self, app_id: []const u8, buffer: []Notification) usize {
        var count: usize = 0;
        for (self.notifications.items) |notification| {
            if (std.mem.eql(u8, notification.app_id, app_id) and count < buffer.len) {
                buffer[count] = notification;
                count += 1;
            }
        }
        return count;
    }

    /// Process scheduled notifications (should be called periodically)
    pub fn processScheduledNotifications(self: *Self) NotificationError!void {
        const current_time = std.time.milliTimestamp();
        var i: usize = 0;

        while (i < self.pending_notifications.items.len) {
            const notification = &self.pending_notifications.items[i];
            if (notification.schedule_time) |schedule_time| {
                if (current_time >= schedule_time) {
                    // Time to deliver
                    var notification_copy = notification.*;
                    notification_copy.schedule_time = null;
                    try self.showNotification(notification_copy);

                    // Remove from pending
                    _ = self.pending_notifications.orderedRemove(i);
                    continue;
                }
            }
            i += 1;
        }
    }

    /// Register for push notifications
    pub fn registerPushToken(self: *Self, token: []const u8, service: []const u8, app_id: []const u8) NotificationError!void {
        // Remove existing token for this app
        var i: usize = 0;
        while (i < self.push_tokens.items.len) {
            if (std.mem.eql(u8, self.push_tokens.items[i].app_id, app_id)) {
                var old_token = self.push_tokens.orderedRemove(i);
                self.allocator.free(old_token.token);
                self.allocator.free(old_token.app_id);
                break;
            }
            i += 1;
        }

        // Add new token
        const push_token = PushToken{
            .token = try self.allocator.dupe(u8, token),
            .service = if (std.mem.eql(u8, service, "fcm")) .fcm else if (std.mem.eql(u8, service, "apns")) .apns else .custom,
            .timestamp = std.time.milliTimestamp(),
            .app_id = try self.allocator.dupe(u8, app_id),
        };

        try self.push_tokens.append(push_token);

        // Register with platform
        if (self.platform_register_push_token) |platform_register_push_token| {
            try platform_register_push_token(token, service);
        }
    }

    /// Set Do Not Disturb settings
    pub fn setDoNotDisturbSettings(self: *Self, settings: DoNotDisturbSettings) void {
        self.dnd_settings = settings;
    }

    /// Set event callback
    pub fn setEventCallback(self: *Self, callback: NotificationCallback, userdata: ?*anyopaque) void {
        self.event_callback = callback;
        self.callback_userdata = userdata;
    }

    /// Handle notification event (called by platform layer)
    pub fn handleNotificationEvent(self: *Self, event: NotificationEventData) void {
        // Update statistics
        switch (event.event) {
            .delivered => self.stats.total_delivered += 1,
            .clicked => self.stats.total_clicked += 1,
            .dismissed => self.stats.total_dismissed += 1,
            else => {},
        }

        // Calculate rates
        if (self.stats.total_sent > 0) {
            self.stats.delivery_rate = @as(f32, @floatFromInt(self.stats.total_delivered)) / @as(f32, @floatFromInt(self.stats.total_sent));
        }
        if (self.stats.total_delivered > 0) {
            self.stats.click_through_rate = @as(f32, @floatFromInt(self.stats.total_clicked)) / @as(f32, @floatFromInt(self.stats.total_delivered));
        }

        self.stats.last_updated = std.time.milliTimestamp();

        // Store in history
        self.notification_history.append(event) catch {}; // Ignore if history is full

        // Call event callback
        if (self.event_callback) |callback| {
            callback(event, self.callback_userdata);
        }
    }

    /// Check if notification should be suppressed due to DND settings
    fn shouldSuppressNotification(self: *Self, notification: *const Notification) bool {
        if (!self.dnd_settings.enabled) return false;

        // Check quiet hours
        if (self.dnd_settings.quiet_hours_start) |start| {
            if (self.dnd_settings.quiet_hours_end) |end| {
                const now = std.time.timestamp();
                const time_info = std.time.epoch.EpochSeconds{ .secs = @intCast(now) };
                const day_seconds = time_info.getDaySeconds();
                const minutes_from_midnight = @divTrunc(day_seconds, 60);

                if (start < end) {
                    if (minutes_from_midnight >= start and minutes_from_midnight <= end) {
                        return !self.shouldAllowDuringQuietHours(notification);
                    }
                } else { // Quiet hours span midnight
                    if (minutes_from_midnight >= start or minutes_from_midnight <= end) {
                        return !self.shouldAllowDuringQuietHours(notification);
                    }
                }
            }
        }

        return !self.shouldAllowDuringDnd(notification);
    }

    fn shouldAllowDuringDnd(self: *Self, notification: *const Notification) bool {
        return switch (notification.category) {
            .alarm => self.dnd_settings.allow_alarms,
            .call => self.dnd_settings.allow_calls,
            .message => self.dnd_settings.allow_messages,
            .event => self.dnd_settings.allow_events,
            else => if (notification.priority == .max or notification.priority == .high)
                self.dnd_settings.allow_priority_interruptions
            else
                false,
        };
    }

    fn shouldAllowDuringQuietHours(self: *Self, notification: *const Notification) bool {
        return notification.category == .alarm or
            (notification.priority == .max and self.dnd_settings.allow_priority_interruptions);
    }

    /// Get notification statistics
    pub fn getStatistics(self: *Self) NotificationStats {
        return self.stats;
    }

    /// Clear notification history
    pub fn clearHistory(self: *Self) void {
        for (self.notification_history.items) |*event| {
            self.allocator.free(event.notification_id);
            self.allocator.free(event.app_id);
            if (event.action_id) |action| self.allocator.free(action);
            if (event.reply_text) |reply| self.allocator.free(reply);
            if (event.error_message) |error_msg| self.allocator.free(error_msg);
        }
        self.notification_history.clearAndFree();
    }
};

/// Global notification manager instance
var global_notification_manager: ?NotificationManager = null;

/// Initialize global notification manager
pub fn initGlobalNotificationManager(allocator: Allocator) !void {
    if (global_notification_manager != null) return;

    global_notification_manager = try NotificationManager.init(allocator);
    try global_notification_manager.?.initialize();
}

/// Get global notification manager instance
pub fn getNotificationManager() ?*NotificationManager {
    if (global_notification_manager) |*manager| {
        return manager;
    }
    return null;
}

/// Cleanup global notification manager
pub fn deinitGlobalNotificationManager() void {
    if (global_notification_manager) |*manager| {
        manager.deinit();
        global_notification_manager = null;
    }
}

// Platform interface functions (to be implemented by platform-specific code)
pub extern fn platform_notification_init() callconv(.C) c_int;
pub extern fn platform_notification_deinit() callconv(.C) void;
pub extern fn platform_notification_create_channel(channel_data: *anyopaque) callconv(.C) c_int;
pub extern fn platform_notification_show(notification_data: *anyopaque) callconv(.C) c_int;
pub extern fn platform_notification_cancel(notification_id: [*:0]const u8) callconv(.C) c_int;
pub extern fn platform_notification_register_push(token: [*:0]const u8, service: [*:0]const u8) callconv(.C) c_int;
pub extern fn platform_notification_request_permissions() callconv(.C) c_int;

// Unit tests
test "notification manager initialization" {
    var manager = try NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.initialize();
    try std.testing.expect(manager.channels.items.len > 0); // Should have default channel
}

test "notification creation and cleanup" {
    var notification = try Notification.init(std.testing.allocator, "test-id", "test-app", "default", "Test Title");
    defer notification.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("test-id", notification.id);
    try std.testing.expectEqualStrings("Test Title", notification.title);
}

test "do not disturb filtering" {
    var manager = try NotificationManager.init(std.testing.allocator);
    defer manager.deinit();

    manager.dnd_settings.enabled = true;
    manager.dnd_settings.allow_calls = true;
    manager.dnd_settings.allow_messages = false;

    var call_notification = try Notification.init(std.testing.allocator, "call-1", "phone", "default", "Incoming Call");
    defer call_notification.deinit(std.testing.allocator);
    call_notification.category = .call;

    var message_notification = try Notification.init(std.testing.allocator, "msg-1", "messages", "default", "New Message");
    defer message_notification.deinit(std.testing.allocator);
    message_notification.category = .message;

    try std.testing.expect(!manager.shouldSuppressNotification(&call_notification));
    try std.testing.expect(manager.shouldSuppressNotification(&message_notification));
}

test "notification priority handling" {
    const high_priority = NotificationPriority.high;
    const low_priority = NotificationPriority.low;

    try std.testing.expect(@intFromEnum(high_priority) > @intFromEnum(low_priority));
    try std.testing.expectEqualStrings("high", high_priority.toString());
}
