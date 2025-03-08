import React from 'react';
import { FileTree } from '../FileTree/FileTree';
import { TagList } from '../TagList/TagList';
import type { Note } from '../../types';

interface SidebarProps {
  notes: Note[];
  onNoteSelect: (id: string) => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ notes, onNoteSelect }) => {
  const handleNoteMove = (noteId: string, newPath: string) => {
    // TODO: Implement note moving functionality
    console.log('Moving note', noteId, 'to', newPath);
  };

  const handleCreateDirectory = (path: string) => {
    // TODO: Implement directory creation
    console.log('Creating directory at', path);
  };

  return (
    <div className="sidebar">
      <div className="sidebar-section">
        <h3>Files</h3>
        <FileTree 
          notes={notes}
          onNoteSelect={onNoteSelect}
          onNoteMove={handleNoteMove}
          onCreateDirectory={handleCreateDirectory}
        />
      </div>
      <div className="sidebar-section">
        <h3>Tags</h3>
        <TagList />
      </div>
    </div>
  );
}; 