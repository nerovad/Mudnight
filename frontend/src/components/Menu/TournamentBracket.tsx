import React, { useEffect, useState } from 'react';
import './TournamentBracket.scss';

interface Film {
  filmId: string;
  seed: number;
  title: string;
  creator?: string;
  thumbnail?: string;
}

interface Matchup {
  id: string;
  position: number;
  roundNumber: number;
  film1: Film | null;
  film2: Film | null;
  votes1: number;
  votes2: number;
  winner?: string;
  dbMatchupId?: string;
}

interface Round {
  roundNumber: number;
  roundName: string;
  matchups: Matchup[];
}

interface TournamentData {
  id: string;
  channelName: string;
  status: "upcoming" | "active" | "completed";
  currentRound: number;
  rounds: Round[];
  startsAt: string;
  endsAt: string;
  votingWindow?: {
    isActive: boolean;
    currentRound: number | null;
  };
}

interface Props {
  channelId: string;
}

const TournamentBracket: React.FC<Props> = ({ channelId }) => {
  const [tournament, setTournament] = useState<TournamentData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [votingFor, setVotingFor] = useState<string | null>(null);
  const [userVotes, setUserVotes] = useState<Record<string, string>>({}); // matchupId -> filmId
  const [showConfetti, setShowConfetti] = useState(false);
  const [hasShownConfetti, setHasShownConfetti] = useState(false);

  useEffect(() => {
    loadTournament();

    // ✅ Poll for updates every 5 seconds to catch round changes
    const interval = setInterval(loadTournament, 5000);
    return () => clearInterval(interval);
  }, [channelId]);

  // Helper function to find the champion
  const getChampion = (): { film: Film; matchup: Matchup } | null => {
    if (!tournament || !tournament.rounds || tournament.rounds.length === 0) return null;

    const finalRound = tournament.rounds[tournament.rounds.length - 1];
    if (!finalRound || finalRound.matchups.length === 0) return null;

    const finalMatchup = finalRound.matchups[0];
    if (!finalMatchup.winner) return null;

    const championFilm = finalMatchup.winner === finalMatchup.film1?.filmId
      ? finalMatchup.film1
      : finalMatchup.film2;

    if (!championFilm) return null;

    return { film: championFilm, matchup: finalMatchup };
  };

  // Check if tournament has a champion (final round winner exists)
  const hasChampion = (): boolean => {
    return getChampion() !== null;
  };

  // Trigger confetti when a champion is crowned
  useEffect(() => {
    if (tournament && hasChampion() && !hasShownConfetti) {
      console.log('🎉 Champion detected! Triggering confetti...');
      setShowConfetti(true);
      setHasShownConfetti(true);

      // Auto-hide confetti after 10 seconds
      const timer = setTimeout(() => setShowConfetti(false), 10000);
      return () => clearTimeout(timer);
    }
  }, [tournament, hasShownConfetti]);

  const loadTournament = async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await fetch(`/api/channels/${channelId}/tournament`, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        }
      });

      if (!response.ok) {
        throw new Error('Failed to load tournament');
      }

      const data = await response.json();
      console.log('Tournament data received:', data);
      setTournament(data);
    } catch (err) {
      console.error('Error loading tournament:', err);
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  const handleFilmClick = async (matchup: Matchup, filmId: string) => {
    // Check if voting is active
    if (!tournament?.votingWindow?.isActive) {
      alert('Voting is not currently active');
      return;
    }

    if (tournament.votingWindow.currentRound !== matchup.roundNumber) {
      alert(`Voting is active for Round ${tournament.votingWindow.currentRound}, not Round ${matchup.roundNumber}`);
      return;
    }

    // Check if matchup is already completed
    if (matchup.winner) {
      alert('This matchup has already been decided');
      return;
    }

    const matchupKey = matchup.dbMatchupId || matchup.id;
    const currentVote = userVotes[matchupKey];

    try {
      setVotingFor(matchupKey);

      // If clicking the same film they already voted for, undo the vote
      if (currentVote === filmId) {
        const response = await fetch(`/api/tournaments/matchups/${matchup.dbMatchupId}/vote`, {
          method: 'DELETE',
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('token')}`
          }
        });

        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.error || 'Failed to undo vote');
        }

        // Remove the vote from userVotes
        setUserVotes(prev => {
          const updated = { ...prev };
          delete updated[matchupKey];
          return updated;
        });
      } else {
        // Either voting for the first time or switching to a different film
        const response = await fetch(`/api/tournaments/matchups/${matchup.dbMatchupId}/vote`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${localStorage.getItem('token')}`
          },
          body: JSON.stringify({ film_id: filmId })
        });

        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.error || 'Failed to submit vote');
        }

        // Update userVotes with the new film
        setUserVotes(prev => ({ ...prev, [matchupKey]: filmId }));
      }

      // Reload tournament to get updated vote counts
      await loadTournament();
    } catch (err) {
      console.error('Error voting:', err);
      alert(err instanceof Error ? err.message : 'Failed to submit vote');
    } finally {
      setVotingFor(null);
    }
  };

  const getVotePercentage = (votes: number, totalVotes: number): number => {
    if (totalVotes === 0) return 0;
    return Math.round((votes / totalVotes) * 100);
  };

  if (loading) {
    return (
      <div className="tournament-bracket loading">
        <div className="spinner">Loading tournament...</div>
      </div>
    );
  }

  if (error || !tournament) {
    return (
      <div className="tournament-bracket error">
        <p>Error: {error || 'Tournament not found'}</p>
      </div>
    );
  }

  // Additional check for rounds data
  if (!tournament.rounds || tournament.rounds.length === 0) {
    return (
      <div className="tournament-bracket error">
        <p>No tournament rounds available. The tournament may not be set up yet.</p>
      </div>
    );
  }

  const { status, currentRound, rounds, votingWindow } = tournament;
  const champion = getChampion();
  const tournamentHasChampion = hasChampion();

  return (
    <div className="tournament-bracket">
      {/* Confetti overlay */}
      {showConfetti && (
        <div className="confetti-container">
          {[...Array(50)].map((_, i) => (
            <div
              key={i}
              className="confetti-piece"
              style={{
                left: `${Math.random() * 100}%`,
                animationDelay: `${Math.random() * 3}s`,
                backgroundColor: ['#00ff41', '#ff006e', '#8338ec', '#ffbe0b'][Math.floor(Math.random() * 4)]
              }}
            />
          ))}
        </div>
      )}

      {/* Status Bar */}
      <div className="tournament-status-bar">
        {tournamentHasChampion ? (
          <div className="status-badge complete">
            🏆 Champion Crowned!
          </div>
        ) : status === 'completed' ? (
          <div className="status-badge complete">
            Tournament Complete
          </div>
        ) : (
          <>
            <div className="status-badge in-progress">
              Round {currentRound} of {rounds.length}
            </div>
            {votingWindow && (
              <div className={`voting-status ${votingWindow.isActive ? 'active' : 'inactive'}`}>
                {votingWindow.isActive ? (
                  <>🟢 Voting Active (Round {votingWindow.currentRound})</>
                ) : (
                  <>⚫ Voting Closed</>
                )}
              </div>
            )}
          </>
        )}
      </div>

      {/* Bracket Grid */}
      <div className="bracket-container">
        {rounds.map((round, roundIndex) => (
          <div key={roundIndex} className="bracket-round">
            <div className="round-header">
              {round.roundName}
            </div>
            <div className="matchups">
              {round.matchups.map((matchup) => {
                const totalVotes = matchup.votes1 + matchup.votes2;
                const isVotingActive =
                  votingWindow?.isActive &&
                  votingWindow.currentRound === matchup.roundNumber &&
                  !matchup.winner;
                return (
                  <div key={matchup.id} className="matchup">
                    {/* Film 1 */}
                    {matchup.film1 ? (
                      <div
                        className={`film-slot ${matchup.winner === matchup.film1.filmId ? 'winner' : ''
                          } ${userVotes[matchup.dbMatchupId || matchup.id] === matchup.film1.filmId ? 'user-voted' : ''
                          } ${isVotingActive ? 'votable' : ''
                          } ${votingFor === (matchup.dbMatchupId || matchup.id) ? 'voting' : ''
                          }`}
                        onClick={() => {
                          if (isVotingActive) {
                            handleFilmClick(matchup, matchup.film1!.filmId);
                          }
                        }}
                      >
                        <div className="film-seed">#{matchup.film1.seed}</div>
                        {matchup.film1.thumbnail && (
                          <img
                            src={matchup.film1.thumbnail}
                            alt={matchup.film1.title}
                            className="film-thumbnail"
                          />
                        )}
                        <div className="film-info">
                          <h3 className="film-title">{matchup.film1.title}</h3>
                          {matchup.film1.creator && (
                            <p className="film-creator">{matchup.film1.creator}</p>
                          )}
                        </div>
                        {totalVotes > 0 && (
                          <div className="vote-stats">
                            <div className="vote-count">{matchup.votes1} votes</div>
                            <div className="vote-bar">
                              <div
                                className="vote-fill"
                                style={{ width: `${getVotePercentage(matchup.votes1, totalVotes)}%` }}
                              />
                            </div>
                            <div className="vote-pct">
                              {getVotePercentage(matchup.votes1, totalVotes)}%
                            </div>
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="film-slot bye">BYE</div>
                    )}

                    {/* VS Divider */}
                    <div className="vs-divider">VS</div>

                    {/* Film 2 */}
                    {matchup.film2 ? (
                      <div
                        className={`film-slot ${matchup.winner === matchup.film2.filmId ? 'winner' : ''
                          } ${userVotes[matchup.dbMatchupId || matchup.id] === matchup.film2.filmId ? 'user-voted' : ''
                          } ${isVotingActive ? 'votable' : ''
                          } ${votingFor === (matchup.dbMatchupId || matchup.id) ? 'voting' : ''
                          }`}
                        onClick={() => {
                          if (isVotingActive) {
                            handleFilmClick(matchup, matchup.film2!.filmId);
                          }
                        }}
                      >
                        <div className="film-seed">#{matchup.film2.seed}</div>
                        {matchup.film2.thumbnail && (
                          <img
                            src={matchup.film2.thumbnail}
                            alt={matchup.film2.title}
                            className="film-thumbnail"
                          />
                        )}
                        <div className="film-info">
                          <h3 className="film-title">{matchup.film2.title}</h3>
                          {matchup.film2.creator && (
                            <p className="film-creator">{matchup.film2.creator}</p>
                          )}
                        </div>
                        {totalVotes > 0 && (
                          <div className="vote-stats">
                            <div className="vote-count">{matchup.votes2} votes</div>
                            <div className="vote-bar">
                              <div
                                className="vote-fill"
                                style={{ width: `${getVotePercentage(matchup.votes2, totalVotes)}%` }}
                              />
                            </div>
                            <div className="vote-pct">
                              {getVotePercentage(matchup.votes2, totalVotes)}%
                            </div>
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="film-slot bye">BYE</div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      {/* Champion Banner - Shows when final round has a winner */}
      {tournamentHasChampion && champion && (
        <div className="champion-banner">
          <div className="champion-trophy">🏆</div>
          <div className="champion-details">
            <h2>Tournament Champion!</h2>
            <div className="champion-film">
              {champion.film.thumbnail && (
                <img
                  src={champion.film.thumbnail}
                  alt={champion.film.title}
                  className="champion-thumbnail"
                />
              )}
              <div className="champion-info">
                <div className="champion-seed">Seed #{champion.film.seed}</div>
                <h3 className="champion-title">{champion.film.title}</h3>
                {champion.film.creator && (
                  <p className="champion-creator">by {champion.film.creator}</p>
                )}
                <div className="champion-stats">
                  <span className="final-score">
                    Final Score: {champion.matchup.winner === champion.film.filmId
                      ? champion.matchup.votes1
                      : champion.matchup.votes2} votes
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default TournamentBracket;
