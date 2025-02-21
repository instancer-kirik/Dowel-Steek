// public/src/components/Editor.tsx
import React, { useRef, useState } from 'react';
import { Note } from '../types';
import { TouchToolbar } from './TouchToolbar';

interface EditorProps {
    note: Note;
    onChange: (note: Note) => void;
}

export const Editor: React.FC<EditorProps> = ({ note, onChange }) => {
    const editorRef = useRef<HTMLTextAreaElement>(null);
    const [isSelecting, setIsSelecting] = useState(false);
    const [touchStart, setTouchStart] = useState<{x: number, y: number} | null>(null);

    const handleTouchStart = (e: React.TouchEvent) => {
        setTouchStart({
            x: e.touches[0].clientX,
            y: e.touches[0].clientY
        });
    };

    const handleTouchMove = (e: React.TouchEvent) => {
        if (!touchStart || !isSelecting) return;
        
        const editor = editorRef.current;
        if (!editor) return;

        // Calculate selection based on touch position
        const rect = editor.getBoundingClientRect();
        const x = e.touches[0].clientX - rect.left;
        const y = e.touches[0].clientY - rect.top;
        
        // Use editor.setSelectionRange() based on calculated position
    };

    return (
        <div className="editor">
            <TouchToolbar 
                onCursorLeft={() => {/* Move cursor left */}}
                onCursorRight={() => {/* Move cursor right */}}
                onToggleSelect={() => setIsSelecting(!isSelecting)}
                onInsertLink={() => {/* Show link dialog */}}
            />
            <textarea
                ref={editorRef}
                value={note.content}
                onChange={(e) => onChange({
                    ...note,
                    content: e.target.value,
                    modified: new Date()
                })}
                onTouchStart={handleTouchStart}
                onTouchMove={handleTouchMove}
                className="editor-textarea"
            />
        </div>
    );
};