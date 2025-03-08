import React, { useState } from 'react';
import { ContextMenu } from '../ContextMenu/ContextMenu';
import type { Note } from '../../types';

interface FileTreeProps {
  notes: Note[];
  onNoteSelect: (id: string) => void;
  onNoteMove: (noteId: string, newPath: string) => void;
  onCreateDirectory: (path: string) => void;
}

interface FileNode {
  type: 'file' | 'directory';
  name: string;
  path: string;
  children?: FileNode[];
  note?: Note;
}

export const FileTree: React.FC<FileTreeProps> = ({
  notes = [],
  onNoteSelect,
  onNoteMove,
  onCreateDirectory
}) => {
  const [contextMenu, setContextMenu] = useState<{x: number, y: number, node: FileNode} | null>(null);
  const [expandedDirs, setExpandedDirs] = useState<Set<string>>(new Set(['/']));

  // Build tree structure from flat notes array
  const buildTree = (notes: Note[]): FileNode[] => {
    if (!notes || !Array.isArray(notes)) {
      console.warn('Notes is not an array:', notes);
      return [];
    }

    const root: { [key: string]: FileNode } = {
      '/': {
        type: 'directory',
        name: 'Root',
        path: '/',
        children: []
      }
    };
    
    // First pass: Create directories
    notes.forEach(note => {
      if (!note) return;
      const path = note.path || '/unsorted';
      const parts = path.split('/').filter(Boolean);
      let currentPath = '';
      
      parts.forEach((part: string) => {
        currentPath += '/' + part;
        if (!root[currentPath]) {
          root[currentPath] = {
            type: 'directory',
            name: part,
            path: currentPath,
            children: []
          };
        }
      });
    });

    // Second pass: Add files
    notes.forEach(note => {
      if (!note) return;
      const path = note.path || '/unsorted';
      const dir = path.substring(0, path.lastIndexOf('/')) || '/';
      const fileNode: FileNode = {
        type: 'file',
        name: note.title || 'Untitled',
        path: path + '/' + (note.title || 'Untitled'),
        note
      };
      
      if (root[dir]) {
        root[dir].children = root[dir].children || [];
        root[dir].children.push(fileNode);
      } else {
        // If directory doesn't exist, add to root
        root['/'].children = root['/'].children || [];
        root['/'].children.push(fileNode);
      }
    });

    // Build the tree hierarchy
    Object.values(root).forEach(node => {
      if (node.path === '/') return;
      const parentPath = node.path.substring(0, node.path.lastIndexOf('/')) || '/';
      const parent = root[parentPath];
      if (parent && node.type === 'directory') {
        parent.children = parent.children || [];
        parent.children.push(node);
      }
    });

    return root['/'].children || [];
  };

  const handleContextMenu = (e: React.MouseEvent, node: FileNode) => {
    e.preventDefault();
    setContextMenu({
      x: e.clientX,
      y: e.clientY,
      node
    });
  };

  const renderNode = (node: FileNode) => {
    const isExpanded = expandedDirs.has(node.path);
    
    return (
      <li key={node.path}>
        <div 
          className={`tree-node ${node.type}`}
          onClick={() => {
            if (node.type === 'file' && node.note) {
              onNoteSelect(node.note.id);
            } else {
              setExpandedDirs(prev => {
                const next = new Set(prev);
                if (isExpanded) next.delete(node.path);
                else next.add(node.path);
                return next;
              });
            }
          }}
          onContextMenu={e => handleContextMenu(e, node)}
        >
          {node.type === 'directory' ? (isExpanded ? '📁' : '📂') : '📝'} {node.name}
        </div>
        {node.type === 'directory' && isExpanded && node.children && (
          <ul>
            {node.children.map(child => renderNode(child))}
          </ul>
        )}
      </li>
    );
  };

  const tree = buildTree(notes);

  return (
    <div className="file-tree">
      <ul>
        {tree.map(node => renderNode(node))}
      </ul>
      {contextMenu && (
        <ContextMenu
          x={contextMenu.x}
          y={contextMenu.y}
          items={[
            {
              label: 'New Directory',
              icon: '📁',
              action: () => {
                const name = prompt('Directory name:');
                if (name) {
                  onCreateDirectory(contextMenu.node.path + '/' + name);
                }
              }
            },
            {
              label: 'Move to...',
              icon: '📦',
              action: () => {
                // TODO: Show directory picker
              }
            }
          ]}
          onClose={() => setContextMenu(null)}
        />
      )}
    </div>
  );
};

function findSimilarNotes(note: Note, allNotes: Note[]): Note[] {
  const normalize = (s: string) => s.toLowerCase().replace(/[^a-z0-9]/g, '');
  const baseTitle = normalize(note.title);
  
  return allNotes.filter(other => {
    if (other.id === note.id) return false;
    const otherTitle = normalize(other.title);
    
    // Check for similar titles
    const distance = levenshteinDistance(baseTitle, otherTitle);
    const similarity = 1 - (distance / Math.max(baseTitle.length, otherTitle.length));
    
    return similarity > 0.8; // 80% similar
  });
}

function levenshteinDistance(a: string, b: string): number {
  const matrix = [];

  for (let i = 0; i <= b.length; i++) {
    matrix[i] = [i];
  }

  for (let j = 0; j <= a.length; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= b.length; i++) {
    for (let j = 1; j <= a.length; j++) {
      if (b.charAt(i-1) === a.charAt(j-1)) {
        matrix[i][j] = matrix[i-1][j-1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i-1][j-1] + 1,
          matrix[i][j-1] + 1,
          matrix[i-1][j] + 1
        );
      }
    }
  }

  return matrix[b.length][a.length];
} 