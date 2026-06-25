import type { SaveData } from '../state/GameState';
import { sanitize } from './migrations';
import { SAVE_KEY } from '../config';

const DB_NAME = 'eventhorizon';
const STORE = 'saves';
const PRIMARY_KEY = 'current';

/**
 * Persistence with redundancy. Primary store is IndexedDB; every write is also
 * mirrored to localStorage. Loads try IndexedDB first, then the mirror, then a
 * fresh save — so progress survives a corrupt store, a cleared DB, or private
 * mode where IndexedDB may be unavailable. All writes are versioned & sanitized.
 */
export class SaveManager {
  private db: IDBDatabase | null = null;
  private dbReady: Promise<void>;
  private idbOk = true;

  constructor() {
    this.dbReady = this.openDb();
  }

  private openDb(): Promise<void> {
    return new Promise((resolve) => {
      try {
        if (typeof indexedDB === 'undefined') {
          this.idbOk = false;
          resolve();
          return;
        }
        const req = indexedDB.open(DB_NAME, 1);
        req.onupgradeneeded = () => {
          const db = req.result;
          if (!db.objectStoreNames.contains(STORE)) db.createObjectStore(STORE);
        };
        req.onsuccess = () => {
          this.db = req.result;
          resolve();
        };
        req.onerror = () => {
          this.idbOk = false;
          resolve();
        };
      } catch {
        this.idbOk = false;
        resolve();
      }
    });
  }

  async save(data: SaveData): Promise<void> {
    data.lastSaved = Date.now();
    const json = JSON.stringify(data);
    // Mirror to localStorage synchronously (cheap, reliable fallback).
    try {
      localStorage.setItem(SAVE_KEY, json);
    } catch {
      /* storage may be full / unavailable; IDB still tries below */
    }
    await this.dbReady;
    if (!this.idbOk || !this.db) return;
    await new Promise<void>((resolve) => {
      try {
        const tx = this.db!.transaction(STORE, 'readwrite');
        tx.objectStore(STORE).put(json, PRIMARY_KEY);
        tx.oncomplete = () => resolve();
        tx.onerror = () => resolve();
        tx.onabort = () => resolve();
      } catch {
        resolve();
      }
    });
  }

  async load(): Promise<SaveData | null> {
    await this.dbReady;
    // 1) Try IndexedDB.
    if (this.idbOk && this.db) {
      const raw = await new Promise<string | null>((resolve) => {
        try {
          const tx = this.db!.transaction(STORE, 'readonly');
          const req = tx.objectStore(STORE).get(PRIMARY_KEY);
          req.onsuccess = () => resolve((req.result as string) ?? null);
          req.onerror = () => resolve(null);
        } catch {
          resolve(null);
        }
      });
      const parsed = this.tryParse(raw);
      if (parsed) return parsed;
    }
    // 2) Fall back to the localStorage mirror.
    try {
      const ls = localStorage.getItem(SAVE_KEY);
      const parsed = this.tryParse(ls);
      if (parsed) return parsed;
    } catch {
      /* ignore */
    }
    return null;
  }

  private tryParse(raw: string | null): SaveData | null {
    if (!raw) return null;
    try {
      return sanitize(JSON.parse(raw));
    } catch {
      return null;
    }
  }

  /** Export the current save as a portable base64 string. */
  exportString(data: SaveData): string {
    const json = JSON.stringify(data);
    return btoa(unescape(encodeURIComponent(json)));
  }

  /** Parse an imported base64 string into validated save data, or null. */
  importString(text: string): SaveData | null {
    try {
      const json = decodeURIComponent(escape(atob(text.trim())));
      return sanitize(JSON.parse(json));
    } catch {
      return null;
    }
  }

  async wipe(): Promise<void> {
    try {
      localStorage.removeItem(SAVE_KEY);
    } catch {
      /* ignore */
    }
    await this.dbReady;
    if (!this.idbOk || !this.db) return;
    await new Promise<void>((resolve) => {
      try {
        const tx = this.db!.transaction(STORE, 'readwrite');
        tx.objectStore(STORE).delete(PRIMARY_KEY);
        tx.oncomplete = () => resolve();
        tx.onerror = () => resolve();
      } catch {
        resolve();
      }
    });
  }
}
