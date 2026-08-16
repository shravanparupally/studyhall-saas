import { logger as functionsLogger } from 'firebase-functions/v2';

/**
 * Structured logging shape mandated by docs/15_Technical_Architecture.md
 * §15.18: every log entry carries `organizationId`/`branchId`/`actorId`/
 * `action` (and `latencyMs` where timed). Never log PII — no phone numbers,
 * names, or ID document references, on either side of the stack.
 */
export interface LogContext {
  organizationId?: string;
  branchId?: string;
  actorId?: string;
  latencyMs?: number;
}

function log(
  level: 'debug' | 'info' | 'warn' | 'error',
  action: string,
  context: LogContext = {},
  error?: unknown,
): void {
  const entry = { action, ...context };
  switch (level) {
    case 'debug':
      functionsLogger.debug(entry);
      break;
    case 'info':
      functionsLogger.info(entry);
      break;
    case 'warn':
      functionsLogger.warn(entry);
      break;
    case 'error':
      functionsLogger.error({
        ...entry,
        error: error instanceof Error ? error.message : error,
      });
      break;
  }
}

export const appLogger = {
  debug: (action: string, context?: LogContext) => log('debug', action, context),
  info: (action: string, context?: LogContext) => log('info', action, context),
  warn: (action: string, context?: LogContext) => log('warn', action, context),
  error: (action: string, context?: LogContext, error?: unknown) => log('error', action, context, error),
};
