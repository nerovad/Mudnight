import React, { useState, useEffect } from "react";
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider } from "./store/AuthContext";
import { useUIStore } from "./store/useUIStore";
import { useIsMobile, useIsPortrait } from "./hooks/useIsMobile";
import NavBar from "./components/Navigation/Navigation.tsx";
import NewsTicker from "./components/NewsTicker/NewsTicker.tsx";
import TvGuide from "./components/TvGuide/TvGuide.tsx";
import VideoPlayer from "./components/VideoPlayer/VideoPlayer.tsx";
import Channels from "./components/Menu/Menu.tsx";
import Chatbox from "./components/Chatbox/Chatbox.tsx";
import Auth from "./components/Auth/Auth.tsx";
import Settings from "./components/Settings/Settings.tsx";
import Upload from "./components/Upload/Upload.tsx";
import Profile from "./components/Profile/Profile.tsx";
import UserProfile from "./components/Profile/UserProfile.tsx";
import AdminFestivals from "./components/Pages/AdminFestivals.tsx";
import Admin from "./components/Pages/Admin.tsx";
import { usePageviews } from "./analytics/hooks";
import "./App.scss";

// Pageviews are sent by hand rather than by Umami's auto-tracker; this has to
// live inside the Router to read the current location.
const RouteTracker: React.FC = () => {
  usePageviews();
  return null;
};

const MainLayout: React.FC<{
  isMenuOpen: boolean;
  isChatOpen: boolean;
  setIsMenuOpen: React.Dispatch<React.SetStateAction<boolean>>;
  setIsChatOpen: React.Dispatch<React.SetStateAction<boolean>>;
  isGuideOpen: boolean;
  setIsGuideOpen: React.Dispatch<React.SetStateAction<boolean>>;
  videoControls: any;
  setIsAuthOpen: React.Dispatch<React.SetStateAction<boolean>>;
  setAuthMode: React.Dispatch<React.SetStateAction<"login" | "register">>;
  channelSlug?: string;
  isMobile: boolean;
  isMobilePortrait: boolean;
  mobilePanel: 'chat' | 'pit';
  setMobilePanel: React.Dispatch<React.SetStateAction<'chat' | 'pit'>>;
}> = ({
  isMenuOpen,
  isChatOpen,
  setIsMenuOpen,
  setIsChatOpen,
  isGuideOpen,
  setIsGuideOpen,
  videoControls,
  setIsAuthOpen,
  setAuthMode,
  channelSlug,
  isMobile,
  isMobilePortrait,
  mobilePanel,
  setMobilePanel,
}) => (
    <>
      <NavBar
        setIsGuideOpen={setIsGuideOpen}
        setIsAuthOpen={setIsAuthOpen}
        setAuthMode={setAuthMode}
        isMobile={isMobile}
        isMenuOpen={isMenuOpen}
        setIsMenuOpen={setIsMenuOpen}
        isMobilePortrait={isMobilePortrait}
        mobilePanel={mobilePanel}
        setMobilePanel={setMobilePanel}
        {...videoControls}
      />
      <div className={`main-content ${isMobile ? 'mobile' : ''} ${isMobilePortrait ? 'mobile-portrait' : ''}`}>
        {/* Desktop / mobile landscape: Menu sidebar on left */}
        {!isMobilePortrait && (
          <Channels isOpen={isMenuOpen} setIsOpen={setIsMenuOpen} isMobile={isMobile} />
        )}

        <VideoPlayer
          isMenuOpen={isMobilePortrait ? false : isMenuOpen}
          isChatOpen={isMobilePortrait ? false : isChatOpen}
          setVideoControls={videoControls.setVideoControls}
          channelSlug={channelSlug}
          isMobile={isMobile}
        />

        {/* Desktop / mobile landscape: Chat sidebar on right */}
        {!isMobilePortrait && (
          <Chatbox isOpen={isChatOpen} setIsOpen={setIsChatOpen} />
        )}

        {/* Mobile portrait: panel below video */}
        {isMobilePortrait && (
          <div className="mobile-panel-container">
            {mobilePanel === 'chat' ? (
              <Chatbox isOpen={true} setIsOpen={setIsChatOpen} mobileInline={true} />
            ) : (
              <Channels isOpen={true} setIsOpen={() => setMobilePanel('chat')} isMobile={true} mobileInline={true} />
            )}
          </div>
        )}
      </div>
      <NewsTicker />

      {/* Mobile menu backdrop (landscape only) */}
      {isMobile && !isMobilePortrait && isMenuOpen && (
        <div className="menu-backdrop" onClick={() => setIsMenuOpen(false)} />
      )}

      {isGuideOpen && <TvGuide isOpen={isGuideOpen} closeGuide={() => setIsGuideOpen(false)} />}
    </>
  );

const App: React.FC = () => {
  const isMobile = useIsMobile();
  const isPortrait = useIsPortrait();
  const isMobilePortrait = isMobile && isPortrait;
  const { setIsMobile } = useUIStore();

  // Sync mobile state to store
  useEffect(() => {
    setIsMobile(isMobile);
  }, [isMobile, setIsMobile]);

  // Start with sidebars closed on mobile, open on desktop
  const [isMenuOpen, setIsMenuOpen] = useState(!isMobile);
  const [isChatOpen, setIsChatOpen] = useState(!isMobile);

  // Mobile portrait: which panel is shown below the video
  const [mobilePanel, setMobilePanel] = useState<'chat' | 'pit'>('chat');
  const [isGuideOpen, setIsGuideOpen] = useState(false);

  // Auto-close sidebars when switching to mobile
  useEffect(() => {
    if (isMobile) {
      setIsMenuOpen(false);
      setIsChatOpen(false);
    }
  }, [isMobile]);

  // Auto-fullscreen on mobile landscape, exit on portrait
  useEffect(() => {
    if (!isMobile) return;

    if (!isPortrait) {
      // Mobile landscape → enter fullscreen
      const el = document.querySelector('.tv-container') as HTMLElement;
      if (el && !document.fullscreenElement) {
        el.requestFullscreen().catch(() => { });
      }
    } else {
      // Mobile portrait → exit fullscreen
      if (document.fullscreenElement) {
        document.exitFullscreen().catch(() => { });
      }
    }
  }, [isMobile, isPortrait]);

  const [isAuthOpen, setIsAuthOpen] = useState(false);
  const [authMode, setAuthMode] = useState<"login" | "register">("login");

  const [videoControls, setVideoControls] = useState<any>({
    currentIndex: 0,
    setCurrentIndex: () => { },
    videoLinks: [],
    videoRef: null,
    goToNextVideo: () => { },
    goToPreviousVideo: () => { },
    toggleMute: () => { },
    toggleFullscreen: () => { },
    loadVideo: () => { },
    setVideoControls: (controls: any) => setVideoControls((prev: any) => ({ ...prev, ...controls })),
  });

  return (
    <AuthProvider>
      <Router>
        <RouteTracker />
        <Routes>
          {/* Redirect root to default channel */}
          <Route path="/" element={<Navigate to="/channel/channel-0" replace />} />

          {/* Channel-specific route */}
          <Route
            path="/channel/:channelSlug"
            element={
              <MainLayout
                isMenuOpen={isMenuOpen}
                isChatOpen={isChatOpen}
                setIsMenuOpen={setIsMenuOpen}
                setIsChatOpen={setIsChatOpen}
                isGuideOpen={isGuideOpen}
                setIsGuideOpen={setIsGuideOpen}
                setIsAuthOpen={setIsAuthOpen}
                setAuthMode={setAuthMode}
                videoControls={videoControls}
                channelSlug={undefined}
                isMobile={isMobile}
                isMobilePortrait={isMobilePortrait}
                mobilePanel={mobilePanel}
                setMobilePanel={setMobilePanel}
              />
            }
          />

          {/* Other routes */}
          <Route path="/upload" element={<Upload />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="/profile/:handle" element={<UserProfile />} />
          <Route path="/admin" element={<Admin />} />
          <Route path="/admin/festivals" element={<AdminFestivals />} />

          {/* Catch-all redirect */}
          <Route path="*" element={<Navigate to="/channel/channel-0" replace />} />
        </Routes>

        {isAuthOpen && (
          <Auth
            setIsAuthOpen={setIsAuthOpen}
            authMode={authMode}
            setAuthMode={setAuthMode}
          />
        )}
      </Router>
    </AuthProvider>
  );
};

export default App;
