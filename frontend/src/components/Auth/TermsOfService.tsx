import React from "react";
import "./TermsOfService.scss";

interface TermsOfServiceProps {
  onAccept: () => void;
  onDecline: () => void;
}

const TermsOfService: React.FC<TermsOfServiceProps> = ({ onAccept, onDecline }) => {
  return (
    <div className="tos-overlay">
      <div className="tos-card">
        <h2>Terms of Service</h2>
        <div className="tos-content">
          <p><strong>Last updated: {new Date().toLocaleDateString()}</strong></p>

          <h3>The Honest Version</h3>

          <p><strong>1. You must be 13 or older</strong><br />
            If you're under 13, you can't use this. It's the law (COPPA).</p>

          <p><strong>2. Don't be a jerk</strong><br />
            No harassment, hate speech, spam, or illegal stuff. Be cool to each other.</p>

          <p><strong>3. Your account is your responsibility</strong><br />
            Pick a good password. If you lose it, we can't help you recover it (we don't collect emails).</p>

          <p><strong>4. We can remove content or accounts</strong><br />
            If you break these rules or do something sketchy, we can delete your stuff or ban you.</p>

          <p><strong>5. No guarantees</strong><br />
            This service is provided "as is." We'll try our best, but we can't promise 100% uptime or that nothing will ever go wrong.</p>

          <p><strong>6. Your content is yours</strong><br />
            We don't claim ownership of what you post, but you give us permission to display it on the platform.</p>

          <p><strong>7. We might change these terms</strong><br />
            If we do, we'll update the date above. Continuing to use the service means you accept the new terms.</p>

          <p><strong>8. Privacy matters</strong><br />
            We only collect your username and password. We don't sell your data because we barely have any data to sell.</p>

          <p className="bottom-line">
            <strong>Bottom line:</strong> Be respectful, follow the law, and remember this is just a website. If you can't agree to these basic rules, this isn't the place for you.
          </p>
        </div>

        <div className="tos-buttons">
          <button className="decline-btn" onClick={onDecline}>
            Decline
          </button>
          <button className="accept-btn" onClick={onAccept}>
            I Accept
          </button>
        </div>
      </div>
    </div>
  );
};

export default TermsOfService;
