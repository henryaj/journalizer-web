# Journalizer Sync for Obsidian

Sync your handwritten journal entries from [Journalizer](https://journalizer.blmc.dev) to your Obsidian vault.

## Features

- **One-click sync**: Fetch new journal entries with a single click
- **Auto-sync**: Optionally sync entries automatically at regular intervals
- **Images included**: Journal page images are downloaded to your attachments folder
- **Markdown format**: Entries are saved as markdown with YAML frontmatter

## Installation

### From Community Plugins

1. Open Obsidian Settings
2. Go to Community Plugins and disable Safe Mode
3. Click Browse and search for "Journalizer Sync"
4. Install and enable the plugin

### Manual Installation

1. Download `main.js` and `manifest.json` from the [latest release](https://github.com/henryaj/journalizer-web/releases)
2. Create folder: `.obsidian/plugins/journalizer-sync/`
3. Copy the files into the folder
4. Reload Obsidian
5. Enable the plugin in Settings > Community Plugins

## Setup

1. Log in to [Journalizer](https://journalizer.blmc.dev)
2. Go to Dashboard > Manage Tokens
3. Create a new API token
4. Copy the token
5. In Obsidian, go to Settings > Journalizer Sync
6. Paste your API key
7. Click "Test" to verify the connection

## Usage

### Manual Sync

- Click the refresh icon in the left ribbon, or
- Use command palette: "Journalizer: Sync journal entries"

### Full Sync

To re-download all entries (not just new ones):
- Use command palette: "Journalizer: Full sync"

### Auto Sync

1. Go to Settings > Journalizer Sync
2. Enable "Auto Sync"
3. Set your preferred sync interval (5-120 minutes)

## Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| API Key | Your Journalizer API token | (required) |
| Server URL | Journalizer server address | `https://journalizer.blmc.dev` |
| Journal Folder | Where to save journal entries | `journal` |
| Attachments Folder | Where to save images | `attachments` |
| Auto Sync | Enable automatic syncing | Off |
| Sync Interval | Minutes between auto syncs | 30 |

## Entry Format

Synced entries are saved as markdown with this format:

```markdown
---
date: 2025-01-22
type: journal
source: handwritten-ocr
imported_at: 2025-01-22T10:30:00Z
---

# January 22, 2025

[Your transcribed journal text...]

---

*Transcribed with Journalizer on January 22, 2025*

![[journal-2025-01-22-000.jpg]]
```

## Support

- [Report issues](https://github.com/henryaj/journalizer-web/issues)
- [Journalizer website](https://journalizer.blmc.dev)

## License

MIT License - see [LICENSE](LICENSE) for details.
