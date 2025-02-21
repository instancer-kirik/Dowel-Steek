import React from 'react';

interface SettingsProps {
  isOpen: boolean;
  onClose: () => void;
}

export interface AppSettings {
  theme: 'light' | 'dark';
  fontSize: number;
  autoSave: boolean;
  defaultDirectory: string;
  hotReload: boolean;
}

export const Settings: React.FC<SettingsProps> = ({ isOpen, onClose }) => {
  const [settings, setSettings] = React.useState<AppSettings>({
    theme: 'light',
    fontSize: 14,
    autoSave: true,
    defaultDirectory: '/unsorted',
    hotReload: true
  });

  if (!isOpen) return null;

  return (
    <div className="modal-overlay">
      <div className="modal settings-modal">
        <h2>Settings</h2>
        
        <div className="settings-group">
          <h3>Appearance</h3>
          <label>
            Theme
            <select 
              value={settings.theme}
              onChange={e => setSettings(s => ({ ...s, theme: e.target.value as 'light' | 'dark' }))}
            >
              <option value="light">Light</option>
              <option value="dark">Dark</option>
            </select>
          </label>

          <label>
            Font Size
            <input 
              type="number"
              value={settings.fontSize}
              onChange={e => setSettings(s => ({ ...s, fontSize: parseInt(e.target.value) }))}
              min={8}
              max={32}
            />
          </label>
        </div>

        <div className="settings-group">
          <h3>Editor</h3>
          <label>
            <input 
              type="checkbox"
              checked={settings.autoSave}
              onChange={e => setSettings(s => ({ ...s, autoSave: e.target.checked }))}
            />
            Auto-save
          </label>
        </div>

        <div className="settings-group">
          <h3>Files</h3>
          <label>
            Default Directory
            <input 
              type="text"
              value={settings.defaultDirectory}
              onChange={e => setSettings(s => ({ ...s, defaultDirectory: e.target.value }))}
            />
          </label>

          <label>
            <input 
              type="checkbox"
              checked={settings.hotReload}
              onChange={e => setSettings(s => ({ ...s, hotReload: e.target.checked }))}
            />
            Hot Reload Files
          </label>
        </div>

        <div className="modal-actions">
          <button onClick={onClose}>Cancel</button>
          <button 
            className="primary"
            onClick={() => {
              // Save settings
              localStorage.setItem('app-settings', JSON.stringify(settings));
              onClose();
            }}
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}; 