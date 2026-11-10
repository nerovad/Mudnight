declare module 'hls.js' {
  export default class Hls {
    static isSupported(): boolean;
    loadSource(source: string): void;
    attachMedia(media: HTMLMediaElement): void;
    on(event: string, callback: (...args: any[]) => void): void;
    destroy(): void;
    static Events: {
      MANIFEST_PARSED: string;
      ERROR: string;
    };
    static ErrorTypes: {
      NETWORK_ERROR: string;
      MEDIA_ERROR: string;
    };
  }
}
