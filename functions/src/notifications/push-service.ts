import * as admin from 'firebase-admin';

export interface TopicMessenger {
  send(message: any): Promise<string>;
}

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string | null;
}

export const BREAKING_TOPIC = 'breaking';
export const DAILY_BRIEF_TOPIC = 'daily-brief';

/**
 * Thin, never-throwing wrapper around firebase-admin Cloud Messaging topic sends.
 */
export class PushService {
  constructor(private messenger?: TopicMessenger) {}

  private getMessenger(): TopicMessenger | undefined {
    if (this.messenger) return this.messenger;
    try {
      if (!admin.apps.length) return undefined;
      return admin.messaging();
    } catch {
      return undefined;
    }
  }

  /** Sends to an FCM topic. Returns the message id, or null on any failure (logged, never thrown). */
  async sendToTopic(topic: string, payload: PushPayload): Promise<string | null> {
    try {
      const messenger = this.getMessenger();
      if (!messenger) {
        console.warn(`[PushService] Messaging unavailable; skipped push to topic "${topic}"`);
        return null;
      }
      const title = payload.title.slice(0, 120);
      const body = payload.body.slice(0, 240);
      const image = payload.imageUrl && payload.imageUrl.startsWith('https://') ? payload.imageUrl : undefined;
      const data: Record<string, string> = {};
      for (const [k, v] of Object.entries(payload.data ?? {})) {
        if (v != null) data[k] = String(v);
      }
      const message: any = {
        topic,
        notification: image ? { title, body, imageUrl: image } : { title, body },
        data,
        android: { priority: 'high', notification: { channelId: topic } },
        apns: { payload: { aps: { sound: 'default' } } },
        webpush: data.url && data.url.startsWith('https://') ? { fcmOptions: { link: data.url } } : undefined,
      };
      if (!message.webpush) delete message.webpush;
      const id = await messenger.send(message);
      console.log(`[PushService] Sent push to topic "${topic}": ${id}`);
      return id;
    } catch (err: any) {
      console.warn(`[PushService] Push to topic "${topic}" failed: ${err?.message || err}`);
      return null;
    }
  }
}
