import React, { useEffect, useState } from 'react';
import './TournamentConsole.scss';

interface Matchup {
  id: string;
  matchupId: string;
  round: number;
  position: number;
  film1Title: string;
  film2Title: string;
  votes1: number;
  votes2: number;
  winnerId: string | null;
  completed: boolean;
}

interface TournamentStatus {
  currentRound: number;
  totalRounds: number;
  isComplete: boolean;
  votingWindow: {
    isActive: boolean;
    currentRound: number | null;
  };
  rounds: {
    [round: number]: Matchup[];
  };
}

interface Props {
  channelId: string;
  sessionId: string;
  onClose: () => void;
}

const TournamentConsole: React.FC<Props> = ({ channelId, sessionId, onClose }) => {
  const [status, setStatus] = useState<TournamentStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => {
    loadStatus();
    // Poll for updates every 5 seconds
    const interval = setInterval(loadStatus, 5000);
    return () => clearInterval(interval);
  }, [channelId, sessionId]);

  const loadStatus = async () => {
    try {
      const response = await fetch(`/api/tournaments/${sessionId}/status`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        }
      });

      if (!response.ok) {
        throw new Error('Failed to load tournament status');
      }

      const data = await response.json();
      setStatus(data);
      setError(null);
    } catch (err) {
      console.error('Error loading status:', err);
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  const startVoting = async (round: number) => {
    if (!confirm(`Start voting for Round ${round}?`)) return;

    try {
      setActionLoading(true);
      const response = await fetch(`/api/tournaments/${sessionId}/voting/start`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        },
        body: JSON.stringify({ round })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to start voting');
      }

      await loadStatus();
      alert(`Voting started for Round ${round}`);
    } catch (err) {
      console.error('Error starting voting:', err);
      alert(err instanceof Error ? err.message : 'Failed to start voting');
    } finally {
      setActionLoading(false);
    }
  };

  const endVoting = async () => {
    if (!status?.votingWindow.isActive) return;

    const round = status.votingWindow.currentRound;
    if (!confirm(`End voting for Round ${round} and advance winners?`)) return;

    try {
      setActionLoading(true);
      const response = await fetch(`/api/tournaments/${sessionId}/voting/end`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        }
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to end voting');
      }

      const result = await response.json();
      await loadStatus();
      alert(`Voting ended. ${result.winnersAdvanced} winner(s) advanced to next round.`);
    } catch (err) {
      console.error('Error ending voting:', err);
      alert(err instanceof Error ? err.message : 'Failed to end voting');
    } finally {
      setActionLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="tournament-console-modal">
        <div className="modal-overlay" onClick={onClose}></div>
        <div className="modal-content">
          <div className="tournament-console loading">
            <div className="spinner">Loading console...</div>
          </div>
        </div>
      </div>
    );
  }

  if (error || !status) {
    return (
      <div className="tournament-console-modal">
        <div className="modal-overlay" onClick={onClose}></div>
        <div className="modal-content">
          <div className="tournament-console error">
            <button className="modal-close" onClick={onClose}>×</button>
            <p>Error: {error || 'Failed to load tournament'}</p>
          </div>
        </div>
      </div>
    );
  }

  const { votingWindow, currentRound, totalRounds, isComplete } = status;

  return (
    <div className="tournament-console-modal">
      <div className="modal-overlay" onClick={onClose}></div>
      <div className="modal-content">
        <div className="tournament-console">
          <button className="modal-close" onClick={onClose}>×</button>
          <div className="console-header">
            <h2>🎮 Tournament Console</h2>
            <div className="tournament-info">
              <span className="info-item">Round {currentRound} of {totalRounds}</span>
              {isComplete ? (
                <span className="status-badge complete">Complete</span>
              ) : (
                <span className={`status-badge ${votingWindow.isActive ? 'active' : 'inactive'}`}>
                  {votingWindow.isActive ? 'Voting Active' : 'Voting Inactive'}
                </span>
              )}
            </div>
          </div>

          {!isComplete && (
            <div className="console-controls">
              <div className="control-section">
                <h3>Voting Controls</h3>
                {votingWindow.isActive ? (
                  <div className="active-voting">
                    <p className="voting-status">
                      🟢 Voting is currently active for Round {votingWindow.currentRound}
                    </p>
                    <button
                      className="btn btn-danger"
                      onClick={endVoting}
                      disabled={actionLoading}
                    >
                      {actionLoading ? 'Processing...' : 'End Voting & Advance Winners'}
                    </button>
                  </div>
                ) : (
                  <div className="inactive-voting">
                    <p className="voting-status">⚫ No active voting window</p>
                    <button
                      className="btn btn-primary"
                      onClick={() => startVoting(currentRound)}
                      disabled={actionLoading}
                    >
                      {actionLoading ? 'Starting...' : `Start Voting for Round ${currentRound}`}
                    </button>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Round Overview */}
          <div className="rounds-overview">
            <h3>Rounds Overview</h3>
            {Object.entries(status.rounds).map(([roundNum, matchups]) => {
              const round = parseInt(roundNum);
              const totalMatchups = matchups.length;
              const completedMatchups = matchups.filter(m => m.completed || m.winnerId).length;
              const isCurrentRound = round === currentRound;
              const isVotingRound = votingWindow.isActive && round === votingWindow.currentRound;

              return (
                <div
                  key={round}
                  className={`round-card ${isCurrentRound ? 'current' : ''} ${isVotingRound ? 'voting' : ''}`}
                >
                  <div className="round-header">
                    <h4>Round {round}</h4>
                    <div className="round-status">
                      {isVotingRound && <span className="badge voting">Voting Active</span>}
                      <span className="progress-badge">
                        {completedMatchups}/{totalMatchups} Complete
                      </span>
                    </div>
                  </div>

                  <div className="matchups-list">
                    {matchups.map((matchup, idx) => {
                      const totalVotes = matchup.votes1 + matchup.votes2;
                      const isDecided = matchup.completed || matchup.winnerId;

                      return (
                        <div key={matchup.id} className={`matchup-item ${isDecided ? 'decided' : ''}`}>
                          <div className="matchup-number">#{idx + 1}</div>
                          <div className="matchup-details">
                            <div className="film-vs">
                              <span className={matchup.winnerId === matchup.film1Title ? 'winner' : ''}>
                                {matchup.film1Title} ({matchup.votes1})
                              </span>
                              <span className="vs">vs</span>
                              <span className={matchup.winnerId === matchup.film2Title ? 'winner' : ''}>
                                {matchup.film2Title} ({matchup.votes2})
                              </span>
                            </div>
                            <div className="matchup-stats">
                              <span className="total-votes">{totalVotes} total votes</span>
                              {isDecided && <span className="decided-badge">✓ Decided</span>}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>

          {isComplete && (
            <div className="tournament-complete">
              <h3>🏆 Tournament Complete!</h3>
              <p>All rounds have been completed and a champion has been crowned.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default TournamentConsole;
