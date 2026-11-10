/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL?: string;
  readonly VITE_SOCKET_URL?: string;
  /** HLS tower base URL; override to point dev at a local tower, e.g. http://localhost:8088 */
  readonly VITE_HLS_BASE?: string;
  /** Full URL of the self-hosted Umami tracker script, e.g. https://stats.cinezoo.tv/script.js */
  readonly VITE_UMAMI_SCRIPT_URL?: string;
  /** Website UUID that Umami issues when you add cinezoo.tv in its dashboard */
  readonly VITE_UMAMI_WEBSITE_ID?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
