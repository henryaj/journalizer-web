export interface JournalEntry {
  id: number;
  entry_date: string | null;
  title: string;
  content: string;
  source: string;
  synced: boolean;
  image_count: number;
  created_at: string;
  expires_at: string;
}

export interface EntriesResponse {
  entries: JournalEntry[];
  total: number;
}

export class JournalizerAPI {
  private baseUrl: string;
  private apiKey: string;

  constructor(baseUrl: string, apiKey: string) {
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.apiKey = apiKey;
  }

  private async request<T>(path: string, options: RequestInit = {}): Promise<T> {
    const url = `${this.baseUrl}/api/v1${path}`;
    const response = await fetch(url, {
      ...options,
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
        ...options.headers,
      },
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status} ${response.statusText}`);
    }

    return response.json();
  }

  async getEntries(options: {
    since?: string;
    unsyncedOnly?: boolean;
    limit?: number;
  } = {}): Promise<EntriesResponse> {
    const params = new URLSearchParams();
    if (options.since) params.set("since", options.since);
    if (options.unsyncedOnly) params.set("unsynced_only", "true");
    if (options.limit) params.set("limit", options.limit.toString());

    const query = params.toString();
    return this.request<EntriesResponse>(`/entries${query ? `?${query}` : ""}`);
  }

  async getMarkdown(entryId: number): Promise<string> {
    const url = `${this.baseUrl}/api/v1/entries/${entryId}/markdown`;
    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
      },
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status} ${response.statusText}`);
    }

    return response.text();
  }

  async getImage(entryId: number, index: number): Promise<ArrayBuffer> {
    const url = `${this.baseUrl}/api/v1/entries/${entryId}/images/${index}`;
    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
      },
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status} ${response.statusText}`);
    }

    return response.arrayBuffer();
  }

  async markSynced(entryId: number): Promise<void> {
    await this.request(`/entries/${entryId}/mark_synced`, {
      method: "POST",
    });
  }

  async testConnection(): Promise<boolean> {
    try {
      const url = `${this.baseUrl}/api/v1/me`;
      const response = await fetch(url, {
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
        },
      });
      return response.ok;
    } catch {
      return false;
    }
  }
}
