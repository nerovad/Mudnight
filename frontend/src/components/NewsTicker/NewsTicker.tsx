import React, { useCallback, useEffect, useState } from "react";
import Marquee from "react-fast-marquee";
import { track } from "../../analytics/umami";
import "./NewsTicker.scss";
import "../../styles/_variables.scss";

type TickerSegment = {
  id: number;
  kind: "editorial" | "sponsor";
  body: string;
  sponsorName: string | null;
  linkUrl: string | null;
};

/** Shown if the API is unreachable, so a backend blip never leaves the strip
 *  blank. Deliberately evergreen — nothing dated, nothing that can go stale. */
const FALLBACK_SEGMENTS: TickerSegment[] = [
  { id: -1, kind: "editorial", body: "Welcome to CineZoo!", sponsorName: null, linkUrl: null },
  {
    id: -2,
    kind: "editorial",
    body: "Click anywhere on screen to navigate channels",
    sponsorName: null,
    linkUrl: null,
  },
];

/** A TV stays open for hours. Re-poll so copy edits reach viewers who are
 *  already watching, without anyone having to reload. */
const REFRESH_INTERVAL_MS = 5 * 60 * 1000;

const NewsTicker: React.FC = () => {
  const [isMinimized, setIsMinimized] = useState(false);
  const [segments, setSegments] = useState<TickerSegment[]>(FALLBACK_SEGMENTS);

  const toggleMinimize = () => {
    setIsMinimized(!isMinimized);
  };

  useEffect(() => {
    const isMobile = window.matchMedia("(max-width: 768px)").matches;
    document.documentElement.style.setProperty(
      "--ticker-height",
      isMinimized ? "0px" : isMobile ? "28px" : "50px"
    );
  }, [isMinimized]);

  useEffect(() => {
    let alive = true;

    const load = async () => {
      try {
        const res = await fetch("/api/ticker");
        if (!res.ok) return; // keep whatever is already on screen
        const data = await res.json();
        if (alive && Array.isArray(data.segments) && data.segments.length > 0) {
          setSegments(data.segments);
        }
      } catch {
        // Offline or backend down — the fallback copy stays up.
      }
    };

    load();
    const timer = window.setInterval(load, REFRESH_INTERVAL_MS);
    return () => {
      alive = false;
      window.clearInterval(timer);
    };
  }, []);

  const handleSponsorClick = useCallback((sponsorName: string | null) => {
    track("ticker-sponsor-click", { sponsor: sponsorName ?? "unknown" });
  }, []);

  const renderSegment = (segment: TickerSegment) => {
    if (segment.kind !== "sponsor") {
      return <span className="ticker-item">{segment.body}</span>;
    }

    const label = (
      <>
        <span className="ticker-item__sponsor-label">Sponsored by {segment.sponsorName}</span>
        {" — "}
        {segment.body}
      </>
    );

    if (!segment.linkUrl) {
      return <span className="ticker-item ticker-item--sponsor">{label}</span>;
    }

    return (
      <a
        className="ticker-item ticker-item--sponsor ticker-item--link"
        href={segment.linkUrl}
        target="_blank"
        rel="noopener noreferrer sponsored"
        // VideoPlayer listens on the document for click and contextmenu to
        // change channel. Without stopping propagation here, following a
        // sponsor link would also flip the channel out from under the viewer.
        onClick={(e) => {
          e.stopPropagation();
          handleSponsorClick(segment.sponsorName);
        }}
        onContextMenu={(e) => e.stopPropagation()}
      >
        {label}
      </a>
    );
  };

  return (
    <div className={`news-ticker ${isMinimized ? "minimized" : ""}`}>
      <button
        className="ticker-toggle"
        onClick={toggleMinimize}
        aria-label={isMinimized ? "Expand news ticker" : "Minimize news ticker"}
      >
        {isMinimized ? "▲" : "▼"}
      </button>
      {!isMinimized && (
        // pauseOnHover exists for the sponsor link: a click target sliding
        // past at 30px/s is not a click target. It also reads as a deliberate
        // tell that the strip is interactive.
        <Marquee speed={30} gradient={false} pauseOnHover className="ticker-wrapper">
          {segments.map((segment) => (
            <React.Fragment key={segment.id}>
              {renderSegment(segment)}
              <span className="ticker-separator" aria-hidden="true">
                |
              </span>
            </React.Fragment>
          ))}
        </Marquee>
      )}
    </div>
  );
};

export default NewsTicker;
