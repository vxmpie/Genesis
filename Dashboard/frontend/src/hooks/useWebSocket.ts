import { useCallback, useEffect, useRef } from 'react';
import { useDashboardStore } from '../store/useDashboard';
import {
  parseWsServerMessage,
  type WsCommandMap,
  type WsCommandName,
  type WsServerMessage,
} from '../types/ws';

// --- Singleton Socket State ---
interface QueuedCommand {
  command: string;
  payload: Record<string, unknown>;
}

let globalWs: WebSocket | null = null;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let pendingCommands: QueuedCommand[] = [];
let backoffMs = 1500;

function buildWebSocketUrl(token: string): string {
  const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
  const host = window.location.host;
  const tokenQuery = token ? `?token=${encodeURIComponent(token)}` : '';
  return host.includes('5173')
    ? `ws://127.0.0.1:7700/ws${tokenQuery}`
    : `${proto}://${host}/ws${tokenQuery}`;
}

export function authenticateSocket(token: string): void {
  if (globalWs && globalWs.readyState === WebSocket.OPEN && token) {
    globalWs.send(JSON.stringify({ command: 'auth', token }));
  }
}

export function disconnectAndReconnect(): void {
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  backoffMs = 1500;
  if (globalWs) {
    globalWs.close();
  }
}

// --- WebSocket Hook ---
export function useWebSocket() {
  const connectRef = useRef<() => void>(() => {});

  const handleIncomingMessage = useCallback((msg: WsServerMessage) => {
    const store = useDashboardStore.getState();

    switch (msg.type) {
      case 'init':
        store.applyInitPayload(msg);
        break;
      case 'metrics':
        store.applyMetricsPayload(msg);
        break;
      case 'event':
        store.addEvent(msg.event);
        if (msg.event.type === 'boost' || msg.event.type === 'warning') {
          store.addToast(msg.event.type, msg.event.message);
        } else if (msg.event.type === 'crash' || msg.event.type === 'error') {
          store.addToast('error', msg.event.message);
        }
        break;
      case 'auth_success':
        store.setAuthenticated(true);
        break;
      case 'auth_result':
        store.setAuthenticated(Boolean(msg.authenticated));
        break;
      case 'auth_failed':
        store.clearSession();
        store.addToast('error', 'Session PIN invalid or expired');
        break;
      case 'auth_required':
        store.setAuthenticated(false);
        store.clearPendingOperations();
        store.setAuthModalOpen(true);
        break;
      case 'error':
        store.clearPendingOperations();
        store.addToast('error', msg.error);
        break;
      case 'boost_result':
        store.setIsBoosting(false);
        store.setSummary(msg.summary);
        store.addToast(
          'boost',
          `RAM Boost freed ${msg.result.freed_mb} MB (${msg.result.processes_trimmed} procs)`
        );
        break;
      case 'boost_triggered':
        store.addToast(
          'boost',
          `Auto-Boost freed ${msg.result.freed_mb} MB RAM (${msg.result.processes_trimmed} procs)`
        );
        break;
      case 'session_summary':
      case 'session_boost_reset':
      case 'total_boost_reset':
        store.setSummary(msg.data);
        if (msg.type === 'session_boost_reset') {
          store.addToast('system', 'Session boost counter reset');
        } else if (msg.type === 'total_boost_reset') {
          store.addToast('system', 'Lifetime boost counter purged');
        }
        break;
      case 'config_updated':
        store.setConfig(msg.config);
        store.updateAutoBoost({
          enabled: msg.auto_boost.enabled,
          mode: msg.auto_boost.mode,
          threshold: msg.auto_boost.threshold,
          interval_minutes: msg.auto_boost.interval_minutes,
        });
        store.addToast(
          'system',
          `Auto-Boost updated (${msg.auto_boost.enabled ? 'Armed' : 'Disarmed'})`
        );
        break;
      case 'deep_clean_preview': {
        store.setIsScanningClean(false);
        const items = msg.items || msg.data || [];
        store.setDeepCleanPreview(items);
        store.addToast(
          'system',
          `Scanned ${msg.total_files ?? items.length} targets (${msg.total_size_mb ?? 0} MB)`
        );
        break;
      }
      case 'deep_clean_result': {
        store.setIsDeepCleaning(false);
        store.setDeepCleanPreview([]);
        const cleanRes = msg.result || msg.data;
        store.addToast(
          'success',
          `Deep Clean freed ${cleanRes.total_freed_mb} MB (${cleanRes.total_deleted} files)`
        );
        break;
      }
      case 'vm_disk_status':
        store.setVmDisk(msg.data);
        break;
      case 'vm_trim_result':
        store.addToast(
          msg.success ? 'success' : 'error',
          msg.success
            ? `VM /data trimmed on port ${msg.port}`
            : `VM trim failed on port ${msg.port}`
        );
        break;
      case 'hardening_status':
        store.setHardening(msg.data);
        break;
      case 'defender_status':
        store.setDefender(msg.data);
        break;
      case 'quick_scan_result':
        store.addToast(
          msg.success ? 'system' : 'warning',
          msg.success
            ? 'Windows Defender Quick Scan started'
            : 'Defender Quick Scan already running or unavailable'
        );
        break;
      case 'growth_data':
        store.setGrowthData(msg.data);
        break;
      case 'flush_dns_result':
        store.addToast(
          msg.success ? 'success' : 'error',
          msg.success ? 'DNS resolver cache flushed' : 'Failed to flush DNS cache'
        );
        break;
      case 'observatory_update':
        store.setObservatory(msg.data);
        break;
      case 'instance_game_updated':
        store.addToast(
          msg.ok ? 'success' : 'error',
          msg.ok
            ? `Instance #${msg.instance} target set to ${msg.game_name}`
            : `Failed to update Instance #${msg.instance} target`
        );
        break;
      case 'mumu_username_set':
        store.addToast(
          'system',
          msg.username
            ? `Bound @${msg.username} to Instance #${msg.instance}`
            : `Cleared username binding on Instance #${msg.instance}`
        );
        break;
      case 'mumu_trim_result':
        if (msg.data.success) {
          store.addToast(
            'success',
            `Trimmed ${msg.data.name} (freed ${msg.data.freed_mb} MB)`
          );
        } else {
          store.addToast('error', msg.data.error);
        }
        break;
      case 'timer_resolution_result':
        store.setTimerResolution(msg.data);
        store.addToast(
          'system',
          `Kernel Timer: ${msg.data.resolution_ms} ms (${msg.data.active ? '0.5ms Active' : 'Default'})`
        );
        break;
      case 'pcore_affinity_result':
        store.setPcoreAffinity(msg.data);
        store.addToast('system', `CPU Affinity: ${msg.data.mode}`);
        break;
      case 'shader_cache_result':
        store.setShaderCache(msg.data);
        if (msg.data.success !== false) {
          store.addToast(
            'success',
            `Shader cache flushed: ${msg.data.cleaned_files} files (${msg.data.cleaned_mb} MB)`
          );
        } else {
          store.addToast('error', msg.data.error);
        }
        break;
      case 'shader_cache_status':
        store.setShaderCache(msg.data);
        break;
      case 'governor_result':
        if (msg.data.success) {
          store.addToast(
            'success',
            `Instance #${msg.data.instance}: ${msg.data.action} completed`
          );
        } else {
          store.addToast('error', `Governor error: ${msg.data.error}`);
        }
        break;
      case 'alerts_delivery':
        store.pushAlertDelivery(msg.entry);
        break;
      case 'alerts_status':
        store.setAlertsStatus(msg.data);
        break;
      case 'alerts_history':
        store.setAlertsHistory(msg.data);
        break;
      case 'alerts_config_updated':
        store.setIsSavingAlerts(false);
        store.setAlertsStatus(msg.alerts);
        store.setConfig(msg.config);
        store.markAlertsSaved();
        store.addToast('success', 'Discord alert configuration saved');
        break;
      case 'alerts_test_result':
        store.setIsTestingAlert(false);
        store.setLastAlertTestResult(msg);
        store.pushAlertDelivery(msg.entry);
        if (msg.ok) {
          store.addToast(
            'success',
            `Test alert delivered (HTTP ${msg.http_status ?? 204})`
          );
        } else {
          store.addToast('error', `Test alert failed: ${msg.error || 'Unknown error'}`);
        }
        break;
      case 'alerts_purge_result':
        store.setIsPurgingAlerts(false);
        store.setLastAlertPurgeResult(msg);
        if (msg.ok) {
          store.addToast('success', `Purged ${msg.deleted_count} Discord message(s)`);
        } else {
          store.addToast('error', `Purge failed: ${msg.error || 'Unknown error'}`);
        }
        break;
      case 'tunnel_status':
        store.setTunnel(msg.data);
        if (msg.data.status === 'online' || msg.data.status === 'offline' || msg.data.status === 'local_only') {
          store.setIsRestartingTunnel(false);
        }
        break;
      case 'tunnel_restart_result':
        store.setTunnel(msg.tunnel);
        if (msg.ok) {
          store.addToast('system', 'Tunnel restart initiated');
        } else {
          store.setIsRestartingTunnel(false);
          store.addToast('warning', msg.error || 'Unable to restart tunnel');
        }
        break;
    }
  }, []);

  const connect = useCallback(() => {
    if (
      globalWs &&
      (globalWs.readyState === WebSocket.OPEN || globalWs.readyState === WebSocket.CONNECTING)
    ) {
      return;
    }

    const store = useDashboardStore.getState();
    store.setConnectionState(store.lastMessageAt ? 'reconnecting' : 'connecting');

    const currentToken = store.token;
    const url = buildWebSocketUrl(currentToken);

    try {
      const ws = new WebSocket(url);
      globalWs = ws;

      ws.onopen = () => {
        backoffMs = 1500;
        useDashboardStore.getState().setConnectionState('connected');
        const tok = useDashboardStore.getState().token;
        if (tok) {
          ws.send(JSON.stringify({ command: 'auth', token: tok }));
        }

        if (pendingCommands.length > 0) {
          const queue = [...pendingCommands];
          pendingCommands = [];
          queue.forEach(({ command, payload }) => {
            ws.send(JSON.stringify({ command, token: tok, ...payload }));
          });
        }
      };

      ws.onclose = () => {
        globalWs = null;
        useDashboardStore.getState().setConnectionState('reconnecting');
        if (reconnectTimer) clearTimeout(reconnectTimer);
        const wait = backoffMs;
        backoffMs = backoffMs === 1500 ? 3000 : 5000;
        reconnectTimer = setTimeout(() => {
          connectRef.current();
        }, wait);
      };

      ws.onerror = () => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.close();
        }
      };

      ws.onmessage = (event: MessageEvent<string>) => {
        const msg = parseWsServerMessage(event.data);
        if (msg) {
          handleIncomingMessage(msg);
        }
      };
    } catch {
      useDashboardStore.getState().setConnectionState('offline');
      if (reconnectTimer) clearTimeout(reconnectTimer);
      reconnectTimer = setTimeout(() => {
        connectRef.current();
      }, 3000);
    }
  }, [handleIncomingMessage]);

  useEffect(() => {
    connectRef.current = connect;
  }, [connect]);

  const sendCommand = useCallback(
    <K extends WsCommandName>(command: K, payload: WsCommandMap[K] = {} as WsCommandMap[K]) => {
      const currentToken = useDashboardStore.getState().token;
      const body: Record<string, unknown> = { command, token: currentToken, ...payload };
      if (globalWs && globalWs.readyState === WebSocket.OPEN) {
        globalWs.send(JSON.stringify(body));
      } else {
        pendingCommands.push({ command, payload: payload as Record<string, unknown> });
        useDashboardStore.getState().addToast('info', 'Connecting... Command queued');
        connect();
      }
    },
    [connect]
  );

  useEffect(() => {
    connect();

    const handleVisibility = () => {
      if (document.visibilityState === 'visible') {
        if (!globalWs || globalWs.readyState !== WebSocket.OPEN) {
          connect();
        }
      }
    };

    document.addEventListener('visibilitychange', handleVisibility);
    window.addEventListener('focus', handleVisibility);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibility);
      window.removeEventListener('focus', handleVisibility);
    };
  }, [connect]);

  return { sendCommand };
}
