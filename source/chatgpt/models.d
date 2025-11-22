module chatgpt.models;

import std.json;
import std.datetime;
import std.typecons;
import std.conv;
import std.algorithm;
import std.range;
import std.format;

/// Helper function to safely extract a numeric value from JSON
private double safeGetNumeric(JSONValue json, double defaultValue = 0.0)
{
    switch (json.type)
    {
    case JSONType.float_:
        return json.floating;
    case JSONType.integer:
        return cast(double) json.integer;
    case JSONType.uinteger:
        return cast(double) json.uinteger;
    case JSONType.string:
        try
        {
            return to!double(json.str);
        }
        catch (Exception)
        {
            return defaultValue;
        }
    default:
        return defaultValue;
    }
}

/// Helper function to safely extract a string value from JSON
private string safeGetString(JSONValue json, string defaultValue = "")
{
    switch (json.type)
    {
    case JSONType.string:
        return json.str;
    case JSONType.integer:
        return to!string(json.integer);
    case JSONType.uinteger:
        return to!string(json.uinteger);
    case JSONType.float_:
        return to!string(json.floating);
    case JSONType.true_:
        return "true";
    case JSONType.false_:
        return "false";
    case JSONType.null_:
        return defaultValue;
    default:
        return defaultValue;
    }
}

/// Author information for a message
struct MessageAuthor
{
    string role; // "user", "assistant", "system"
    string name; // Can be null/empty
    JSONValue metadata; // Additional metadata

    this(JSONValue json)
    {
        if ("role" in json)
            role = safeGetString(json["role"]);
        if ("name" in json)
        {
            name = safeGetString(json["name"]);
        }
        if ("metadata" in json)
            metadata = json["metadata"];
    }
}

/// Content of a message
struct MessageContent
{
    string contentType; // "text", "image", etc.
    string[] parts; // Array of content parts

    this(JSONValue json)
    {
        if ("content_type" in json)
            contentType = safeGetString(json["content_type"]);
        if ("parts" in json && json["parts"].type == JSONType.array)
        {
            foreach (part; json["parts"].array)
            {
                parts ~= safeGetString(part);
            }
        }
    }

    /// Get the full text content as a single string
    string getFullText() const
    {
        import std.array : join;

        return parts.join("\n");
    }
}

/// Metadata for a message
struct MessageMetadata
{
    string timestampType; // "absolute", etc.
    JSONValue raw; // Store raw metadata for extensibility

    this(JSONValue json)
    {
        if ("timestamp_" in json)
            timestampType = safeGetString(json["timestamp_"]);
        raw = json;
    }
}

/// Individual message in a conversation
struct ConversationMessage
{
    string id;
    MessageAuthor author;
    double createTime; // Unix timestamp
    Nullable!double updateTime;
    MessageContent content;
    string status; // "finished_successfully", etc.
    Nullable!bool endTurn;
    double weight = 1.0;
    MessageMetadata metadata;
    string recipient = "all";
    Nullable!string channel;

    this(string messageId, JSONValue json)
    {
        id = messageId;

        if ("author" in json)
            author = MessageAuthor(json["author"]);
        if ("create_time" in json)
            createTime = safeGetNumeric(json["create_time"]);
        if ("update_time" in json && json["update_time"].type != JSONType.null_)
        {
            updateTime = safeGetNumeric(json["update_time"]);
        }
        if ("content" in json)
            content = MessageContent(json["content"]);
        if ("status" in json)
            status = safeGetString(json["status"]);
        if ("end_turn" in json && json["end_turn"].type != JSONType.null_)
        {
            endTurn = json["end_turn"].type == JSONType.true_;
        }
        if ("weight" in json)
            weight = safeGetNumeric(json["weight"], 1.0);
        if ("metadata" in json)
            metadata = MessageMetadata(json["metadata"]);
        if ("recipient" in json)
            recipient = safeGetString(json["recipient"], "all");
        if ("channel" in json && json["channel"].type != JSONType.null_)
        {
            channel = safeGetString(json["channel"]);
        }
    }

    /// Get formatted timestamp
    string getFormattedTime() const
    {
        import std.datetime.systime : SysTime;

        auto time = SysTime.fromUnixTime(cast(long) createTime);
        return time.toISOExtString();
    }

    /// Check if this is a user message
    bool isUserMessage() const
    {
        return author.role == "user";
    }

    /// Check if this is an assistant message
    bool isAssistantMessage() const
    {
        return author.role == "assistant";
    }

    /// Get a preview of the message content (first N characters)
    string getPreview(size_t maxLength = 100) const
    {
        string text = content.getFullText();
        if (text.length <= maxLength)
            return text;
        return text[0 .. maxLength] ~ "...";
    }
}

/// Node in the conversation tree representing message relationships
struct ConversationNode
{
    ConversationMessage message;
    string parentId;
    string[] childrenIds;

    this(string messageId, JSONValue messageData, JSONValue nodeData)
    {
        message = ConversationMessage(messageId, messageData);

        if ("parent" in nodeData && nodeData["parent"].type != JSONType.null_)
        {
            parentId = safeGetString(nodeData["parent"]);
        }

        if ("children" in nodeData && nodeData["children"].type == JSONType.array)
        {
            foreach (child; nodeData["children"].array)
            {
                string childId = safeGetString(child);
                if (childId.length > 0)
                {
                    childrenIds ~= childId;
                }
            }
        }
    }

    /// Check if this is a root node (no parent)
    bool isRoot() const
    {
        return parentId.length == 0;
    }

    /// Check if this is a leaf node (no children)
    bool isLeaf() const
    {
        return childrenIds.length == 0;
    }
}

/// Statistics about a conversation
struct ConversationStats
{
    size_t totalMessages;
    size_t userMessages;
    size_t assistantMessages;
    size_t totalTokensApprox; // Rough estimate based on word count
    double duration; // Time span in seconds
    string[] topics; // Extracted topics/themes

    /// Calculate approximate tokens (rough estimate: ~4 chars per token)
    static size_t estimateTokens(string text)
    {
        return text.length / 4;
    }
}

/// Main conversation class that manages the entire conversation tree
class ChatGPTConversation
{
    private ConversationNode[string] nodes;
    private string[] rootNodeIds;
    private string title;
    private double startTime;
    private double endTime;

    this()
    {
        // Initialize empty conversation
    }

    /// Load conversation from JSON data
    this(JSONValue json)
    {
        loadFromJSON(json);
    }

    /// Load conversation data from JSON
    void loadFromJSON(JSONValue json)
    {
        // Debug: Print JSON structure
        import std.stdio : stderr;

        stderr.writefln("DEBUG: JSON type = %s", json.type);

        // Handle array format (new OpenAI export format)
        if (json.type == JSONType.array)
        {
            stderr.writefln(
                "DEBUG: Detected array format, attempting to parse as conversation array");
            loadFromArrayFormat(json);
            return;
        }

        if (json.type != JSONType.object)
        {
            throw new Exception(std.format.format("Invalid JSON: expected object or array but got %s", json
                    .type));
        }

        // Debug: Print available keys
        stderr.writefln("DEBUG: Available JSON keys:");
        foreach (key, value; json.object)
        {
            stderr.writefln("  - %s: %s", key, value.type);
        }

        if ("mapping" !in json)
        {
            // Try alternative field names that might be in ChatGPT exports
            if ("conversation" in json)
            {
                stderr.writefln("DEBUG: Found 'conversation' field instead of 'mapping'");
                loadFromConversationFormat(json["conversation"]);
                return;
            }
            else if ("messages" in json)
            {
                stderr.writefln("DEBUG: Found 'messages' field instead of 'mapping'");
                loadFromMessagesFormat(json["messages"]);
                return;
            }
            else
            {
                throw new Exception(
                    "Invalid ChatGPT conversation format: missing 'mapping', 'conversation', or 'messages' field");
            }
        }

        auto mapping = json["mapping"].object;

        // First pass: create all nodes
        foreach (string messageId, JSONValue nodeData; mapping)
        {
            if ("message" in nodeData && nodeData["message"].type != JSONType.null_)
            {
                auto messageData = nodeData["message"];
                nodes[messageId] = ConversationNode(messageId, messageData, nodeData);
            }
        }

        // Second pass: find root nodes and calculate time span
        double minTime = double.max;
        double maxTime = 0;

        foreach (ref node; nodes)
        {
            if (node.isRoot())
            {
                rootNodeIds ~= node.message.id;
            }

            minTime = min(minTime, node.message.createTime);
            maxTime = max(maxTime, node.message.createTime);
        }

        startTime = minTime;
        endTime = maxTime;

        // Generate title from first user message if not set
        if (title.length == 0)
        {
            generateTitle();
        }

        stderr.writefln("DEBUG: Successfully loaded %d nodes", nodes.length);
    }

    /// Load from alternative conversation format
    private void loadFromConversationFormat(JSONValue conversation)
    {
        import std.stdio : stderr;

        stderr.writefln("DEBUG: Loading from conversation format");

        if ("mapping" in conversation)
        {
            loadFromJSON(conversation);
            return;
        }

        throw new Exception("Unsupported conversation format");
    }

    /// Load from messages array format
    private void loadFromMessagesFormat(JSONValue messages)
    {
        import std.stdio : stderr;

        stderr.writefln("DEBUG: Loading from messages array format");

        if (messages.type != JSONType.array)
        {
            throw new Exception("Messages field is not an array");
        }

        // Convert messages array to mapping format
        double minTime = double.max;
        double maxTime = 0;
        bool hasValidMessages = false;

        foreach (i, msgValue; messages.array)
        {
            if (msgValue.type != JSONType.object)
                continue;

            string messageId = std.format.format("msg_%d", i);

            try
            {
                // Create a synthetic node structure
                JSONValue nodeData = JSONValue((JSONValue[string]).init);

                // Handle different message structures
                JSONValue actualMessage;
                if ("message" in msgValue && msgValue["message"].type != JSONType.null_)
                {
                    actualMessage = msgValue["message"];
                    nodeData["message"] = actualMessage;
                }
                else
                {
                    actualMessage = msgValue;
                    nodeData["message"] = msgValue;
                }

                // Ensure required fields exist with defaults
                if ("author" !in actualMessage)
                {
                    actualMessage["author"] = JSONValue((JSONValue[string]).init);
                    actualMessage["author"]["role"] = JSONValue("unknown");
                }

                if ("create_time" !in actualMessage)
                {
                    if ("timestamp" in actualMessage)
                    {
                        actualMessage["create_time"] = JSONValue(
                            safeGetNumeric(actualMessage["timestamp"]));
                    }
                    else if ("created_at" in actualMessage)
                    {
                        actualMessage["create_time"] = JSONValue(
                            safeGetNumeric(actualMessage["created_at"]));
                    }
                    else if ("time" in actualMessage)
                    {
                        actualMessage["create_time"] = JSONValue(
                            safeGetNumeric(actualMessage["time"]));
                    }
                    else
                    {
                        actualMessage["create_time"] = JSONValue(cast(double) i);
                    }
                }

                if ("content" !in actualMessage)
                {
                    if ("text" in actualMessage)
                    {
                        JSONValue content = JSONValue((JSONValue[string]).init);
                        content["content_type"] = JSONValue("text");
                        content["parts"] = JSONValue([actualMessage["text"]]);
                        actualMessage["content"] = content;
                    }
                    else if ("body" in actualMessage)
                    {
                        JSONValue content = JSONValue((JSONValue[string]).init);
                        content["content_type"] = JSONValue("text");
                        content["parts"] = JSONValue([actualMessage["body"]]);
                        actualMessage["content"] = content;
                    }
                    else
                    {
                        JSONValue content = JSONValue((JSONValue[string]).init);
                        content["content_type"] = JSONValue("text");
                        content["parts"] = JSONValue([JSONValue("")]);
                        actualMessage["content"] = content;
                    }
                }

                if ("status" !in actualMessage)
                {
                    actualMessage["status"] = JSONValue("finished_successfully");
                }

                if ("metadata" !in actualMessage)
                {
                    actualMessage["metadata"] = JSONValue((JSONValue[string]).init);
                }

                // Set up parent-child relationships (linear for array format)
                if (i > 0)
                {
                    nodeData["parent"] = JSONValue(std.format.format("msg_%d", i - 1));
                }
                else
                {
                    nodeData["parent"] = JSONValue(null);
                }

                if (i < messages.array.length - 1)
                {
                    nodeData["children"] = JSONValue([
                        JSONValue(std.format.format("msg_%d", i + 1))
                    ]);
                }
                else
                {
                    nodeData["children"] = JSONValue(JSONValue[].init);
                }

                nodes[messageId] = ConversationNode(messageId, actualMessage, nodeData);

                if (nodes[messageId].isRoot())
                {
                    rootNodeIds ~= messageId;
                }

                double msgTime = nodes[messageId].message.createTime;
                if (msgTime > 0)
                { // Only consider valid timestamps
                    minTime = min(minTime, msgTime);
                    maxTime = max(maxTime, msgTime);
                }

                hasValidMessages = true;

            }
            catch (Exception e)
            {
                stderr.writefln("DEBUG: Error processing message %d: %s", i, e.msg);
                continue;
            }
        }

        if (!hasValidMessages)
        {
            throw new Exception("No valid messages found in array");
        }

        startTime = (minTime == double.max) ? 0 : minTime;
        endTime = (maxTime == 0) ? startTime : maxTime;

        if (title.length == 0)
        {
            generateTitle();
        }

        stderr.writefln("DEBUG: Loaded %d messages from array format", nodes.length);
    }

    /// Load from array format (new OpenAI export format)
    private void loadFromArrayFormat(JSONValue jsonArray)
    {
        import std.stdio : stderr;

        stderr.writefln("DEBUG: Loading from array format");

        if (jsonArray.type != JSONType.array)
        {
            throw new Exception("Expected array format");
        }

        // Check if array contains conversations or is a single conversation
        if (jsonArray.array.length == 0)
        {
            throw new Exception("Empty conversation array");
        }

        // Check if this looks like a multi-conversation export
        if (jsonArray.array.length > 1)
        {
            bool looksLikeConversations = true;
            foreach (i, element; jsonArray.array)
            {
                if (element.type != JSONType.object ||
                    ("mapping" !in element && "messages" !in element && "title" !in element))
                {
                    looksLikeConversations = false;
                    break;
                }
                // Only check first few to avoid processing everything
                if (i >= 2)
                    break;
            }

            if (looksLikeConversations)
            {
                throw new Exception("MULTI_CONVERSATION_EXPORT");
            }
        }

        // Take the first conversation if it's an array of conversations
        JSONValue conversationData = jsonArray.array[0];

        // If the first element is an object with mapping, use it directly
        if (conversationData.type == JSONType.object && "mapping" in conversationData)
        {
            stderr.writefln("DEBUG: Found conversation object with mapping in array");
            loadFromJSON(conversationData);
            return;
        }

        // If the first element is an object with messages, treat it as messages array
        if (conversationData.type == JSONType.object && "messages" in conversationData)
        {
            stderr.writefln("DEBUG: Found conversation object with messages in array");
            loadFromMessagesFormat(conversationData["messages"]);
            return;
        }

        // Otherwise, treat the entire array as a messages array
        stderr.writefln("DEBUG: Treating entire array as messages");
        loadFromMessagesFormat(jsonArray);
    }

    /// Get all messages in chronological order
    ConversationMessage[] getMessagesChronological()
    {
        ConversationMessage[] messages;

        foreach (node; nodes)
        {
            messages ~= node.message;
        }

        // Sort by creation time
        import std.algorithm : sort;

        messages.sort!((a, b) => a.createTime < b.createTime);
        return messages;
    }

    /// Get conversation statistics
    ConversationStats getStats()
    {
        ConversationStats stats;
        stats.totalMessages = nodes.length;
        stats.duration = endTime - startTime;

        size_t totalChars = 0;
        foreach (node; nodes)
        {
            if (node.message.isUserMessage())
            {
                stats.userMessages++;
            }
            else if (node.message.isAssistantMessage())
            {
                stats.assistantMessages++;
            }

            totalChars += node.message.content.getFullText().length;
        }

        stats.totalTokensApprox = ConversationStats.estimateTokens(to!string(totalChars));
        return stats;
    }

    /// Get a conversation thread starting from a specific message
    ConversationMessage[] getThread(string startMessageId)
    {
        ConversationMessage[] thread;

        if (startMessageId !in nodes)
            return thread;

        // Trace back to root
        string currentId = startMessageId;
        ConversationMessage[] backtrack;

        while (currentId.length > 0 && currentId in nodes)
        {
            backtrack ~= nodes[currentId].message;
            currentId = nodes[currentId].parentId;
        }

        // Reverse to get chronological order
        import std.algorithm : reverse;

        thread = backtrack.dup;
        thread.reverse();
        return thread;
    }

    /// Search for messages containing specific text
    ConversationMessage[] searchMessages(string query)
    {
        import std.uni : toLower;
        import std.algorithm : canFind;

        ConversationMessage[] results;
        string lowerQuery = query.toLower();

        foreach (node; nodes)
        {
            string content = node.message.content.getFullText().toLower();
            if (content.canFind(lowerQuery))
            {
                results ~= node.message;
            }
        }

        // Sort by relevance (for now, just chronological)
        import std.algorithm : sort;

        results.sort!((a, b) => a.createTime < b.createTime);
        return results;
    }

    /// Get conversation title
    string getTitle() const
    {
        return title.length > 0 ? title : "Untitled Conversation";
    }

    /// Set conversation title
    void setTitle(string newTitle)
    {
        title = newTitle;
    }

    /// Generate a title from the conversation content
    private void generateTitle()
    {
        // Find first substantial user message
        auto messages = getMessagesChronological();

        foreach (msg; messages)
        {
            if (msg.isUserMessage())
            {
                string preview = msg.getPreview(50);
                if (preview.length > 10)
                { // Ensure it's substantial
                    title = preview;
                    return;
                }
            }
        }

        title = "Conversation";
    }

    /// Export conversation to a simple text format
    string exportToText()
    {
        import std.array : appender;
        import std.format : format;

        auto output = appender!string();
        auto messages = getMessagesChronological();

        output ~= format("=== %s ===\n\n", getTitle());

        foreach (msg; messages)
        {
            output ~= format("[%s] %s:\n",
                msg.getFormattedTime(),
                msg.author.role);
            output ~= msg.content.getFullText();
            output ~= "\n\n";
        }

        return output.data;
    }
}

/// Summary information about a conversation
struct ConversationInfo
{
    size_t index; // Index in the collection
    string title; // Conversation title
    double createTime; // Creation timestamp
    double updateTime; // Last update timestamp
    size_t messageCount; // Number of messages
    string firstUserMessage; // Preview of first user message

    /// Get formatted creation time
    string getFormattedCreateTime() const
    {
        import std.datetime.systime : SysTime;

        auto time = SysTime.fromUnixTime(cast(long) createTime);
        return time.toISOExtString();
    }

    /// Get formatted update time
    string getFormattedUpdateTime() const
    {
        import std.datetime.systime : SysTime;

        auto time = SysTime.fromUnixTime(cast(long) updateTime);
        return time.toISOExtString();
    }
}

/// Collection of multiple ChatGPT conversations from OpenAI export
class ConversationCollection
{
    private JSONValue[] conversationData;
    private ConversationInfo[size_t] cachedInfos; // Lazy cache indexed by position
    private ConversationInfo[] allInfosCache; // Full cache when needed
    private bool allInfosLoaded = false;
    private size_t maxConversations = 10000; // Increased limit for lazy loading
    private string[] searchIndex; // For fast searching
    private bool searchIndexBuilt = false;

    this()
    {
        // Initialize empty collection
    }

    /// Load conversations from array format (lazy)
    this(JSONValue jsonArray)
    {
        loadFromArrayLazy(jsonArray);
    }

    /// Load conversations from JSON array with lazy processing
    void loadFromArrayLazy(JSONValue jsonArray)
    {
        import std.stdio : stderr;
        import core.time : MonoTime;

        auto startTime = MonoTime.currTime;

        if (jsonArray.type != JSONType.array)
        {
            throw new Exception("Expected array format for conversations");
        }

        if (jsonArray.array.length == 0)
        {
            throw new Exception("Empty conversations array");
        }

        // Store raw data without processing
        if (jsonArray.array.length > maxConversations)
        {
            stderr.writefln("WARNING: Truncating conversation collection from %d to %d items",
                jsonArray.array.length, maxConversations);
            conversationData = jsonArray.array[0 .. maxConversations].dup;
        }
        else
        {
            conversationData = jsonArray.array.dup;
        }

        auto loadTime = MonoTime.currTime - startTime;
        stderr.writefln("DEBUG: Stored %d conversations in %d ms (lazy mode)",
            conversationData.length, loadTime.total!"msecs");

        // Pre-process first batch for immediate display
        preloadBatch(0, 50);
    }

    /// Preload a batch of conversation infos
    private void preloadBatch(size_t start, size_t count)
    {
        import std.algorithm : min;
        import std.stdio : stderr;

        size_t end = min(start + count, conversationData.length);

        for (size_t i = start; i < end; i++)
        {
            if (i !in cachedInfos)
            {
                try
                {
                    cachedInfos[i] = extractConversationInfo(i, conversationData[i]);
                }
                catch (Exception e)
                {
                    // Create fallback info
                    ConversationInfo info;
                    info.index = i;
                    info.title = std.format.format("Conversation %d (Error)", i + 1);
                    info.createTime = 0;
                    info.updateTime = 0;
                    info.messageCount = 0;
                    info.firstUserMessage = "Error loading conversation";
                    cachedInfos[i] = info;
                }
            }
        }

        stderr.writefln("DEBUG: Preloaded conversations %d-%d", start, end - 1);
    }

    /// Get conversation info with lazy loading
    ConversationInfo getConversationInfoLazy(size_t index)
    {
        if (index >= conversationData.length)
        {
            throw new Exception("Index out of bounds");
        }

        // Check cache first
        if (auto info = index in cachedInfos)
        {
            return *info;
        }

        // Load on demand
        try
        {
            auto info = extractConversationInfo(index, conversationData[index]);
            cachedInfos[index] = info;

            // Preload nearby conversations for smoother scrolling
            if (index + 1 < conversationData.length && (index + 1) !in cachedInfos)
            {
                preloadBatch(index + 1, 10);
            }

            return info;
        }
        catch (Exception e)
        {
            // Return fallback info
            ConversationInfo info;
            info.index = index;
            info.title = std.format.format("Conversation %d (Error)", index + 1);
            info.createTime = 0;
            info.updateTime = 0;
            info.messageCount = 0;
            info.firstUserMessage = "Error loading conversation";
            cachedInfos[index] = info;
            return info;
        }
    }

    /// Search conversations (returns indices of matches)
    size_t[] searchConversations(string query, size_t maxResults = 100)
    {
        import std.string : toLower, indexOf;
        import std.algorithm : sort;
        import std.array : array;

        if (query.length == 0)
            return [];

        string lowerQuery = query.toLower();
        size_t[] results;

        // Build search index if not already built
        if (!searchIndexBuilt)
        {
            buildSearchIndex();
        }

        // Simple substring search for now
        foreach (i, searchText; searchIndex)
        {
            if (searchText.indexOf(lowerQuery) >= 0)
            {
                results ~= i;
                if (results.length >= maxResults)
                    break;
            }
        }

        return results;
    }

    /// Build search index for fast searching
    private void buildSearchIndex()
    {
        import std.string : toLower;
        import std.stdio : stderr;
        import core.time : MonoTime;

        auto startTime = MonoTime.currTime;

        searchIndex.length = conversationData.length;

        foreach (i, ref conv; conversationData)
        {
            try
            {
                string searchText = "";

                // Add title to search index
                if ("title" in conv)
                {
                    searchText ~= safeGetString(conv["title"], "");
                }

                // Add first user message if available
                if ("mapping" in conv && conv["mapping"].type == JSONType.object)
                {
                    foreach (nodeId, node; conv["mapping"].object)
                    {
                        if ("message" in node && node["message"].type == JSONType.object)
                        {
                            auto msg = node["message"];
                            if ("author" in msg && msg["author"].type == JSONType.object)
                            {
                                auto role = safeGetString(msg["author"]["role"], "");
                                if (role == "user")
                                {
                                    if ("content" in msg && msg["content"].type == JSONType.object)
                                    {
                                        if ("parts" in msg["content"] && msg["content"]["parts"].type == JSONType.array)
                                        {
                                            foreach (part; msg["content"]["parts"].array)
                                            {
                                                if (part.type == JSONType.string)
                                                {
                                                    searchText ~= " " ~ part.str;
                                                    break; // Just first message
                                                }
                                            }
                                        }
                                    }
                                    break; // Found first user message
                                }
                            }
                        }
                    }
                }

                searchIndex[i] = searchText.toLower();
            }
            catch (Exception e)
            {
                searchIndex[i] = "";
            }

            // Show progress for large collections
            if (i % 500 == 0 && i > 0)
            {
                stderr.writefln("DEBUG: Building search index... %d/%d", i, conversationData.length);
            }
        }

        searchIndexBuilt = true;

        auto buildTime = MonoTime.currTime - startTime;
        stderr.writefln("DEBUG: Built search index in %d ms", buildTime.total!"msecs");
    }

    /// Extract summary information from conversation data
    private ConversationInfo extractConversationInfo(size_t index, JSONValue convData)
    {
        ConversationInfo info;
        info.index = index;

        if (convData.type != JSONType.object)
        {
            throw new Exception("Conversation data is not an object");
        }

        // Extract title
        if ("title" in convData)
        {
            info.title = safeGetString(convData["title"], std.format.format("Conversation %d", index + 1));
        }
        else
        {
            info.title = std.format.format("Conversation %d", index + 1);
        }

        // Extract timestamps
        if ("create_time" in convData)
        {
            info.createTime = safeGetNumeric(convData["create_time"]);
        }
        if ("update_time" in convData)
        {
            info.updateTime = safeGetNumeric(convData["update_time"]);
        }

        // Count messages and find first user message
        if ("mapping" in convData && convData["mapping"].type == JSONType.object)
        {
            auto mapping = convData["mapping"].object;
            info.messageCount = mapping.length;

            // Find first user message for preview
            double earliestTime = double.max;
            string firstUserMsg = "";

            foreach (string messageId, JSONValue nodeData; mapping)
            {
                if ("message" in nodeData && nodeData["message"].type != JSONType.null_)
                {
                    auto messageData = nodeData["message"];

                    if ("author" in messageData &&
                        safeGetString(messageData["author"]["role"]) == "user" &&
                        "create_time" in messageData)
                    {

                        double msgTime = safeGetNumeric(messageData["create_time"]);
                        if (msgTime < earliestTime && msgTime > 0)
                        {
                            earliestTime = msgTime;

                            if ("content" in messageData &&
                                "parts" in messageData["content"] &&
                                messageData["content"]["parts"].type == JSONType.array &&
                                messageData["content"]["parts"].array.length > 0)
                            {

                                string fullText = safeGetString(
                                    messageData["content"]["parts"].array[0]);
                                if (fullText.length > 100)
                                {
                                    firstUserMsg = fullText[0 .. 100] ~ "...";
                                }
                                else
                                {
                                    firstUserMsg = fullText;
                                }
                            }
                        }
                    }
                }
            }

            info.firstUserMessage = firstUserMsg.length > 0 ? firstUserMsg
                : "No user messages found";
        }
        else
        {
            info.messageCount = 0;
            info.firstUserMessage = "Unable to analyze conversation";
        }

        // If we don't have a good title, try to use the first user message
        if (info.title == std.format.format("Conversation %d", index + 1) &&
            info.firstUserMessage.length > 0 &&
            info.firstUserMessage != "No user messages found")
        {

            string titleFromMessage = info.firstUserMessage;
            if (titleFromMessage.length > 50)
            {
                titleFromMessage = titleFromMessage[0 .. 50] ~ "...";
            }
            info.title = titleFromMessage;
        }

        return info;
    }

    /// Get the number of conversations
    @property size_t length() const
    {
        return conversationData.length;
    }

    /// Check if search index is ready
    @property bool isSearchReady() const
    {
        return searchIndexBuilt;
    }

    /// Build search index asynchronously (call from UI thread with timer)
    void buildSearchIndexAsync()
    {
        if (!searchIndexBuilt)
        {
            buildSearchIndex();
        }
    }

    /// Get conversation info at index
    ConversationInfo getConversationInfo(size_t index)
    {
        return getConversationInfoLazy(index);
    }

    /// Get all conversation infos
    /// Get all conversation infos (triggers full load if needed)
    ConversationInfo[] getAllConversationInfos()
    {
        import std.stdio : stderr;
        import core.time : MonoTime;

        if (!allInfosLoaded)
        {
            auto startTime = MonoTime.currTime;

            allInfosCache.length = conversationData.length;

            foreach (i; 0 .. conversationData.length)
            {
                allInfosCache[i] = getConversationInfoLazy(i);

                // Show progress for large collections
                if (i % 200 == 0 && i > 0)
                {
                    stderr.writefln("DEBUG: Loading conversation infos... %d/%d", i, conversationData.length);
                }
            }

            allInfosLoaded = true;

            auto loadTime = MonoTime.currTime - startTime;
            stderr.writefln("DEBUG: Loaded all %d conversation infos in %d ms",
                conversationData.length, loadTime.total!"msecs");
        }

        return allInfosCache;
    }

    /// Get a batch of conversation infos (for pagination)
    ConversationInfo[] getConversationInfoBatch(size_t start, size_t count)
    {
        import std.algorithm : min;

        size_t end = min(start + count, conversationData.length);
        ConversationInfo[] batch;
        batch.reserve(end - start);

        for (size_t i = start; i < end; i++)
        {
            batch ~= getConversationInfoLazy(i);
        }

        // Preload next batch in background
        if (end < conversationData.length)
        {
            preloadBatch(end, count);
        }

        return batch;
    }

    /// Load a specific conversation by index
    ChatGPTConversation loadConversation(size_t index)
    {
        if (index >= conversationData.length)
        {
            throw new Exception(std.format.format("Invalid conversation index: %d", index));
        }

        try
        {
            return new ChatGPTConversation(conversationData[index]);
        }
        catch (Exception e)
        {
            import std.stdio : stderr;

            stderr.writefln("ERROR: Failed to load conversation at index %d: %s", index, e.msg);
            // Return an empty conversation as fallback
            auto emptyConv = new ChatGPTConversation();
            emptyConv.title = std.format.format("Failed to load conversation %d", index + 1);
            return emptyConv;
        }
    }
}
