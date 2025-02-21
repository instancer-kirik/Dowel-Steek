import React from 'react';
import type { TouchToolbarProps } from '../types';

export const TouchToolbar: React.FC<TouchToolbarProps> = ({
    onCursorLeft,
    onCursorRight,
    onToggleSelect,
    onInsertLink
}) => {
    return (
        <div className="touch-toolbar">
            <button onClick={onCursorLeft}>←</button>
            <button onClick={onCursorRight}>→</button>
            <button onClick={onToggleSelect}>Select</button>
            <button onClick={onInsertLink}>Link</button>
        </div>
    );
}; 