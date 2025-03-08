import React, { useState, useEffect } from 'react';
import { MainLayout } from './components/Layout/MainLayout';
import type { Note } from './types';

function App() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [activeNoteId, setActiveNoteId] = useState<string | null>(null);

  useEffect(() => {
    fetch('/api/notes')
      .then(res => res.json())
      .then(data => {
        console.log('Loaded notes:', data);
        setNotes(data.notes || []);
      })
      .catch(error => {
        console.error('Failed to load notes:', error);
        setNotes([]);
      });
  }, []);

  const handleNewNote = () => {
    const newNote: Note = {
      id: crypto.randomUUID(),
      title: 'Untitled Note',
      content: '',
      tags: [],
      created: new Date(),
      modified: new Date(),
      path: '/unsorted'
    };
    setNotes(prevNotes => [...prevNotes, newNote]);
    setActiveNoteId(newNote.id);
  };

  const handleSaveNote = async (note: Note) => {
    try {
      const response = await fetch(`/api/notes/${note.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(note)
      });
      if (!response.ok) throw new Error('Failed to save note');
    } catch (error) {
      console.error('Error saving note:', error);
    }
  };

  return (
    <MainLayout 
      notes={notes}
      activeNoteId={activeNoteId}
      onNewNote={handleNewNote}
      onSaveNote={handleSaveNote}
      onNoteSelect={setActiveNoteId}
    />
  );
}

export default App; 