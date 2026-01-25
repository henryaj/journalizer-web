import { App, PluginSettingTab, Setting, Notice } from "obsidian";
import JournalizerPlugin from "./main";
import { JournalizerAPI } from "./api";

export interface JournalizerSettings {
  apiKey: string;
  serverUrl: string;
  journalFolder: string;
  attachmentsFolder: string;
  autoSync: boolean;
  syncIntervalMinutes: number;
  lastSyncTime: string | null;
}

export const DEFAULT_SETTINGS: JournalizerSettings = {
  apiKey: "",
  serverUrl: "https://journalizer.blmc.dev",
  journalFolder: "journal",
  attachmentsFolder: "attachments",
  autoSync: false,
  syncIntervalMinutes: 30,
  lastSyncTime: null,
};

export class JournalizerSettingTab extends PluginSettingTab {
  plugin: JournalizerPlugin;

  constructor(app: App, plugin: JournalizerPlugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display(): void {
    const { containerEl } = this;
    containerEl.empty();

    containerEl.createEl("h2", { text: "Journalizer Sync Settings" });

    new Setting(containerEl)
      .setName("API Key")
      .setDesc("Your Journalizer API key (get it from your dashboard)")
      .addText((text) =>
        text
          .setPlaceholder("Enter your API key")
          .setValue(this.plugin.settings.apiKey)
          .onChange(async (value) => {
            this.plugin.settings.apiKey = value;
            await this.plugin.saveSettings();
          })
      );

    new Setting(containerEl)
      .setName("Server URL")
      .setDesc("Journalizer server URL")
      .addText((text) =>
        text
          .setPlaceholder("https://journalizer.blmc.dev")
          .setValue(this.plugin.settings.serverUrl)
          .onChange(async (value) => {
            this.plugin.settings.serverUrl = value;
            await this.plugin.saveSettings();
          })
      );

    new Setting(containerEl)
      .setName("Test Connection")
      .setDesc("Verify your API key and server connection")
      .addButton((button) =>
        button.setButtonText("Test").onClick(async () => {
          const api = new JournalizerAPI(
            this.plugin.settings.serverUrl,
            this.plugin.settings.apiKey
          );
          const success = await api.testConnection();
          if (success) {
            new Notice("Connection successful!");
          } else {
            new Notice("Connection failed. Check your API key and server URL.");
          }
        })
      );

    containerEl.createEl("h3", { text: "Folders" });

    new Setting(containerEl)
      .setName("Journal Folder")
      .setDesc("Folder where journal entries will be saved")
      .addText((text) =>
        text
          .setPlaceholder("journal")
          .setValue(this.plugin.settings.journalFolder)
          .onChange(async (value) => {
            this.plugin.settings.journalFolder = value;
            await this.plugin.saveSettings();
          })
      );

    new Setting(containerEl)
      .setName("Attachments Folder")
      .setDesc("Folder where images will be saved")
      .addText((text) =>
        text
          .setPlaceholder("attachments")
          .setValue(this.plugin.settings.attachmentsFolder)
          .onChange(async (value) => {
            this.plugin.settings.attachmentsFolder = value;
            await this.plugin.saveSettings();
          })
      );

    containerEl.createEl("h3", { text: "Auto Sync" });

    new Setting(containerEl)
      .setName("Enable Auto Sync")
      .setDesc("Automatically sync entries at regular intervals")
      .addToggle((toggle) =>
        toggle
          .setValue(this.plugin.settings.autoSync)
          .onChange(async (value) => {
            this.plugin.settings.autoSync = value;
            await this.plugin.saveSettings();
            this.plugin.setupAutoSync();
          })
      );

    new Setting(containerEl)
      .setName("Sync Interval")
      .setDesc("How often to sync (in minutes)")
      .addSlider((slider) =>
        slider
          .setLimits(5, 120, 5)
          .setValue(this.plugin.settings.syncIntervalMinutes)
          .setDynamicTooltip()
          .onChange(async (value) => {
            this.plugin.settings.syncIntervalMinutes = value;
            await this.plugin.saveSettings();
            this.plugin.setupAutoSync();
          })
      );

    if (this.plugin.settings.lastSyncTime) {
      containerEl.createEl("p", {
        text: `Last sync: ${new Date(this.plugin.settings.lastSyncTime).toLocaleString()}`,
        cls: "setting-item-description",
      });
    }
  }
}
