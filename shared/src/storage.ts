export interface StorageAdapter {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
}

const WebStorageAdapter: StorageAdapter = {
  async getItem(key: string) {
    return localStorage.getItem(key);
  },
  async setItem(key: string, value: string) {
    localStorage.setItem(key, value);
  },
  async removeItem(key: string) {
    localStorage.removeItem(key);
  },
};

let currentAdapter: StorageAdapter = WebStorageAdapter;

export function setStorageAdapter(adapter: StorageAdapter) {
  currentAdapter = adapter;
}

export function getStorage(): StorageAdapter {
  return currentAdapter;
}
