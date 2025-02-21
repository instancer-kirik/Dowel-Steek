import React from 'react';
import { Editor } from './Editor';
import type { Note } from '../../types';

interface EditorTabsProps {
  notes: Note[];
  activeNoteId: string | null;
  onNoteSelect: (id: string) => void;
}

export const EditorTabs: React.FC<EditorTabsProps> = ({
  notes,
  activeNoteId,
  onNoteSelect
}) => {
  const activeNote = notes.find(note => note.id === activeNoteId);

  return (
    <div className="editor-tabs">
      <div className="tabs-header">
        {notes.map(note => (
          <div 
            key={note.id}
            className={`tab ${activeNoteId === note.id ? 'active' : ''}`}
            onClick={() => onNoteSelect(note.id)}
          >
            {note.title}
            <button onClick={(e) => {
              e.stopPropagation();
              // TODO: Handle tab close
            }}>×</button>
          </div>
        ))}
      </div>
      <div className="tab-content">
        {activeNote && <Editor note={activeNote} />}
      </div>
    </div>
  );
}; 