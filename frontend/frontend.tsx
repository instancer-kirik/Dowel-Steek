// public/src/App.tsx
import React, { useState, useEffect } from 'react';
import { Editor } from './components/Editor';
import { NotesList } from './components/NotesList';
import { TagsList } from './components/TagsList';

interface Note {
    id: string;
    title: string;
    content: string;
    tags: string[];
    created: Date;
    modified: Date;
}

export const App: React.FC = () => {
    const [notes, setNotes] = useState<Note[]>([]);
    const [selectedNote, setSelectedNote] = useState<Note | null>(null);
    const [selectedTags, setSelectedTags] = useState<string[]>([]);

    useEffect(() => {
        fetchNotes();
    }, [selectedTags]);

    const fetchNotes = async () => {
        const response = await fetch('/api/v1/notes');
        const data = await response.json();
        setNotes(data);
    };

    return (
        <div className="app">
            <div className="sidebar">
                <TagsList 
                    selected={selectedTags}
                    onChange={setSelectedTags}
                />
                <NotesList 
                    notes={notes}
                    onSelect={setSelectedNote}
                />
            </div>
            <div className="main">
                {selectedNote && (
                    <Editor 
                        note={selectedNote}
                        onChange={async (note) => {
                            await fetch(`/api/v1/notes/${note.id}`, {
                                method: 'PUT',
                                headers: {'Content-Type': 'application/json'},
                                body: JSON.stringify(note)
                            });
                            fetchNotes();
                        }}
                    />
                )}
            </div>
        </div>
    );
};