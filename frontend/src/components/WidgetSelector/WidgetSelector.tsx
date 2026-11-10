import React from 'react';
import './WidgetSelector.scss';

export type WidgetType =
  | 'voting_ballot'
  | 'leaderboard'
  | 'battle_royale'
  | 'tournament_bracket'
  | 'about'
  | 'now_playing'
  | 'contributions';

export interface WidgetConfig {
  type: WidgetType;
  order: number;
}

interface WidgetOption {
  type: WidgetType;
  name: string;
  description: string;
  icon: string;
  requiresEventType?: string; // If set, widget is only available for this event type
  alwaysAvailable?: boolean;  // If true, widget is always available
}

// Widgets grouped by availability
const ALWAYS_AVAILABLE_WIDGETS: WidgetOption[] = [
  {
    type: 'about',
    name: 'About',
    description: 'Channel info and description',
    icon: 'ℹ️',
    alwaysAvailable: true
  },
  {
    type: 'now_playing',
    name: 'Now Playing / Up Next',
    description: 'Current and upcoming content',
    icon: '📺',
    alwaysAvailable: true
  },
  {
    type: 'contributions',
    name: 'Contributions',
    description: 'Let viewers pitch films to your schedule',
    icon: '🤝',
    alwaysAvailable: true
  }
];

const EVENT_SPECIFIC_WIDGETS: WidgetOption[] = [
  {
    type: 'voting_ballot',
    name: 'Voting Ballot',
    description: 'Rate and support your favorite entries (1-10)',
    icon: '🗳️',
    requiresEventType: 'film_festival'
  },
  {
    type: 'leaderboard',
    name: 'Leaderboard',
    description: 'Top-ranked filmmakers',
    icon: '🏆',
    requiresEventType: 'film_festival'
  },
  {
    type: 'battle_royale',
    name: 'Battle Royale',
    description: 'Head-to-head matchups',
    icon: '⚔️',
    requiresEventType: 'battle_royal'
  },
  {
    type: 'tournament_bracket',
    name: 'Tournament Bracket',
    description: 'Competition progression',
    icon: '🏅',
    requiresEventType: 'tournament'
  }
];

interface Props {
  eventType?: string;
  addEvent?: boolean;
  selectedWidgets: WidgetConfig[];
  onChange: (widgets: WidgetConfig[]) => void;
  /** Now Playing is only offered once the channel has a schedule (see Scheduler). */
  channelScheduled?: boolean;
}

const WidgetSelector: React.FC<Props> = ({ eventType, addEvent = false, selectedWidgets, onChange, channelScheduled = false }) => {
  const toggleWidget = (widgetType: WidgetType) => {
    const exists = selectedWidgets.find(w => w.type === widgetType);

    if (exists) {
      // Remove widget
      onChange(selectedWidgets.filter(w => w.type !== widgetType));
    } else {
      // Add widget with next order
      const maxOrder = Math.max(...selectedWidgets.map(w => w.order), -1);
      onChange([...selectedWidgets, { type: widgetType, order: maxOrder + 1 }]);
    }
  };

  const isSelected = (widgetType: WidgetType) => {
    return selectedWidgets.some(w => w.type === widgetType);
  };

  const isWidgetAvailable = (widget: WidgetOption) => {
    if (widget.alwaysAvailable) return true;
    if (!addEvent) return false;
    return widget.requiresEventType === eventType;
  };

  const getEventTypeName = (eventTypeKey?: string) => {
    switch (eventTypeKey) {
      case 'film_festival': return 'Film Festival';
      case 'battle_royal': return 'Battle Royale';
      case 'tournament': return 'Tournament';
      default: return eventTypeKey;
    }
  };

  // Get available event-specific widgets for the current event type
  const availableEventWidgets = EVENT_SPECIFIC_WIDGETS.filter(w => isWidgetAvailable(w));
  const unavailableEventWidgets = EVENT_SPECIFIC_WIDGETS.filter(w => !isWidgetAvailable(w));

  return (
    <div className="widget-selector">
      <h4>Channel Widgets</h4>
      <p className="help-text">Select which widgets to display in your channel menu.</p>

      {/* Always Available Widgets */}
      <div className="widget-section">
        <h5 className="widget-section-title">General Widgets</h5>
        <div className="widget-grid">
          {ALWAYS_AVAILABLE_WIDGETS.map(widget => {
            // Now Playing only makes sense on a scheduled channel — lock it until
            // the owner builds a loop in the Scheduler.
            const locked = widget.type === 'now_playing' && !channelScheduled;
            if (locked) {
              return (
                <div
                  key={widget.type}
                  className="widget-option disabled"
                  title="Add clips in the Scheduler to enable this widget"
                >
                  <input type="checkbox" checked={false} disabled onChange={() => {}} />
                  <div className="widget-card">
                    <span className="widget-icon">{widget.icon}</span>
                    <div className="widget-info">
                      <strong>{widget.name}</strong>
                      <span className="badge locked">Needs a schedule</span>
                      <p>{widget.description}</p>
                    </div>
                  </div>
                </div>
              );
            }
            return (
              <label
                key={widget.type}
                className={`widget-option ${isSelected(widget.type) ? 'selected' : ''}`}
              >
                <input
                  type="checkbox"
                  checked={isSelected(widget.type)}
                  onChange={() => toggleWidget(widget.type)}
                />
                <div className="widget-card">
                  <span className="widget-icon">{widget.icon}</span>
                  <div className="widget-info">
                    <strong>{widget.name}</strong>
                    <p>{widget.description}</p>
                  </div>
                </div>
              </label>
            );
          })}
        </div>
      </div>

      {/* Event-Specific Widgets */}
      <div className="widget-section">
        <h5 className="widget-section-title">Event Widgets</h5>
        {!addEvent ? (
          <p className="help-text disabled-hint">Add an event below to unlock event-specific widgets.</p>
        ) : (
          <p className="help-text">Widgets available for {getEventTypeName(eventType)} events:</p>
        )}

        <div className="widget-grid">
          {/* Available event widgets */}
          {availableEventWidgets.map(widget => (
            <label
              key={widget.type}
              className={`widget-option ${isSelected(widget.type) ? 'selected' : ''}`}
            >
              <input
                type="checkbox"
                checked={isSelected(widget.type)}
                onChange={() => toggleWidget(widget.type)}
              />
              <div className="widget-card">
                <span className="widget-icon">{widget.icon}</span>
                <div className="widget-info">
                  <strong>{widget.name}</strong>
                  <span className="badge available">Available</span>
                  <p>{widget.description}</p>
                </div>
              </div>
            </label>
          ))}

          {/* Unavailable event widgets (shown as disabled) */}
          {unavailableEventWidgets.map(widget => (
            <div
              key={widget.type}
              className="widget-option disabled"
              title={!addEvent
                ? "Add an event to enable this widget"
                : `Requires ${getEventTypeName(widget.requiresEventType)} event type`}
            >
              <input
                type="checkbox"
                checked={false}
                disabled
                onChange={() => {}}
              />
              <div className="widget-card">
                <span className="widget-icon">{widget.icon}</span>
                <div className="widget-info">
                  <strong>{widget.name}</strong>
                  <span className="badge locked">
                    {!addEvent ? 'Needs Event' : getEventTypeName(widget.requiresEventType)}
                  </span>
                  <p>{widget.description}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default WidgetSelector;
