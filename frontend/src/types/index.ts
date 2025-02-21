export interface Note {
    id: string;
    title: string;
    content: string;
    tags: string[];
    created: Date;
    modified: Date;
    path?: string;  // Optional path for file organization
}

export interface TouchToolbarProps {
    onCursorLeft: () => void;
    onCursorRight: () => void;
    onToggleSelect: () => void;
    onInsertLink: () => void;
} 