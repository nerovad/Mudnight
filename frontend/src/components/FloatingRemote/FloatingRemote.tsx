import React from "react";
import Draggable from "react-draggable";
import "./FloatingRemote.scss";

interface FloatingRemoteProps {
  isRemoteOpen: boolean;
  setIsRemoteOpen: React.Dispatch<React.SetStateAction<boolean>>;
  goToNextVideo: () => void;
  goToPreviousVideo: () => void;
  toggleMute: () => void;
  toggleFullscreen: () => void;
}

const FloatingRemote: React.FC<FloatingRemoteProps> = ({
  isRemoteOpen,
  setIsRemoteOpen,
  goToNextVideo,
  goToPreviousVideo,
  toggleMute,
  toggleFullscreen,
}) => {
  if (!isRemoteOpen) return null; // ✅ Hide remote when it's closed

  return (
    <Draggable>
      <div className="floating-remote">
        <button className="close-btn-remote" onClick={() => {
          console.log("Closing Remote");
          setIsRemoteOpen(false);
        }}>X</button>

        <button className="channel-up" onClick={(event: React.MouseEvent<HTMLButtonElement>) => {
          console.log("Button clicked:", event.target);
          console.log("goToNextVideo() called");
          goToNextVideo();
        }}>Ch+</button>


        <button className="channel-down" onClick={() => {
          console.log("goToPreviousVideo() called");
          goToPreviousVideo();
        }}>Ch-</button>

        <button className="mute-btn" onClick={() => {
          console.log("toggleMute() called");
          toggleMute();
        }}>Mute</button>

        <button className="fullscreen-btn" onClick={() => {
          console.log("toggleFullscreen() called");
          toggleFullscreen();
        }}>Full</button>

      </div>
    </Draggable>
  );
};

export default FloatingRemote;
