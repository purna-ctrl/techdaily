export type LogLevel = 'info' | 'warn' | 'error';

export interface StructuredLogEvent {
  timestamp: string;
  level: LogLevel;
  event: string;
  message: string;
  sourceId?: string;
  articleId?: string;
  durationMs?: number;
  metadata?: Record<string, any>;
  error?: string;
}

export class StructuredLogger {
  private static sanitize(obj: any): any {
    if (obj == null) return obj;
    if (typeof obj === 'string') {
      // Mask API keys, tokens, and authorization headers
      return obj
        .replace(/AIza[0-9A-Za-z-_]{20,50}/g, '[MASKED_API_KEY]')
        .replace(/Bearer\s+[A-Za-z0-9-_.]+/gi, 'Bearer [MASKED_TOKEN]')
        .replace(/(password|secret|token|apikey)\s*[:=]\s*[^\s,]+/gi, '$1=[MASKED]');
    }
    if (Array.isArray(obj)) {
      return obj.map(StructuredLogger.sanitize);
    }
    if (typeof obj === 'object') {
      const sanitized: Record<string, any> = {};
      for (const [key, val] of Object.entries(obj)) {
        if (/password|secret|key|token|auth/i.test(key)) {
          sanitized[key] = '[REDACTED]';
        } else {
          sanitized[key] = StructuredLogger.sanitize(val);
        }
      }
      return sanitized;
    }
    return obj;
  }

  static log(
    level: LogLevel,
    event: string,
    message: string,
    details: {
      sourceId?: string;
      articleId?: string;
      durationMs?: number;
      metadata?: Record<string, any>;
      error?: any;
    } = {}
  ): StructuredLogEvent {
    const errorString = details.error
      ? (details.error.message || String(details.error))
      : undefined;

    const payload: StructuredLogEvent = {
      timestamp: new Date().toISOString(),
      level,
      event,
      message: StructuredLogger.sanitize(message),
      sourceId: details.sourceId,
      articleId: details.articleId,
      durationMs: details.durationMs,
      metadata: details.metadata ? StructuredLogger.sanitize(details.metadata) : undefined,
      error: errorString ? StructuredLogger.sanitize(errorString) : undefined,
    };

    const serialized = JSON.stringify(payload);
    if (level === 'error') {
      console.error(serialized);
    } else if (level === 'warn') {
      console.warn(serialized);
    } else {
      console.log(serialized);
    }

    return payload;
  }

  static info(event: string, message: string, details?: Parameters<typeof StructuredLogger.log>[3]) {
    return this.log('info', event, message, details);
  }

  static warn(event: string, message: string, details?: Parameters<typeof StructuredLogger.log>[3]) {
    return this.log('warn', event, message, details);
  }

  static error(event: string, message: string, details?: Parameters<typeof StructuredLogger.log>[3]) {
    return this.log('error', event, message, details);
  }
}
