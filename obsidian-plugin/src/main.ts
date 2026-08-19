import { Plugin, Notice } from "obsidian";
import { JournalizerSettings, DEFAULT_SETTINGS, JournalizerSettingTab } from "./settings";
import { SyncEngine } from "./sync";
import { CorrectionPromptModal } from "./correction-prompt";

export default class JournalizerPlugin extends Plugin {
  settings: JournalizerSettings;
  private syncInterval: number | null = null;
  private statusBarItem: HTMLElement | null = null;

  async onload() {
    await this.loadSettings();

    // Add ribbon icon
    this.addRibbonIcon("refresh-cw", "Sync Journalizer entries", async () => {
      await this.runSync(false);
    });

    // Add commands
    this.addCommand({
      id: "sync-entries",
      name: "Sync journal entries",
      callback: async () => {
        await this.runSync(false);
      },
    });

    this.addCommand({
      id: "show-correction-prompt",
      name: "Show correction prompt for last sync",
      callback: () => {
        const paths = this.settings.lastSyncedPaths;
        if (paths.length === 0) {
          new Notice("No entries have been synced yet");
          return;
        }
        new CorrectionPromptModal(this.app, paths).open();
      },
    });

    this.addCommand({
      id: "full-sync",
      name: "Full sync (re-download all entries)",
      callback: async () => {
        await this.runSync(true);
      },
    });

    // Add settings tab
    this.addSettingTab(new JournalizerSettingTab(this.app, this));

    // Add status bar item
    this.statusBarItem = this.addStatusBarItem();
    this.updateStatusBar();

    // Setup auto sync
    this.setupAutoSync();
  }

  onunload() {
    if (this.syncInterval) {
      window.clearInterval(this.syncInterval);
    }
  }

  async loadSettings() {
    this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
  }

  async saveSettings() {
    await this.saveData(this.settings);
  }

  setupAutoSync() {
    // Clear existing interval
    if (this.syncInterval) {
      window.clearInterval(this.syncInterval);
      this.syncInterval = null;
    }

    // Setup new interval if enabled
    if (this.settings.autoSync && this.settings.apiKey) {
      const intervalMs = this.settings.syncIntervalMinutes * 60 * 1000;
      this.syncInterval = window.setInterval(async () => {
        await this.runSync(false, true);
      }, intervalMs);
    }
  }

  private async runSync(fullSync: boolean, silent: boolean = false) {
    if (!this.settings.apiKey) {
      new Notice("Please configure your Journalizer API key in settings");
      return;
    }

    if (!silent) {
      new Notice("Syncing journal entries...");
    }

    try {
      const syncEngine = new SyncEngine(this.app, this.settings);
      const { count, paths } = await syncEngine.sync(fullSync);

      this.settings.lastSyncTime = new Date().toISOString();
      // A full sync re-downloads the whole archive, so its paths aren't a useful
      // "here's what just came in" list - only track incremental syncs.
      if (!fullSync && paths.length > 0) {
        this.settings.lastSyncedPaths = paths;
      }
      await this.saveSettings();
      this.updateStatusBar();

      if (count > 0) {
        new Notice(`Synced ${count} journal ${count === 1 ? "entry" : "entries"}`);
        if (!silent && !fullSync) {
          new CorrectionPromptModal(this.app, paths).open();
        }
      } else if (!silent) {
        new Notice("No new entries to sync");
      }
    } catch (error) {
      console.error("Sync failed:", error);
      new Notice(`Sync failed: ${error.message}`);
    }
  }

  private updateStatusBar() {
    if (!this.statusBarItem) return;

    if (this.settings.lastSyncTime) {
      const lastSync = new Date(this.settings.lastSyncTime);
      const diff = Date.now() - lastSync.getTime();
      const minutes = Math.floor(diff / 60000);

      if (minutes < 1) {
        this.statusBarItem.setText("Journalizer: just now");
      } else if (minutes < 60) {
        this.statusBarItem.setText(`Journalizer: ${minutes}m ago`);
      } else {
        const hours = Math.floor(minutes / 60);
        this.statusBarItem.setText(`Journalizer: ${hours}h ago`);
      }
    } else {
      this.statusBarItem.setText("Journalizer: never synced");
    }
  }
}
