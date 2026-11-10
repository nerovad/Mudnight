import React, { useEffect, useRef, useState, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import Hls from "hls.js";
import "./VideoPlayer.scss";
import Chatbox from "../Chatbox/Chatbox";
import "../../styles/_variables.scss";
import { FaVolumeMute } from "react-icons/fa";
import intermissionDefault from "../../assets/intermission.mp4";
import { useChatStore } from "../../store/useChatStore";
import { useChannelDwell, useViewingHeartbeat } from "../../analytics/hooks";

interface VideoLink {
  src: string;
  channel: string;
  isLive?: boolean;
  channelNumber: number;
  displayName?: string;
  tags?: string[];
  intermissionUrl?: string | null;
}

interface VideoPlayerProps {
  isMenuOpen: boolean;
  isChatOpen: boolean;
  setVideoControls: (controls: {
    currentIndex: number;
    setCurrentIndex: React.Dispatch<React.SetStateAction<number>>;
    videoLinks: VideoLink[];
    videoRef: React.RefObject<HTMLVideoElement>;
    goToNextVideo: () => void;
    goToPreviousVideo: () => void;
    toggleMute: () => void;
    toggleFullscreen: () => void;
    loadVideo: (src: string) => void;
  }) => void;
  channelSlug?: string;
  isMobile?: boolean;
}

// Where the HLS tower lives. Defaults to production; override with
// VITE_HLS_BASE (e.g. http://localhost:8088) to point dev at a local tower.
const HLS_BASE = import.meta.env.VITE_HLS_BASE ?? "https://cinezoo.tv:8088";
const INTRO_VIDEO_SRC = "/videos/CinezooIntro.mp4";

const VideoPlayer: React.FC<VideoPlayerProps> = ({ isMenuOpen, isChatOpen, setVideoControls, isMobile = false }) => {
  const { channelSlug } = useParams<{ channelSlug: string }>();
  const navigate = useNavigate();

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const hlsRef = useRef<Hls | null>(null);
  const endedListenerRef = useRef<(() => void) | null>(null);
  const switchingRef = useRef(false);
  const retryRef = useRef(0);
  const initialLoadRef = useRef(false);
  // The user's mute preference, and the only thing that decides whether a
  // newly loaded video is muted. Starts muted (autoplay policy) and only
  // changes when the user hits a mute control.
  const mutedRef = useRef(true);
  const goToNextVideoRef = useRef<(() => void) | null>(null);
  // Manifest watch. A scheduled channel's engine only starts once we're counted
  // as a viewer, so its HLS manifest shows up seconds AFTER we tune in — the
  // first check always misses. These let the intermission be a waiting room
  // instead of a dead end. loadTokenRef invalidates a watch when the channel
  // changes underneath it.
  const manifestWatchRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const loadTokenRef = useRef(0);
  const loadVideoRef = useRef<((src: string) => void) | null>(null);
  const intermissionVideoRef = useRef<HTMLVideoElement | null>(null);
  const intermissionImgRef = useRef<HTMLImageElement | null>(null);
  const ambientCanvasRef = useRef<HTMLCanvasElement | null>(null);

  const { setChannelId } = useChatStore();

  // Watch time and channel stickiness. Mounted here because VideoPlayer only
  // renders on the channel route, so viewing stops being counted the moment a
  // viewer navigates away to /profile, /upload, etc.
  useViewingHeartbeat(channelSlug);
  useChannelDwell(channelSlug);

  const [currentIndex, setCurrentIndex] = useState(0);
  const [channelName, setChannelName] = useState("");
  const [isMuted, setIsMuted] = useState(true);
  const [showIntermission, setShowIntermission] = useState(false);
  const [isVideoReady, setIsVideoReady] = useState(false);
  // Aspect of whatever is on screen right now. Drives the size of .video-stage,
  // so the stage always matches the picture and nothing is ever cropped.
  const [mediaAspect, setMediaAspect] = useState(16 / 9);
  const [videoLinks, setVideoLinks] = useState<VideoLink[]>([
    { src: "/videos/Color_Bars_DB_Web.mp4", channel: "channel-0", channelNumber: 0, isLive: false },
    { src: INTRO_VIDEO_SRC, channel: "channel-1", channelNumber: 1, isLive: false },
  ]);

  const getClassNames = () => {
    // On mobile, don't add margin classes since sidebars overlay
    if (isMobile) return "mobile";

    let classNames = "";
    if (isMenuOpen) classNames += " expanded-left";
    if (isChatOpen) classNames += " expanded-right";
    if (isMenuOpen && isChatOpen) classNames = "expanded-both";
    return classNames.trim();
  };

  const cleanupHls = () => {
    const v = videoRef.current;
    if (v) {
      v.pause();
      if (endedListenerRef.current) {
        v.removeEventListener("ended", endedListenerRef.current as any);
        endedListenerRef.current = null;
      }
      v.removeAttribute("src");
      v.load();
    }
    if (hlsRef.current) {
      try { hlsRef.current.destroy(); } catch { }
      hlsRef.current = null;
    }
    retryRef.current = 0;
  };

  const stopManifestWatch = () => {
    if (manifestWatchRef.current) {
      clearTimeout(manifestWatchRef.current);
      manifestWatchRef.current = null;
    }
  };

  const manifestExists = async (src: string) => {
    try {
      const res = await fetch(src, { method: "HEAD", cache: "no-store" });
      return res.ok;
    } catch {
      return false;
    }
  };

  // Keep checking the manifest behind the intermission and cut to the stream the
  // moment it exists. Tight cadence while an on-demand engine is spinning up,
  // relaxed after that so a channel that's genuinely dark costs almost nothing.
  const watchForManifest = (src: string, token: number, attempt = 0) => {
    stopManifestWatch();
    const delay = attempt < 10 ? 2000 : 10000;
    manifestWatchRef.current = setTimeout(async () => {
      manifestWatchRef.current = null;
      if (token !== loadTokenRef.current) return;
      // A hidden tab isn't watching anything — skip the round trip, and don't
      // count it against the cadence so coming back still gets a fast pickup.
      if (document.hidden) {
        watchForManifest(src, token, attempt);
        return;
      }
      if (!(await manifestExists(src))) {
        if (token === loadTokenRef.current) watchForManifest(src, token, attempt + 1);
        return;
      }
      if (token !== loadTokenRef.current) return;
      console.log("[VideoPlayer] Manifest is up, leaving intermission:", src);
      loadVideoRef.current?.(src);
    }, delay);
  };

  const attachEndedForMp4 = () => {
    const v = videoRef.current;
    if (!v) return;
    const onEnded = () => {
      console.log("[attachEndedForMp4] Video ended, calling goToNextVideo");
      if (goToNextVideoRef.current) {
        goToNextVideoRef.current();
      } else {
        console.log("[attachEndedForMp4] goToNextVideoRef.current is null!");
      }
    };
    v.addEventListener("ended", onEnded);
    endedListenerRef.current = () => v.removeEventListener("ended", onEnded);
  };

  // Tell the backend a viewer landed here, so a scheduled channel's engine
  // starts on this HTTP call rather than waiting for the chat socket to finish
  // its handshake and join the room. Fire-and-forget: the manifest watch is
  // what actually picks the stream up, this only shortens the wait. Harmless
  // for channels that aren't scheduled — the supervisor ignores those.
  const tuneIn = useCallback((slug: string) => {
    if (!slug) return;
    fetch(`/api/channels/${encodeURIComponent(slug)}/playout/tune`, { method: "POST" })
      .catch(() => { });
  }, []);

  const loadVideo = useCallback(async (src: string) => {
    console.log("[loadVideo] Loading:", src);
    const v = videoRef.current;
    if (!v) {
      console.log("[loadVideo] No video element!");
      return;
    }

    // Any in-flight manifest watch belongs to the previous load — retire it.
    const token = ++loadTokenRef.current;
    stopManifestWatch();

    cleanupHls();
    setShowIntermission(false);

    // Every load honours the user's preference — nothing else flips it.
    const shouldMute = mutedRef.current;

    if (src.endsWith(".mp4")) {
      console.log("[loadVideo] Loading MP4, attaching ended listener");
      v.src = src;
      attachEndedForMp4();
      v.muted = shouldMute;
      v.play().catch(() => {
        // If play fails unmuted, mute and retry (browser policy)
        v.muted = true;
        v.play().catch(() => { });
      });
      return;
    }

    // Pre-check if the HLS manifest exists before creating an HLS instance
    if (src.includes(".m3u8")) {
      const up = await manifestExists(src);
      if (token !== loadTokenRef.current) return; // channel changed mid-check
      if (!up) {
        console.log("[loadVideo] Stream not up yet, showing intermission and watching:", src);
        setShowIntermission(true);
        watchForManifest(src, token);
        return;
      }
    }

    if (Hls.isSupported()) {
      // @ts-expect-error hls.js types don't match runtime API for config
      const hls = new Hls({
        liveBackBufferLength: 0,
        backBufferLength: 0,
        maxBufferLength: 10,
        maxBufferSize: 60 * 1000 * 1000,
        enableWorker: true,
        lowLatencyMode: false,
      });

      hlsRef.current = hls;
      hls.loadSource(src);
      hls.attachMedia(v);

      hls.on(Hls.Events.MANIFEST_PARSED, () => {
        v.muted = shouldMute;
        v.play().catch(() => {
          v.muted = true;
          v.play().catch(() => { });
        });
      });

      hls.on(Hls.Events.ERROR, (_evt: any, data: any) => {
        const fatal = !!data?.fatal;
        const type = data?.type as string | undefined;
        if (!fatal) return;

        if (type === "networkError") {
          if (retryRef.current < 3) {
            retryRef.current += 1;
            (hls as any).startLoad?.();
          } else {
            console.log("[VideoPlayer] Stream dropped after retries, showing intermission and watching");
            setShowIntermission(true);
            watchForManifest(src, token);
          }
        } else if (type === "mediaError") {
          try {
            (hls as any).recoverMediaError?.();
          } catch {
            setShowIntermission(true);
            watchForManifest(src, token);
          }
        } else {
          setShowIntermission(true);
          watchForManifest(src, token);
        }
      });

      return;
    }

    const vtag = videoRef.current;
    if (vtag?.canPlayType("application/vnd.apple.mpegurl")) {
      vtag.src = src;
      vtag.muted = shouldMute;
      vtag.play().catch(() => {
        vtag.muted = true;
        vtag.play().catch(() => { });
      });
      return;
    }

    console.error("This browser cannot play HLS.");
  }, []);

  // ✅ Navigate to new channel URL
  const switchToIndex = (idx: number) => {
    console.log("[switchToIndex] Called with idx:", idx, "videoLinks.length:", videoLinks.length);
    if (switchingRef.current) {
      console.log("[switchToIndex] Already switching, ignoring");
      return;
    }
    switchingRef.current = true;

    const safeIdx = ((idx % videoLinks.length) + videoLinks.length) % videoLinks.length;
    const dest = videoLinks[safeIdx];
    console.log("[switchToIndex] Navigating to:", dest.channel, "at index:", safeIdx);

    // ✅ Update URL instead of just state
    navigate(`/channel/${dest.channel}`, { replace: true });

    setTimeout(() => {
      switchingRef.current = false;
    }, 200);
  };

  const goToNextVideo = useCallback(() => switchToIndex(currentIndex + 1), [currentIndex, videoLinks.length]);
  const goToPreviousVideo = useCallback(() => switchToIndex(currentIndex - 1), [currentIndex, videoLinks.length]);

  // Keep ref updated so loadVideo can always call the latest version
  useEffect(() => {
    goToNextVideoRef.current = goToNextVideo;
  }, [goToNextVideo]);

  // Lets the manifest watch re-enter loadVideo without depending on it.
  useEffect(() => {
    loadVideoRef.current = loadVideo;
  }, [loadVideo]);

  const toggleMute = () => {
    const v = videoRef.current;
    if (!v) return;
    const muted = !v.muted;
    v.muted = muted;
    mutedRef.current = muted;
    setIsMuted(muted);
  };

  const toggleFullscreen = () => {
    const el = containerRef.current;
    if (!el) return;
    if (!document.fullscreenElement) el.requestFullscreen().catch(() => { });
    else document.exitFullscreen().catch(() => { });
  };

  // Whichever element is actually painting right now. Both the aspect lock and
  // the ambient backdrop read from it, so they never disagree about what's on
  // screen during an intermission.
  const getActiveMedia = useCallback((): HTMLVideoElement | HTMLImageElement | null => {
    if (showIntermission) return intermissionVideoRef.current ?? intermissionImgRef.current;
    return videoRef.current;
  }, [showIntermission]);

  const measureAspect = useCallback(() => {
    const el = getActiveMedia();
    if (!el) return;
    const w = el instanceof HTMLVideoElement ? el.videoWidth : el.naturalWidth;
    const h = el instanceof HTMLVideoElement ? el.videoHeight : el.naturalHeight;
    if (w > 0 && h > 0) setMediaAspect(w / h);
  }, [getActiveMedia]);

  // The main element's dimensions arrive at loadedmetadata and can change again
  // mid-stream ("resize") when HLS switches rendition.
  useEffect(() => {
    if (!isVideoReady) return;
    const v = videoRef.current;
    if (!v) return;
    v.addEventListener("loadedmetadata", measureAspect);
    v.addEventListener("resize", measureAspect);
    measureAspect();
    return () => {
      v.removeEventListener("loadedmetadata", measureAspect);
      v.removeEventListener("resize", measureAspect);
    };
  }, [isVideoReady, measureAspect]);

  // Re-measure when the intermission comes or goes — the active element
  // changes without either media element firing an event.
  useEffect(() => { measureAspect(); }, [showIntermission, measureAspect]);

  // Ambient backdrop: the letterbox area is filled with a heavily blurred copy
  // of the picture instead of flat black. Drawn into a 32x18 canvas at ~5fps
  // and blown up by CSS — the source is already destroyed by the blur, so a
  // thumbnail costs nothing and there is no second decode of the stream.
  useEffect(() => {
    const canvas = ambientCanvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;

    const FRAME_MS = 1000 / 5;
    let raf = 0;
    let last = 0;

    const tick = (t: number) => {
      raf = requestAnimationFrame(tick);
      if (t - last < FRAME_MS || document.hidden) return;
      last = t;
      const el = getActiveMedia();
      if (!el) return;
      if (el instanceof HTMLVideoElement && (el.readyState < 2 || el.videoWidth === 0)) return;
      // Cross-origin frames taint the canvas but still draw; we never read back.
      try { ctx.drawImage(el, 0, 0, canvas.width, canvas.height); } catch { }
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [getActiveMedia]);

  // Set video ready state when component mounts
  useEffect(() => {
    const checkVideo = () => {
      if (videoRef.current && !isVideoReady) {
        console.log("[VideoPlayer] Video element is ready");
        setIsVideoReady(true);
      } else if (!videoRef.current) {
        // Retry on next frame if not ready yet
        requestAnimationFrame(checkVideo);
      }
    };
    checkVideo();
  }, []);

  // Mirror the video element's muted state into the overlay icon, so any
  // path that flips muted (slider, M key, remote, programmatic) stays in sync.
  useEffect(() => {
    if (!isVideoReady) return;
    const v = videoRef.current;
    if (!v) return;
    const sync = () => setIsMuted(v.muted);
    v.addEventListener("volumechange", sync);
    return () => v.removeEventListener("volumechange", sync);
  }, [isVideoReady]);

  // The looping intermission clip is a SEPARATE <video> element that the
  // navbar mute button, volume slider, and overlay icon never touch — they
  // all target the main (hidden, src-less) videoRef during an intermission.
  // Mirror the main element's muted/volume onto it so those controls actually
  // affect the audio the user hears on intermission channels (e.g. ch 6, 99).
  useEffect(() => {
    if (!showIntermission) return;
    const main = videoRef.current;
    if (!main) return;
    const sync = () => {
      const iv = intermissionVideoRef.current;
      if (!iv) return;
      iv.muted = main.muted;
      iv.volume = main.volume;
    };
    sync();
    main.addEventListener("volumechange", sync);
    return () => main.removeEventListener("volumechange", sync);
  }, [showIntermission]);

  // Set the intermission clip's initial muted/volume the instant it mounts,
  // from the main video's current state. Runs during commit (before the
  // browser evaluates autoplay), so a muted main video keeps the clip muted
  // and a user who already unmuted hears it right away. The effect above
  // handles every change after mount.
  const attachIntermissionVideo = useCallback((el: HTMLVideoElement | null) => {
    intermissionVideoRef.current = el;
    if (!el) return;
    const main = videoRef.current;
    el.muted = main ? main.muted : mutedRef.current;
    if (main) el.volume = main.volume;
    el.addEventListener("loadedmetadata", measureAspect);
    measureAspect();
  }, [measureAspect]);

  const attachIntermissionImg = useCallback((el: HTMLImageElement | null) => {
    intermissionImgRef.current = el;
    if (!el) return;
    el.addEventListener("load", measureAspect);
    measureAspect();
  }, [measureAspect]);


  // ✅ Fetch channels
  // ✅ Fetch channels
  useEffect(() => {
    let alive = true;

    (async () => {
      try {
        const res = await fetch("/api/channels");
        const channels = await res.json();

        console.log("Raw API response:", channels); // ⬅️ ADD THIS

        const dynamic: VideoLink[] = channels
          .map((ch: any) => {
            const key = ch.stream_key ?? ch.slug ?? ch.key;
            if (!key) return null;
            const src = `${HLS_BASE}/hls/${key}/index.m3u8`;
            return {
              src,
              channel: ch.slug ?? key,
              channelNumber: ch.channel_number ?? 0,
              displayName: ch.display_name ?? null,
              tags: ch.tags ?? [],
              intermissionUrl: ch.intermission_url ?? null,
              isLive: true
            };
          })
          .filter(Boolean) as VideoLink[];

        // Sort AFTER the filter and cast
        dynamic.sort((a: VideoLink, b: VideoLink) => a.channelNumber - b.channelNumber);

        console.log("Dynamic videoLinks after sorting:", dynamic); // ⬅️ ADD THIS

        if (alive) {
          setVideoLinks(prev => {
            const updated = [prev[0], prev[1], ...dynamic];
            console.log("Final videoLinks array:", updated); // ⬅️ ADD THIS
            return updated;
          });
        }
      } catch (e) {
        console.error("Failed to fetch channels", e);
      }
    })();

    return () => { alive = false; };
  }, []);
  // ✅ Sync URL parameter to video player state
  useEffect(() => {
    console.log("[VideoPlayer] Sync effect running:", {
      channelSlug,
      videoLinksLength: videoLinks.length,
      currentIndex,
      initialLoad: initialLoadRef.current,
      isVideoReady
    });

    if (!channelSlug || videoLinks.length === 0) {
      console.log("[VideoPlayer] Exiting early - no channelSlug or videoLinks");
      return;
    }

    if (!isVideoReady) {
      console.log("[VideoPlayer] Exiting early - video element not ready yet");
      return;
    }

    const idx = videoLinks.findIndex(link => link.channel === channelSlug);
    console.log("[VideoPlayer] Found index for", channelSlug, ":", idx);

    // Load video if: 1) switching to a different channel, OR 2) initial load
    if (idx !== -1 && (idx !== currentIndex || !initialLoadRef.current)) {
      console.log("[VideoPlayer] Loading video:", videoLinks[idx]);
      setCurrentIndex(idx);
      const link = videoLinks[idx];

      // Only tower channels have an engine behind them; the colour bars and the
      // intro are local files.
      if (link.src.includes(".m3u8")) tuneIn(link.channel);
      loadVideo(link.src);
      setChannelId(link.channel);
      // The intro slot is meant to feel like part of the boot sequence,
      // not a real channel — keep its slug out of the overlay.
      const overlayName = link.channel === "channel-1" ? "" : link.channel;
      setChannelName(overlayName);
      initialLoadRef.current = true;

      const hide = setTimeout(() => setChannelName(""), 7000);
      return () => clearTimeout(hide);
    } else {
      console.log("[VideoPlayer] Skipping load:", { idx, currentIndex, initialLoad: initialLoadRef.current });
    }
  }, [channelSlug, videoLinks, isVideoReady, loadVideo, tuneIn, setChannelId]);

  // ✅ Provide controls to NavBar
  useEffect(() => {
    setVideoControls({
      currentIndex,
      setCurrentIndex,
      videoLinks,
      videoRef,
      goToNextVideo,
      goToPreviousVideo,
      toggleMute,
      toggleFullscreen,
      loadVideo,
    });
  }, [currentIndex, videoLinks]);

  // ✅ Keyboard shortcuts
  useEffect(() => {
    const handleKey = (event: KeyboardEvent) => {
      const el = document.activeElement as HTMLElement | null;
      if (el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.getAttribute("contenteditable") === "true")) return;
      switch (event.key.toLowerCase()) {
        case "m": toggleMute(); break;
        case "f": toggleFullscreen(); break;
        case "arrowdown": goToPreviousVideo(); break;
        case "arrowup": goToNextVideo(); break;
      }
    };
    const handleRightClick = (e: MouseEvent) => { e.preventDefault(); goToPreviousVideo(); };

    document.addEventListener("keydown", handleKey);
    document.addEventListener("contextmenu", handleRightClick);
    return () => {
      document.removeEventListener("keydown", handleKey);
      document.removeEventListener("contextmenu", handleRightClick);
    };
  }, [goToNextVideo, goToPreviousVideo]);

  useEffect(() => () => { stopManifestWatch(); cleanupHls(); }, []);

  // Resolve the intermission source: custom per-channel or system default
  const currentLink = videoLinks[currentIndex];
  const intermissionSrc = currentLink?.intermissionUrl || intermissionDefault;
  const isIntermissionVideo = !intermissionSrc || /\.(mp4|webm|ogg|mov)(\?|$)/i.test(intermissionSrc) || intermissionSrc === intermissionDefault;

  return (
    <div className={`video-container-dboriginals ${getClassNames()}`}>
      <div className="tv-container" ref={containerRef}>
        <canvas className="video-ambient" ref={ambientCanvasRef} width={32} height={18} aria-hidden="true" />

        <div className="db-originals-next-button" onClick={goToNextVideo} />

        {/* Locked to the picture's own aspect, so the video is never cropped and
            the overlays below stay pinned to the image rather than to the box. */}
        <div
          className="video-stage"
          style={{ "--media-aspect": mediaAspect } as React.CSSProperties}
        >
          <video
            className="myvideo"
            ref={videoRef}
            muted
            autoPlay
            preload="metadata"
            playsInline
            controls={false}
            style={showIntermission ? { display: "none" } : undefined}
          />
          {showIntermission && (
            <div className="intermission-screen">
              {isIntermissionVideo ? (
                <video
                  ref={attachIntermissionVideo}
                  src={intermissionSrc}
                  className="intermission-video"
                  autoPlay
                  loop
                  playsInline
                />
              ) : (
                <img
                  ref={attachIntermissionImg}
                  src={intermissionSrc}
                  className="intermission-video"
                  alt="Intermission"
                />
              )}
            </div>
          )}
          <div className="channelnumber">{channelName}</div>
          {isMuted && (
            <button
              className="mute-icon-overlay"
              aria-label="Unmute"
              onClick={(e) => { e.stopPropagation(); toggleMute(); }}
            >
              <FaVolumeMute />
            </button>
          )}
        </div>
      </div>

      <Chatbox isOpen={isChatOpen} setIsOpen={() => { }} />
    </div>
  );
};

export default VideoPlayer;
