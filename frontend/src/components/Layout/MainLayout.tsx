import React from 'react';
import { Sidebar } from './Sidebar';
import { EditorTabs } from '../Editor/EditorTabs';
import { Toolbar } from '../Toolbar/Toolbar';
import type { Note } from '../../types';

interface MainLayoutProps {
  notes: Note[];
  activeNoteId: string | null;
  onNewNote: () => void;
  onSaveNote: (note: Note) => Promise<void>;
  onNoteSelect: (id: string) => void;
}

export const MainLayout: React.FC<MainLayoutProps> = ({
  notes,
  activeNoteId,
  onNewNote,
  onSaveNote,
  onNoteSelect
}) => {
  return (
    <div className="main-layout">
      <Toolbar onNewNote={onNewNote} onSave={() => {
        const activeNote = notes.find(n => n.id === activeNoteId);
        if (activeNote) onSaveNote(activeNote);
      }} />
      <div className="content-area">
        <Sidebar 
          notes={notes} 
          onNoteSelect={onNoteSelect}
        />
        <EditorTabs 
          notes={notes}
          activeNoteId={activeNoteId}
          onNoteSelect={onNoteSelect}
        />
      </div>
    </div>
  );
}; 