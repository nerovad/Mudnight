import React, { useCallback, useEffect } from 'react';
import SchedulerWidget from '../Menu/SchedulerWidget';
import './SchedulerModal.scss';

interface Props {
  isOpen: boolean;
  onClose: () => void;
  channelSlug: string;
  channelName?: string;
}

/**
 * Standalone owner tool for programming a channel's 24/7 loop. Opened from the
 * owner's profile (per-channel "Scheduler" button) and auto-opened right after a
 * channel is created — not a viewer-facing menu widget.
 */
const SchedulerModal: React.FC<Props> = ({ isOpen, onClose, channelSlug, channelName }) => {
  const onKey = useCallback((e: KeyboardEvent) => {
    if (e.key === 'Escape') onClose();
  }, [onClose]);

  useEffect(() => {
    if (!isOpen) return;
    document.addEventListener('keydown', onKey);
    const original = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = original;
    };
  }, [isOpen, onKey]);

  if (!isOpen) return null;

  return (
    <div
      className="scheduler-modal-backdrop"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-label="Scheduler"
    >
      <div className="scheduler-modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="scheduler-modal-header">
          <h4>📺 Scheduler{channelName ? ` — ${channelName}` : ''}</h4>
          <button className="scheduler-modal-close" onClick={onClose} aria-label="Close scheduler">×</button>
        </div>
        <div className="scheduler-modal-body">
          <SchedulerWidget channelId={channelSlug} />
        </div>
      </div>
    </div>
  );
};

export default SchedulerModal;
