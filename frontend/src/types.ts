export interface Note {
  id: string;
  title: string;
  content: string;
  tags: string[];
  path?: string;
  created: Date;
  modified: Date;
}

export interface FileNode {
  type: 'file' | 'directory';
  name: string;
  path: string;
  children?: FileNode[];
  note?: Note;
}

export interface ApiResponse {
  notes: FileNode[];
} 