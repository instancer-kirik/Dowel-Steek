import React, { useState, useEffect } from 'react';
import { MainLayout } from './components/Layout/MainLayout';
import type { Note, FileNode, ApiResponse } from './types';
import { useFileWatcher } from './hooks/useFileWatcher';

function App() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [activeNoteId, setActiveNoteId] = useState<string | null>(null);

  const handleNewNote = () => {
    const newNote: Note = {
      id: crypto.randomUUID(),
      title: 'Untitled Note',
      content: '',
      tags: [],
      created: new Date(),
      modified: new Date()
    };
    setNotes([...notes, newNote]);
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
      // TODO: Add error notification
    }
  };

  useEffect(() => {
    const fetchNotes = async () => {
      console.log('About to fetch notes from:', window.location.origin + '/api/notes');
      try {
        console.log('Fetching notes...');
        const response = await fetch('/api/notes', {
          headers: {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache'
          }
        });
        console.log('Raw response:', response);
        console.log('Response status:', response.status);
        
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json() as ApiResponse;
        console.log('Received data:', data);
        
        // Handle empty or invalid response
        if (!data?.notes?.[0]) {
          console.warn('Empty or invalid response:', data);
          setNotes([]);
          return;
        }

        // Extract notes with proper type checking
        const children = data.notes[0].children || [];
        const extractedNotes = children
          .filter((child: unknown): child is FileNode & { note: Note } => {
            if (!child || typeof child !== 'object') return false;
            const c = child as any;
            return (
              c.type === 'file' &&
              c.note &&
              typeof c.note === 'object' &&
              typeof c.note.id === 'string' &&
              typeof c.note.title === 'string' &&
              typeof c.note.content === 'string' &&
              Array.isArray(c.note.tags)
            );
          })
          .map(child => child.note);
        
        console.log('Processed notes:', extractedNotes);
        setNotes(extractedNotes);
      } catch (error) {
        console.error('Failed to fetch notes:', error);
        setNotes([]);
      }
    };

    fetchNotes();
  }, []);

  useFileWatcher(() => {
    fetch('/api/notes')
      .then(res => {
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        return res.json() as Promise<ApiResponse>;
      })
      .then(data => {
        console.log('Watcher received data:', data);
        if (!data?.notes?.[0]) {
          console.warn('Empty or invalid response:', data);
          setNotes([]);
          return;
        }

        const children = data.notes[0].children || [];
        const extractedNotes = children
          .filter((child: unknown): child is FileNode & { note: Note } => {
            if (!child || typeof child !== 'object') return false;
            const c = child as any;
            return (
              c.type === 'file' &&
              c.note &&
              typeof c.note === 'object' &&
              typeof c.note.id === 'string' &&
              typeof c.note.title === 'string' &&
              typeof c.note.content === 'string' &&
              Array.isArray(c.note.tags)
            );
          })
          .map(child => child.note);
        setNotes(extractedNotes);
      })
      .catch(error => {
        console.error('Error in file watcher:', error);
        setNotes([]);
      });
  });

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