import React, { useState, useEffect } from "react";
import "./TournamentSeeding.scss";

interface Film {
  id: string;
  title: string;
  creator?: string;
  thumbnail?: string;
}

interface TournamentSeedingProps {
  films: Film[];
  onSeedingComplete: (bracket: TournamentBracket) => void;
}

export interface TournamentBracket {
  rounds: Round[];
  filmSeeds: FilmSeed[];
}

export interface Round {
  roundNumber: number;
  matchups: Matchup[];
}

export interface Matchup {
  id: string;
  position: number;
  film1: FilmSeed | null;
  film2: FilmSeed | null;
  winner?: string; // film id
}

export interface FilmSeed {
  filmId: string;
  seed: number;
  title: string;
  creator?: string;
  thumbnail?: string;
}

const TournamentSeeding: React.FC<TournamentSeedingProps> = ({ films, onSeedingComplete }) => {
  const [seedingMode, setSeedingMode] = useState<"auto" | "manual">("auto");
  const [seeds, setSeeds] = useState<FilmSeed[]>([]);
  const [previewBracket, setPreviewBracket] = useState<TournamentBracket | null>(null);

  // Initialize seeds when films change
  useEffect(() => {
    if (films.length >= 4) {
      const initialSeeds = films.map((film, index) => ({
        filmId: film.id,
        seed: index + 1,
        title: film.title,
        creator: film.creator,
        thumbnail: film.thumbnail,
      }));
      setSeeds(initialSeeds);
      generateBracket(initialSeeds);
    }
  }, [films]);

  // Generate bracket structure based on seeds
  const generateBracket = (currentSeeds: FilmSeed[]) => {
    const numFilms = currentSeeds.length;

    // Find next power of 2
    const bracketSize = Math.pow(2, Math.ceil(Math.log2(numFilms)));
    const firstRoundMatchups = bracketSize / 2;

    // Create first round matchups using standard tournament seeding
    // (1 vs 16, 8 vs 9, 5 vs 12, etc.)
    const rounds: Round[] = [];
    const firstRoundMatches: Matchup[] = [];

    for (let i = 0; i < firstRoundMatchups; i++) {
      const seed1 = i + 1;
      const seed2 = bracketSize - i;

      const film1 = currentSeeds.find(s => s.seed === seed1) || null;
      const film2 = currentSeeds.find(s => s.seed === seed2) || null;

      firstRoundMatches.push({
        id: `r1-m${i + 1}`,
        position: i,
        film1,
        film2,
      });
    }

    rounds.push({
      roundNumber: 1,
      matchups: firstRoundMatches,
    });

    // Generate subsequent rounds (empty matchups)
    const numRounds = Math.log2(bracketSize);
    for (let r = 2; r <= numRounds; r++) {
      const numMatchups = Math.pow(2, numRounds - r);
      const roundMatchups: Matchup[] = [];

      for (let m = 0; m < numMatchups; m++) {
        roundMatchups.push({
          id: `r${r}-m${m + 1}`,
          position: m,
          film1: null,
          film2: null,
        });
      }

      rounds.push({
        roundNumber: r,
        matchups: roundMatchups,
      });
    }

    const bracket: TournamentBracket = {
      rounds,
      filmSeeds: currentSeeds,
    };

    setPreviewBracket(bracket);
  };

  // Handle manual reordering of seeds
  const moveSeed = (fromIndex: number, toIndex: number) => {
    const newSeeds = [...seeds];
    const [movedItem] = newSeeds.splice(fromIndex, 1);
    newSeeds.splice(toIndex, 0, movedItem);

    // Update seed numbers
    const updatedSeeds = newSeeds.map((seed, index) => ({
      ...seed,
      seed: index + 1,
    }));

    setSeeds(updatedSeeds);
    generateBracket(updatedSeeds);
  };

  const handleAutoSeed = () => {
    // Could implement various auto-seeding strategies here
    // For now, just use the order films were added
    const autoSeeds = films.map((film, index) => ({
      filmId: film.id,
      seed: index + 1,
      title: film.title,
      creator: film.creator,
      thumbnail: film.thumbnail,
    }));
    setSeeds(autoSeeds);
    generateBracket(autoSeeds);
  };

  const handleConfirm = () => {
    if (previewBracket) {
      onSeedingComplete(previewBracket);
    }
  };

  if (films.length < 4) {
    return (
      <div className="tournament-seeding">
        <div className="warning">
          <p>⚠️ Tournaments require at least 4 films.</p>
          <p>You currently have {films.length} film{films.length === 1 ? '' : 's'}.</p>
        </div>
      </div>
    );
  }

  if (films.length > 32) {
    return (
      <div className="tournament-seeding">
        <div className="warning">
          <p>⚠️ Maximum 32 films for tournaments.</p>
          <p>You currently have {films.length} films. Please remove some.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="tournament-seeding">
      <div className="seeding-header">
        <h3>🏆 Tournament Bracket Seeding</h3>
        <div className="seeding-mode-toggle">
          <button
            className={seedingMode === "auto" ? "active" : ""}
            onClick={() => setSeedingMode("auto")}
          >
            Auto Seed
          </button>
          <button
            className={seedingMode === "manual" ? "active" : ""}
            onClick={() => setSeedingMode("manual")}
          >
            Manual Order
          </button>
        </div>
      </div>

      {seedingMode === "auto" && (
        <div className="auto-seed-section">
          <p>Films will be automatically seeded in the order you added them.</p>
          <button className="btn-secondary" onClick={handleAutoSeed}>
            Re-seed in Current Order
          </button>
        </div>
      )}

      {seedingMode === "manual" && (
        <div className="manual-seed-section">
          <p>Drag to reorder seeds (Seed 1 is strongest):</p>
          <div className="seed-list">
            {seeds.map((seed, index) => (
              <div
                key={seed.filmId}
                className="seed-item"
                draggable
                onDragStart={(e) => {
                  e.dataTransfer.effectAllowed = "move";
                  e.dataTransfer.setData("text/plain", index.toString());
                }}
                onDragOver={(e) => e.preventDefault()}
                onDrop={(e) => {
                  e.preventDefault();
                  const fromIndex = parseInt(e.dataTransfer.getData("text/plain"));
                  moveSeed(fromIndex, index);
                }}
              >
                <div className="seed-number">#{seed.seed}</div>
                <div className="seed-info">
                  <div className="seed-title">{seed.title}</div>
                  {seed.creator && <div className="seed-creator">{seed.creator}</div>}
                </div>
                <div className="drag-handle">⋮⋮</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {previewBracket && (
        <div className="bracket-preview">
          <h4>Bracket Preview</h4>
          <div className="preview-info">
            <span>{seeds.length} Films</span>
            <span>•</span>
            <span>{previewBracket.rounds.length} Rounds</span>
            <span>•</span>
            <span>{previewBracket.rounds[0].matchups.length} First Round Matchups</span>
          </div>

          <div className="first-round-matchups">
            <h5>Round 1 Matchups:</h5>
            {previewBracket.rounds[0].matchups.map((matchup, idx) => (
              <div key={matchup.id} className="matchup-preview">
                <div className="matchup-number">Match {idx + 1}</div>
                <div className="matchup-films">
                  <div className="film">
                    {matchup.film1 ? (
                      <>
                        <span className="seed-badge">#{matchup.film1.seed}</span>
                        <span>{matchup.film1.title}</span>
                      </>
                    ) : (
                      <span className="bye">BYE</span>
                    )}
                  </div>
                  <div className="vs">vs</div>
                  <div className="film">
                    {matchup.film2 ? (
                      <>
                        <span className="seed-badge">#{matchup.film2.seed}</span>
                        <span>{matchup.film2.title}</span>
                      </>
                    ) : (
                      <span className="bye">BYE</span>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="seeding-actions">
        <button className="btn-primary" onClick={handleConfirm}>
          Confirm Bracket Setup
        </button>
      </div>
    </div>
  );
};

export default TournamentSeeding;
