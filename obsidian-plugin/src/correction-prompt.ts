import { App, Modal, Notice } from "obsidian";

export function buildCorrectionPrompt(paths: string[]): string {
  const fileList = paths.map((path) => `- ${path}`).join("\n");

  return [
    "Correct the journal entries in the following files, fixing any obvious typos",
    "or incorrect proper nouns based on your memory and knowledge of my life.",
    "These are OCR transcriptions of handwriting, so errors are mostly misread",
    "letters and mangled names. Don't change the meaning, wording or voice — only",
    "fix transcription errors.",
    "",
    fileList,
  ].join("\n");
}

export class CorrectionPromptModal extends Modal {
  private prompt: string;
  private copyResetTimeout: number | null = null;

  constructor(app: App, paths: string[]) {
    super(app);
    this.prompt = buildCorrectionPrompt(paths);
  }

  onOpen(): void {
    const { contentEl } = this;
    contentEl.empty();

    contentEl.createEl("h2", { text: "Correct these entries with your agent" });
    contentEl.createEl("p", {
      text: "Paste this into your coding agent to clean up OCR mistakes.",
      cls: "setting-item-description",
    });

    const promptEl = contentEl.createEl("pre", { text: this.prompt });
    promptEl.style.whiteSpace = "pre-wrap";
    promptEl.style.userSelect = "text";
    promptEl.style.maxHeight = "40vh";
    promptEl.style.overflowY = "auto";

    const buttons = contentEl.createDiv({ cls: "modal-button-container" });

    const copyButton = buttons.createEl("button", { text: "Copy", cls: "mod-cta" });
    copyButton.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(this.prompt);
        copyButton.setText("Copied");
        if (this.copyResetTimeout !== null) {
          window.clearTimeout(this.copyResetTimeout);
        }
        this.copyResetTimeout = window.setTimeout(() => {
          this.copyResetTimeout = null;
          copyButton.setText("Copy");
        }, 1500);
      } catch (error) {
        console.error("Failed to copy correction prompt:", error);
        new Notice("Couldn't copy — select the text above and copy it manually.");
      }
    });

    buttons.createEl("button", { text: "Close" }).addEventListener("click", () => {
      this.close();
    });
  }

  onClose(): void {
    if (this.copyResetTimeout !== null) {
      window.clearTimeout(this.copyResetTimeout);
      this.copyResetTimeout = null;
    }
    this.contentEl.empty();
  }
}
