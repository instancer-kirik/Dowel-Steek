import React, { useState } from 'react';
import { Settings } from '../Settings/Settings';

interface ToolbarProps {
  onNewNote: () => void;
  onSave: () => void;
}

export const Toolbar: React.FC<ToolbarProps> = ({ onNewNote, onSave }) => {
  const [showSettings, setShowSettings] = useState(false);

  return (
    <>
      <div className="toolbar">
        <button onClick={onNewNote}>New Note</button>
        <button onClick={onSave}>Save</button>
        <button onClick={() => alert('Search coming soon!')}>Search</button>
        <button onClick={() => setShowSettings(true)}>Settings</button>
      </div>

      <Settings 
        isOpen={showSettings}
        onClose={() => setShowSettings(false)}
      />
    </>
  );
}; 