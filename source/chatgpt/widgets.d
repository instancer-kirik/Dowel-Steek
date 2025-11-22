module chatgpt.widgets;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.scroll;
import dlangui.widgets.editors;
import std.conv : to;
import std.format : format;
import std.datetime : SysTime, DateTime, Clock;
import std.algorithm : min, max;
import std.stdio : writeln, writefln;
import chatgpt.models : ConversationInfo;

/// Virtual list widget that only renders visible items for performance
class VirtualListWidget : ScrollWidget
{
    private int _itemHeight = 72;
    private size_t _itemCount;
    private size_t _firstVisible;
    private size_t _lastVisible;
    private size_t _scrollPosition;
    private Widget delegate(size_t index) _itemBuilder;
    private VerticalLayout _contentWidget;
    private int _overscan = 3; // Render a few extra items for smoother scrolling


    this(string id = null)
    {
        super(id);
        _contentWidget = new VerticalLayout("virtual_list_content");
        _contentWidget.layoutWidth = FILL_PARENT;
        _contentWidget.layoutHeight = WRAP_CONTENT;
        _contentWidget.backgroundColor = 0xFFFF00FF; // Bright magenta background for content
        contentWidget = _contentWidget;

        // Set a debug background color for the scroll widget itself
        backgroundColor = 0xFF00FF00; // Bright green for debugging

        writeln("DEBUG: VirtualListWidget created");
    }

    /// Set the total number of items
    void setItemCount(size_t count)
    {
        _itemCount = count;
        // Set content height based on item count
        _contentWidget.minHeight = cast(int)(_itemCount * _itemHeight);

        // Only update visible range if we have valid dimensions
        if (width > 0 && height > 0)
        {
            updateVisibleRange();
            rebuildVisibleItems();
        }
        else
        {
            writeln("DEBUG: VirtualList - Deferring initial build until layout is complete");
        }

        writefln("DEBUG: VirtualList item count set to %d", count);
        writefln("DEBUG: VirtualList dimensions - width: %d, height: %d", width, height);
        writefln("DEBUG: VirtualList content height set to: %d", _contentWidget.minHeight);
    }

    /// Set the item builder delegate
    void setItemBuilder(Widget delegate(size_t) builder)
    {
        _itemBuilder = builder;
    }

    /// Set the height of each item (must be uniform)
    void setItemHeight(int height)
    {
        _itemHeight = height;
        if (_itemCount > 0)
        {
            _contentWidget.minHeight = cast(int)(_itemCount * _itemHeight);
            updateVisibleRange();
            rebuildVisibleItems();
        }
    }

    override bool onVScroll(ScrollEvent event)
    {
        bool result = super.onVScroll(event);

        size_t newScrollPos = scrollPos.y / _itemHeight;
        writefln("DEBUG: VirtualList - Scroll event: pos.y=%d, newScrollPos=%d, oldScrollPos=%d",
                 scrollPos.y, newScrollPos, _scrollPosition);
        if (newScrollPos != _scrollPosition)
        {
            _scrollPosition = newScrollPos;
            writeln("DEBUG: VirtualList - Scroll position changed, updating view");
            updateVisibleRange();
            rebuildVisibleItems();
        }
        return result;
    }

    private void updateVisibleRange()
    {
        if (_itemHeight <= 0 || height <= 0 || width <= 0)
        {
            writefln("DEBUG: VirtualList - Cannot update range: height=%d, width=%d, itemHeight=%d",
                    height, width, _itemHeight);
            return;
        }

        size_t viewportItems = (height / _itemHeight) + 1;
        _firstVisible = _scrollPosition;
        _lastVisible = min(_firstVisible + viewportItems + _overscan * 2, _itemCount);

        // Add overscan at the beginning too
        if (_firstVisible >= _overscan)
            _firstVisible -= _overscan;

        writefln("DEBUG: VirtualList - Visible range updated: %d-%d (of %d total items)", _firstVisible, _lastVisible, _itemCount);
        writefln("DEBUG: VirtualList - Height: %d, Item height: %d, Viewport items: %d", height, _itemHeight, viewportItems);
    }

    private void rebuildVisibleItems()
    {
        if (!_itemBuilder)
        {
            writeln("DEBUG: VirtualList - No item builder set, cannot rebuild items");
            return;
        }

        writefln("DEBUG: VirtualList - Rebuilding items for range %d-%d", _firstVisible, _lastVisible);

        // Clear all children - widgets cannot be reused due to parent references
        _contentWidget.removeAllChildren();

        // Add spacer for items before visible range
        if (_firstVisible > 0)
        {
            auto topSpacer = new Widget("top_spacer");
            topSpacer.layoutHeight = cast(int)(_firstVisible * _itemHeight);
            topSpacer.layoutWidth = FILL_PARENT;
            topSpacer.backgroundColor = 0xFFFFE0E0; // Light red for debugging
            _contentWidget.addChild(topSpacer);
            writefln("DEBUG: Added top spacer with height %d", topSpacer.layoutHeight);
        }

        // Add visible items
        for (size_t i = _firstVisible; i < _lastVisible && i < _itemCount; i++)
        {
            Widget item;

            // Don't use cache - always create fresh widgets to avoid parent issues
            writefln("DEBUG: VirtualList - Building new item for index %d", i);
            item = _itemBuilder(i);

            if (item)
            {
                writefln("DEBUG: VirtualList - Adding item %d to content, item dimensions: %dx%d, visibility: %s",
                        i, item.width, item.height, item.visibility);
                _contentWidget.addChild(item);
                writefln("DEBUG: VirtualList - Content widget now has %d children", _contentWidget.childCount);
            }
            else
            {
                writefln("ERROR: VirtualList - Item builder returned null for index %d", i);
            }
        }

        // Add spacer for items after visible range
        if (_lastVisible < _itemCount)
        {
            auto bottomSpacer = new Widget("bottom_spacer");
            bottomSpacer.layoutHeight = cast(int)((_itemCount - _lastVisible) * _itemHeight);
            bottomSpacer.layoutWidth = FILL_PARENT;
            bottomSpacer.backgroundColor = 0xFFE0FFE0; // Light green for debugging
            _contentWidget.addChild(bottomSpacer);
            writefln("DEBUG: Added bottom spacer with height %d", bottomSpacer.layoutHeight);
        }

        requestLayout();

        writefln("DEBUG: VirtualList - Rebuild complete. Content has %d children, content height: %d",
                _contentWidget.childCount, _contentWidget.height);
        writefln("DEBUG: VirtualList - Scroll position: %d, visible range: %d-%d",
                scrollPos.y, _firstVisible, _lastVisible);
    }



    override void measure(int parentWidth, int parentHeight)
    {
        super.measure(parentWidth, parentHeight);
        writefln("DEBUG: VirtualList.measure called - measured size: %dx%d, parent: %dx%d",
                 measuredWidth, measuredHeight, parentWidth, parentHeight);
    }

    override void layout(Rect rc)
    {
        super.layout(rc);
        writefln("DEBUG: VirtualList.layout called - rect: %s, actual size: %dx%d",
                 rc, width, height);
        writefln("DEBUG: VirtualList - Content widget size: %dx%d, minHeight: %d",
                _contentWidget.width, _contentWidget.height, _contentWidget.minHeight);

        // Update visible range after layout if we have items
        if (_itemCount > 0 && width > 0 && height > 0)
        {
            writeln("DEBUG: VirtualList - Layout complete, building visible items");
            updateVisibleRange();
            rebuildVisibleItems();
        }
        else
        {
            writefln("DEBUG: VirtualList - Skipping rebuild: itemCount=%d, width=%d, height=%d",
                    _itemCount, width, height);
        }
    }

    /// Refresh the list
    void refresh()
    {
        updateVisibleRange();
        rebuildVisibleItems();
    }
}

/// Enhanced conversation list item widget
class ConversationListItem : HorizontalLayout
{
    private TextWidget _titleText;
    private TextWidget _dateText;
    private TextWidget _messageCountText;
    private TextWidget _previewText;
    private ConversationInfo _info;
    private bool _selected;
    private size_t _index;

    this(ConversationInfo info, size_t index)
    {
        super("conv_item_" ~ to!string(index));
        _info = info;
        _index = index;

        layoutWidth = FILL_PARENT;
        layoutHeight = 72;
        minHeight = 72;  // Ensure minimum height
        minWidth = 200;  // Ensure minimum width
        padding = Rect(12, 8, 12, 8);
        margins = Rect(2, 2, 2, 2);  // More margin to see separation
        // Use contrasting colors and borders for debugging visibility
        backgroundColor = (index % 2 == 0) ? 0xFFFFFF00 : 0xFF00FFFF;  // Yellow and cyan
        // Add a visible border
        // focusRectColors = [0xFF000000, 0xFFFF0000];  // Black and red border

        // Hover effect removed - setState not compatible with this widget type

        initializeUI();

        writefln("DEBUG: ConversationListItem created for index %d, dimensions: %dx%d",
                index, width, height);
    }

    private void initializeUI()
    {
        // Main content layout
        auto contentLayout = new VerticalLayout();
        contentLayout.layoutWidth = FILL_PARENT;
        contentLayout.layoutWeight = 1;

        // Top row: Title
        _titleText = new TextWidget(null, toUTF32(_info.title));
        _titleText.fontSize = 14;
        _titleText.fontWeight = 600;
        _titleText.textColor = 0xFF000000;  // Pure black for visibility
        _titleText.backgroundColor = 0x40FF0000;  // Semi-transparent red background
        _titleText.maxLines = 1;
        _titleText.layoutWidth = FILL_PARENT;
        _titleText.minHeight = 20;
        contentLayout.addChild(_titleText);

        // Middle row: Preview text (if available)
        if (_info.firstUserMessage.length > 0)
        {
            auto preview = _info.firstUserMessage.length > 80
                ? _info.firstUserMessage[0..77] ~ "..."
                : _info.firstUserMessage;
            _previewText = new TextWidget(null, toUTF32(preview));
            _previewText.fontSize = 12;
            _previewText.textColor = 0xFF757575;
            _previewText.maxLines = 1;
            _previewText.layoutWidth = FILL_PARENT;
            contentLayout.addChild(_previewText);
        }

        // Bottom row: Date and message count
        auto metaLayout = new HorizontalLayout();
        metaLayout.layoutWidth = FILL_PARENT;

        _dateText = new TextWidget(null, toUTF32(formatDate(_info.createTime)));
        _dateText.fontSize = 11;
        _dateText.textColor = 0xFF9E9E9E;
        metaLayout.addChild(_dateText);

        auto separator = new TextWidget(null, " • "d);
        separator.fontSize = 11;
        separator.textColor = 0xFF9E9E9E;
        metaLayout.addChild(separator);

        _messageCountText = new TextWidget(null, toUTF32(format("%d messages", _info.messageCount)));
        _messageCountText.fontSize = 11;
        _messageCountText.textColor = 0xFF9E9E9E;
        metaLayout.addChild(_messageCountText);

        contentLayout.addChild(metaLayout);

        // Add index badge on the right
        auto indexBadge = new TextWidget(null, toUTF32(format("%d", _index)));
        indexBadge.fontSize = 10;
        indexBadge.textColor = 0xFFBDBDBD;
        indexBadge.alignment = Align.Right | Align.VCenter;
        indexBadge.minWidth = 40;

        addChild(contentLayout);
        addChild(indexBadge);
    }

    private string formatDate(double timestamp)
    {
        import std.datetime : SysTime, DateTime;
        import std.datetime.systime : unixTimeToStdTime;

        if (timestamp <= 0)
            return "Unknown date";

        try
        {
            auto sysTime = SysTime.fromUnixTime(cast(long)timestamp);
            auto now = Clock.currTime();
            auto diff = now - sysTime;

            if (diff.total!"days" == 0)
                return "Today";
            else if (diff.total!"days" == 1)
                return "Yesterday";
            else if (diff.total!"days" < 7)
                return format("%d days ago", diff.total!"days");
            else if (diff.total!"days" < 30)
                return format("%d weeks ago", diff.total!"days" / 7);
            else if (diff.total!"days" < 365)
                return format("%d months ago", diff.total!"days" / 30);
            else
                return format("%d years ago", diff.total!"days" / 365);
        }
        catch (Exception e)
        {
            return "Unknown date";
        }
    }

    void setSelected(bool selected)
    {
        _selected = selected;
        backgroundColor = selected ? 0xFFE3F2FD : 0xFFFFFFFF;
        if (_titleText)
            _titleText.textColor = selected ? 0xFF1976D2 : 0xFF212121;
        invalidate();
    }

    @property bool selected() const { return _selected; }
    @property size_t index() const { return _index; }
    @property ConversationInfo info() const { return _info; }

    override bool onMouseEvent(MouseEvent event)
    {
        if (event.action == MouseAction.Move)
        {
            // Hover effect
            if (!_selected)
            {
                backgroundColor = 0xFFF5F5F5;
                invalidate();
            }
        }
        return super.onMouseEvent(event);
    }

    void handleMouseLeave()
    {
        // Remove hover effect
        if (!_selected)
        {
            backgroundColor = 0xFFFFFFFF;
            invalidate();
        }
    }
}

/// Message bubble widget for chat display
class MessageBubble : HorizontalLayout
{
    private TextWidget _contentText;
    private TextWidget _authorText;
    private TextWidget _timeText;
    private bool _isUser;

    this(string content, string author, bool isUser = false)
    {
        super();
        _isUser = isUser;

        layoutWidth = FILL_PARENT;
        layoutHeight = WRAP_CONTENT;
        margins = Rect(8, 4, 8, 4);

        initializeUI(content, author);
    }

    private void initializeUI(string content, string author)
    {
        // Create bubble container
        auto bubble = new VerticalLayout();
        bubble.layoutWidth = WRAP_CONTENT;
        bubble.maxWidth = 600;
        bubble.padding = Rect(12, 8, 12, 8);
        bubble.backgroundColor = _isUser ? 0xFFE3F2FD : 0xFFF5F5F5;
        // TODO: Add rounded corners when DrawableRef usage is clarified
        // bubble.backgroundDrawable = DrawableRef(new RoundedRectDrawable(8));

        // Author label
        _authorText = new TextWidget(null, toUTF32(author));
        _authorText.fontSize = 11;
        _authorText.fontWeight = 600;
        _authorText.textColor = _isUser ? 0xFF1565C0 : 0xFF616161;
        bubble.addChild(_authorText);

        // Message content
        _contentText = new TextWidget(null, toUTF32(content));
        _contentText.fontSize = 13;
        _contentText.textColor = 0xFF212121;
        _contentText.layoutWidth = WRAP_CONTENT;
        bubble.addChild(_contentText);

        // Add spacer for alignment
        if (_isUser)
        {
            auto spacer = new Widget();
            spacer.layoutWeight = 1;
            addChild(spacer);
        }

        addChild(bubble);

        if (!_isUser)
        {
            auto spacer = new Widget();
            spacer.layoutWeight = 1;
            addChild(spacer);
        }
    }
}

/// Rounded rectangle drawable for better UI
class RoundedRectDrawable : Drawable
{
    private int _radius;
    private uint _color = 0xFFFFFFFF;
    private int _width = 100;
    private int _height = 100;

    this(int radius = 4)
    {
        _radius = radius;
    }

    override void drawTo(DrawBuf buf, Rect rc, uint state = 0, int tilex0 = 0, int tiley0 = 0)
    {
        // For now, just draw a regular rectangle
        // TODO: Implement actual rounded corners when DrawBuf supports it
        buf.fillRect(rc, _color);
    }

    @property override int width() { return _width; }
    @property override int height() { return _height; }

    @property uint color() const { return _color; }
    @property void color(uint c) { _color = c; }
}
