module auth;

import vibe.d;
import std.json;

// Simple auth state
static bool isAuthenticated = false;

// Basic auth check
bool checkAuth() {
    return isAuthenticated;
}

// Simple login
bool login(string password) {
    // For development, accept any non-empty password
    if (password.length > 0) {
        isAuthenticated = true;
        return true;
    }
    return false;
}

// Logout
void logout() {
    isAuthenticated = false;
}

// Request magic link
ws.send(JSONValue([
    "type": JSONValue("magic_link_request"),
    "data": JSONValue("user@example.com")
]).toString());

// Handle WebSocket responses
void handleResponse(string response) {
    auto data = parseJSON(response);
    switch(data["type"].str) {
        case "magic_link_sent":
            // Show "Check your email" message
            break;
        case "auth_success":
            // Store session and redirect
            auto session = data["session"];
            break;
        default:
            break;
    }
}