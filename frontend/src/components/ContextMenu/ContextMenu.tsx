import React from 'react';

interface ContextMenuItem {
  label: string;
  action: () => void;
  icon?: string;
}

interface ContextMenuProps {
  x: number;
  y: number;
  items: ContextMenuItem[];
  onClose: () => void;
}

export const ContextMenu: React.FC<ContextMenuProps> = ({ x, y, items, onClose }) => {
  React.useEffect(() => {
    const handleClick = () => onClose();
    document.addEventListener('click', handleClick);
    return () => document.removeEventListener('click', handleClick);
  }, [onClose]);

  return (
    <div 
      className="context-menu"
      style={{ left: x, top: y }}
    >
      {items.map((item, i) => (
        <div 
          key={i} 
          className="context-menu-item"
          onClick={item.action}
        >
          {item.icon && <span className="item-icon">{item.icon}</span>}
          {item.label}
        </div>
      ))}
    </div>
  );
}; 