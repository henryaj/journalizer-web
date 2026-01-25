import { App, TFolder, Notice } from "obsidian";
import { JournalizerAPI, JournalEntry } from "./api";
import { JournalizerSettings } from "./settings";

export class SyncEngine {
  private app: App;
  private api: JournalizerAPI;
  private settings: JournalizerSettings;

  constructor(app: App, settings: JournalizerSettings) {
    this.app = app;
    this.settings = settings;
    this.api = new JournalizerAPI(settings.serverUrl, settings.apiKey);
  }

  async sync(fullSync: boolean = false): Promise<number> {
    const since = fullSync ? undefined : this.settings.lastSyncTime || undefined;

    const { entries } = await this.api.getEntries({
      since,
      unsyncedOnly: !fullSync,
    });

    if (entries.length === 0) {
      return 0;
    }

    // Ensure folders exist
    await this.ensureFolder(this.settings.journalFolder);
    await this.ensureFolder(this.settings.attachmentsFolder);

    let syncedCount = 0;

    for (const entry of entries) {
      try {
        await this.syncEntry(entry);
        syncedCount++;
      } catch (error) {
        console.error(`Failed to sync entry ${entry.id}:`, error);
        new Notice(`Failed to sync entry: ${entry.title || entry.id}`);
      }
    }

    return syncedCount;
  }

  private async syncEntry(entry: JournalEntry): Promise<void> {
    // Download and save images first
    for (let i = 0; i < entry.image_count; i++) {
      try {
        const imageData = await this.api.getImage(entry.id, i);
        const datePrefix = entry.entry_date || new Date(entry.created_at).toISOString().split("T")[0];
        const imageName = `journal-${datePrefix}-${String(i).padStart(3, "0")}.jpg`;
        const imagePath = `${this.settings.attachmentsFolder}/${imageName}`;

        await this.saveFile(imagePath, imageData);
      } catch (error) {
        console.error(`Failed to download image ${i} for entry ${entry.id}:`, error);
      }
    }

    // Get and save markdown
    const markdown = await this.api.getMarkdown(entry.id);
    const filename = this.getFilename(entry);
    const filePath = `${this.settings.journalFolder}/${filename}`;

    await this.saveFile(filePath, markdown);

    // Mark as synced on server
    await this.api.markSynced(entry.id);
  }

  private getFilename(entry: JournalEntry): string {
    if (entry.entry_date) {
      return `${entry.entry_date}.md`;
    }
    return `${entry.id}.md`;
  }

  private async ensureFolder(path: string): Promise<void> {
    const folder = this.app.vault.getAbstractFileByPath(path);
    if (!folder) {
      await this.app.vault.createFolder(path);
    }
  }

  private async saveFile(path: string, content: string | ArrayBuffer): Promise<void> {
    const existing = this.app.vault.getAbstractFileByPath(path);

    if (typeof content === "string") {
      if (existing) {
        await this.app.vault.modify(existing as any, content);
      } else {
        await this.app.vault.create(path, content);
      }
    } else {
      // Binary content (images)
      if (existing) {
        await this.app.vault.modifyBinary(existing as any, content);
      } else {
        await this.app.vault.createBinary(path, content);
      }
    }
  }
}
