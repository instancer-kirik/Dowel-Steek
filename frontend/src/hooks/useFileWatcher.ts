import { useEffect } from 'react';

export function useFileWatcher(onFileChange: () => void) {
  useEffect(() => {
    const ws = new WebSocket(`ws://${window.location.host}/ws`);
    
    ws.onmessage = (event) => {
      const changes = JSON.parse(event.data);
      onFileChange();
    };

    return () => ws.close();
  }, [onFileChange]);
} 