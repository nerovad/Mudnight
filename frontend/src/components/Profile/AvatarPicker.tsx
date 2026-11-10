// src/components/Profile/AvatarPicker.tsx
import React, { useState } from "react";
import "./AvatarPicker.scss";
import JawsAvatar from '../../assets/Jaws_Avatar.png';
import ClueAvatar from '../../assets/Clue_Avatar.png';
import TheThingAvatar from '../../assets/The_Thing_Avatar.png';

const AVATAR_COLLECTION = [
  { id: 'noir-1', url: JawsAvatar, category: 'noir' },
  { id: 'noir-2', url: ClueAvatar, category: 'noir' },
  { id: 'vintage-1', url: TheThingAvatar, category: 'vintage' },
];

interface AvatarPickerProps {
  isOpen: boolean;
  onClose: () => void;
  onSelect: (avatarUrl: string) => void;
  currentAvatar?: string;
}

const categories = [
  { id: 'all', label: 'All' },
  { id: 'noir', label: 'Film Noir' },
  { id: 'vintage', label: 'Vintage Cinema' },
  { id: 'abstract', label: 'Abstract' },
  { id: 'cinematic', label: 'Cinematic' }
];

const AvatarPicker: React.FC<AvatarPickerProps> = ({
  isOpen,
  onClose,
  onSelect,
  currentAvatar
}) => {
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedAvatar, setSelectedAvatar] = useState(currentAvatar);

  if (!isOpen) return null;

  const filteredAvatars = selectedCategory === 'all'
    ? AVATAR_COLLECTION
    : AVATAR_COLLECTION.filter(a => a.category === selectedCategory);

  const handleSelect = () => {
    if (selectedAvatar) {
      onSelect(selectedAvatar);
      onClose();
    }
  };

  return (
    <div className="avatar-picker-overlay">
      <div className="avatar-picker-modal">
        <div className="avatar-picker-header">
          <h3>Choose Your Avatar</h3>
          <button className="close-btn" onClick={onClose}>✕</button>
        </div>

        <div className="avatar-categories">
          {categories.map(cat => (
            <button
              key={cat.id}
              className={`category-btn ${selectedCategory === cat.id ? 'active' : ''}`}
              onClick={() => setSelectedCategory(cat.id)}
            >
              {cat.label}
            </button>
          ))}
        </div>

        <div className="avatar-grid">
          {filteredAvatars.map(avatar => (
            <div
              key={avatar.id}
              className={`avatar-option ${selectedAvatar === avatar.url ? 'selected' : ''}`}
              onClick={() => setSelectedAvatar(avatar.url)}
            >
              <img src={avatar.url} alt={avatar.id} />
              {selectedAvatar === avatar.url && (
                <div className="selected-indicator">✓</div>
              )}
            </div>
          ))}
        </div>

        <div className="avatar-picker-actions">
          <button className="btn ghost" onClick={onClose}>Cancel</button>
          <button
            className="btn primary"
            onClick={handleSelect}
            disabled={!selectedAvatar}
          >
            Confirm Selection
          </button>
        </div>
      </div>
    </div>
  );
};

export default AvatarPicker;
