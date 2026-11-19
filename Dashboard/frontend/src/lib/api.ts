import type {
  AlertsConfigUpdatePayload,
  AlertsPurgeResult,
  AlertsStatus,
  AlertTestResult,
  TunnelRestartResult,
} from '../types/dashboard';
import { isRecord } from '../types/ws';

export type LoginResult =
  | { ok: true; token: string }
  | { ok: false; status: number; error: string; retryAfterSeconds?: number };

export interface ApiResponse<T> {
  ok: boolean;
  status: number;
  data?: T;
  error?: string;
}

async function apiFetch<T>(
  path: string,
  init: RequestInit = {},
  token = ''
): Promise<ApiResponse<T>> {
  const headers = new Headers(init.headers);
  if (!headers.has('Content-Type') && init.body !== undefined) {
    headers.set('Content-Type', 'application/json');
  }
  if (token) {
    headers.set('X-Auth-Token', token);
  }

  try {
    const res = await fetch(path, { ...init, headers });
    const raw: unknown = await res.json().catch(() => null);
    if (!res.ok) {
      const errorMsg =
        isRecord(raw) && typeof raw.error === 'string'
          ? raw.error
          : `Request failed (HTTP ${res.status})`;
      return {
        ok: false,
        status: res.status,
        data: isRecord(raw) ? (raw as T) : undefined,
        error: errorMsg,
      };
    }
    return { ok: true, status: res.status, data: raw as T };
  } catch (err) {
    return {
      ok: false,
      status: 0,
      error: err instanceof Error ? err.message : 'Network request failed',
    };
  }
}

export async function loginWithPin(pin: string): Promise<LoginResult> {
  try {
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ pin }),
    });
    const raw: unknown = await res.json().catch(() => null);
    if (res.ok && isRecord(raw) && typeof raw.token === 'string') {
      return { ok: true, token: raw.token };
    }
    const errMsg =
      isRecord(raw) && typeof raw.error === 'string'
        ? raw.error
        : 'Invalid PIN code. Please try again.';
    const retryAfter =
      isRecord(raw) && typeof raw.retry_after_seconds === 'number'
        ? raw.retry_after_seconds
        : undefined;
    return {
      ok: false,
      status: res.status,
      error: errMsg,
      retryAfterSeconds: retryAfter,
    };
  } catch {
    return {
      ok: false,
      status: 0,
      error: 'Connection error. Could not verify PIN.',
    };
  }
}

export async function putAlertsConfig(
  payload: AlertsConfigUpdatePayload,
  token: string
): Promise<ApiResponse<{ ok: boolean; alerts: AlertsStatus }>> {
  return apiFetch<{ ok: boolean; alerts: AlertsStatus }>(
    '/api/alerts/config',
    { method: 'PUT', body: JSON.stringify(payload) },
    token
  );
}

export async function postTestAlert(token: string): Promise<ApiResponse<AlertTestResult>> {
  return apiFetch<AlertTestResult>(
    '/api/alerts/test',
    { method: 'POST', body: JSON.stringify({}) },
    token
  );
}

export async function postPurgeDiscordAlerts(
  payload: { limit?: number; bot_only?: boolean },
  token: string
): Promise<ApiResponse<AlertsPurgeResult>> {
  return apiFetch<AlertsPurgeResult>(
    '/api/alerts/purge',
    { method: 'POST', body: JSON.stringify(payload) },
    token
  );
}

export async function postRestartTunnel(
  token: string
): Promise<ApiResponse<TunnelRestartResult>> {
  return apiFetch<TunnelRestartResult>(
    '/api/tunnel/restart',
    { method: 'POST', body: JSON.stringify({}) },
    token
  );
}

export async function postRestartServer(
  token: string
): Promise<ApiResponse<{ success: boolean; message: string }>> {
  return apiFetch<{ success: boolean; message: string }>(
    '/api/system/restart',
    { method: 'POST', body: JSON.stringify({}) },
    token
  );
}
