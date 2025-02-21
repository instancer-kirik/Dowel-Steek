import React, { useState, useEffect } from 'react';
import type { Note } from '../../types';

interface EditorProps {
  note: Note;
}

export const Editor: React.FC<EditorProps> = ({ note }) => {
  const [title, setTitle] = useState(note.title);
  const [content, setContent] = useState(note.content);
  const [tags, setTags] = useState(note.tags.join(', '));

  useEffect(() => {
    setTitle(note.title);
    setContent(note.content);
    setTags(note.tags.join(', '));
  }, [note]);

  return (
    <div className="editor">
      <div className="editor-header">
        <input 
          type="text" 
          value={title}
          onChange={e => setTitle(e.target.value)}
          placeholder="Title" 
          className="title-input" 
        />
        <input 
          type="text" 
          value={tags}
          onChange={e => setTags(e.target.value)}
          placeholder="Tags (comma separated)" 
          className="tags-input" 
        />
      </div>
      <div className="editor-content">
        <textarea 
          className="editor-textarea"
          value={content}
          onChange={e => setContent(e.target.value)}
          placeholder="Start writing..."
        />
        <div className="preview-pane">
          {/* TODO: Add markdown preview */}
          {content}
        </div>
      </div>
    </div>
  );
}; 