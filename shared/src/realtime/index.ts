/**
 * A socket.io-shaped client for the Rails ActionCable ChatChannel.
 *
 * The backend moved from Socket.io to ActionCable, but the web and mobile
 * components were written against socket.io-client. This keeps their call
 * sites unchanged — `io(url, opts)`, `on` / `off` / `emit`, `connected`,
 * `disconnect()`, and the "connect" / "disconnect" events — by speaking the
 * ActionCable wire protocol directly over a plain WebSocket. It has no
 * dependencies and needs no DOM, so it runs in React Native as well as the
 * browser (@rails/actioncable reaches for `document`).
 *
 * Emitted event names map to channel actions in snake_case:
 *   emit("joinRoom", data)    -> ChatChannel#join_room
 *   emit("sendMessage", data) -> ChatChannel#send_message
 * The server pushes `{ event, data }`, dispatched to `on(event)` handlers.
 */

type Handler = (...args: any[]) => void;

export interface CableSocketOptions {
  /** Accepted for socket.io-client compatibility; ignored. */
  withCredentials?: boolean;
  /** Accepted for socket.io-client compatibility; ignored. */
  transports?: string[];
  /** Path ActionCable is mounted at (default "/cable"). */
  path?: string;
}

const CHANNEL_IDENTIFIER = JSON.stringify({ channel: "ChatChannel" });
const PROTOCOLS = ["actioncable-v1-json", "actioncable-unsupported"];
// Rails pings every 3s; treat the connection as dead after this much silence.
const STALE_AFTER_MS = 10_000;
const MAX_BACKOFF_MS = 10_000;

const snakeCase = (s: string) => s.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);

function cableUrl(baseUrl: string, path: string): string {
  if (!baseUrl) {
    if (typeof location === "undefined") throw new Error("io(): a base URL is required outside the browser");
    const proto = location.protocol === "https:" ? "wss:" : "ws:";
    return `${proto}//${location.host}${path}`;
  }
  const url = baseUrl.replace(/^http/i, "ws").replace(/\/+$/, "");
  return /\/cable$/.test(url) ? url : `${url}${path}`;
}

export class CableSocket {
  connected = false;

  private readonly url: string;
  private ws: WebSocket | null = null;
  private handlers = new Map<string, Set<Handler>>();
  private queue: { action: string; data: any }[] = [];
  private lastJoin: any = null;
  private closedByUser = false;
  private attempts = 0;
  private lastSeen = 0;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private staleTimer: ReturnType<typeof setInterval> | null = null;

  constructor(baseUrl = "", opts: CableSocketOptions = {}) {
    this.url = cableUrl(baseUrl, opts.path ?? "/cable");
    this.open();
  }

  on(event: string, handler: Handler): this {
    if (!this.handlers.has(event)) this.handlers.set(event, new Set());
    this.handlers.get(event)!.add(handler);
    return this;
  }

  /** off(event) removes every handler for it; off(event, fn) removes one. */
  off(event: string, handler?: Handler): this {
    if (handler) this.handlers.get(event)?.delete(handler);
    else this.handlers.delete(event);
    return this;
  }

  emit(event: string, data?: any): this {
    if (event === "joinRoom") this.lastJoin = data;
    const msg = { action: snakeCase(event), data: data ?? {} };
    // Like socket.io, buffer until the subscription is confirmed.
    if (this.connected) this.perform(msg);
    else this.queue.push(msg);
    return this;
  }

  disconnect(): this {
    this.closedByUser = true;
    this.clearTimers();
    this.ws?.close();
    this.ws = null;
    this.setConnected(false);
    return this;
  }

  close(): this {
    return this.disconnect();
  }

  // --- internals ---

  private open() {
    this.closedByUser = false;
    const ws = new WebSocket(this.url, PROTOCOLS);
    this.ws = ws;

    ws.onmessage = (ev) => this.receive(ev.data);
    ws.onclose = () => {
      if (this.ws !== ws) return;
      this.ws = null;
      this.setConnected(false);
      this.scheduleReconnect();
    };
    ws.onerror = () => ws.close();
  }

  private receive(raw: any) {
    this.lastSeen = Date.now();
    let msg: any;
    try {
      msg = JSON.parse(typeof raw === "string" ? raw : String(raw));
    } catch {
      return;
    }

    switch (msg.type) {
      case "welcome":
        this.send({ command: "subscribe", identifier: CHANNEL_IDENTIFIER });
        this.startStaleCheck();
        return;
      case "ping":
        return;
      case "confirm_subscription":
        this.attempts = 0;
        this.setConnected(true);
        // A fresh subscription has no room: rejoin the last one, then flush.
        if (this.lastJoin && !this.queue.some((m) => m.action === "join_room")) {
          this.perform({ action: "join_room", data: this.lastJoin });
        }
        this.queue.splice(0).forEach((m) => this.perform(m));
        return;
      case "reject_subscription":
      case "disconnect":
        this.ws?.close();
        return;
    }

    if (msg.identifier === CHANNEL_IDENTIFIER && msg.message?.event) {
      this.dispatch(msg.message.event, msg.message.data);
    }
  }

  private perform({ action, data }: { action: string; data: any }) {
    this.send({
      command: "message",
      identifier: CHANNEL_IDENTIFIER,
      data: JSON.stringify({ ...data, action }),
    });
  }

  private send(payload: object) {
    if (this.ws && this.ws.readyState === 1) this.ws.send(JSON.stringify(payload));
  }

  private dispatch(event: string, ...args: any[]) {
    this.handlers.get(event)?.forEach((h) => h(...args));
  }

  private setConnected(value: boolean) {
    if (this.connected === value) return;
    this.connected = value;
    this.dispatch(value ? "connect" : "disconnect");
  }

  private scheduleReconnect() {
    this.clearTimers();
    if (this.closedByUser) return;
    const delay = Math.min(MAX_BACKOFF_MS, 500 * 2 ** this.attempts++);
    this.reconnectTimer = setTimeout(() => this.open(), delay);
  }

  private startStaleCheck() {
    if (this.staleTimer) clearInterval(this.staleTimer);
    this.staleTimer = setInterval(() => {
      if (Date.now() - this.lastSeen > STALE_AFTER_MS) this.ws?.close();
    }, STALE_AFTER_MS / 2);
  }

  private clearTimers() {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    if (this.staleTimer) clearInterval(this.staleTimer);
    this.reconnectTimer = this.staleTimer = null;
  }
}

/** Drop-in for socket.io-client's default export. */
export default function io(url = "", opts: CableSocketOptions = {}): CableSocket {
  return new CableSocket(url, opts);
}

export { io };
export type Socket = CableSocket;
