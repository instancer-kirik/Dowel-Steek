import React from 'react';
import { FileTree } from '../FileTree/FileTree';
import { TagList } from '../TagList/TagList';

export const Sidebar: React.FC = () => {
  return (
    <div className="sidebar">
      <div className="sidebar-section">
        <h3>Files</h3>
        <FileTree />
      </div>
      <div className="sidebar-section">
        <h3>Tags</h3>
        <TagList />
      </div>
    </div>
  );
}; 