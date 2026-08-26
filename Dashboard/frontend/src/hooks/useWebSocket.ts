import { useEffect, useCallback } from 'react';
import { useDashboardStore } from '../store/useDashboard';

// Shared module-level singleton WebSocket connection
let globalWs: WebSocket | null = null;
let reconnectTimer: any = null;
let pendingCommands: { command: string; payload: Record<string, any> }[] = [];

export function useWebSocket() {
  const setConnected = useDashboardStore((s) => s.setConnected);
  const setAuthenticated = useDashboardStore((s) => s.setAuthenticated);
  const updateInitPayload = useDashboardStore((s) => s.updateInitPayload);
  const updateMetricsPayload = useDashboardStore((s) => s.updateMetricsPayload);
  const addToast = useDashboardStore((s) => s.addToast);
  const addEvent = useDashboardStore((s) => s.addEvent);
  const setDeepCleanPreview = useDashboardStore((s) => s.setDeepCleanPreview);
  const setIsDeepCleaning = useDashboardStore((s) => s.setIsDeepCleaning);
  const setIsScanningClean = useDashboardStore((s) => s.setIsScanningClean);

  const connect = useCallback(() => {
    if (globalWs && (globalWs.readyState === WebSocket.OPEN || globalWs.readyState === WebSocket.CONNECTING)) {
      return;
    }

    const currentToken = useDashboardStore.getState().token;
    const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
    const host = window.location.host;
    const tokenQuery = currentToken ? `?token=${encodeURIComponent(currentToken)}` : '';
    const url = host.includes('5173') 
      ? `ws://127.0.0.1:7700/ws${tokenQuery}`
      : `${proto}://${host}/ws${tokenQuery}`;

    try {
      const ws = new WebSocket(url);
      globalWs = ws;

      ws.onopen = () => {
        setConnected(true);
        const tok = useDashboardStore.getState().token;
        if (tok) {
          ws.send(JSON.stringify({ command: 'auth', token: tok }));
        }

        // Flush pending queued commands
        if (pendingCommands.length > 0) {
          pendingCommands.forEach(({ command, payload }) => {
            ws.send(JSON.stringify({ command, token: tok, ...payload }));
          });
          pendingCommands = [];
        }
      };

      ws.onclose = () => {
        setConnected(false);
        globalWs = null;
        clearTimeout(reconnectTimer);
        reconnectTimer = setTimeout(connect, 1500);
      };

      ws.onerror = () => {
        if (ws.readyState === WebSocket.OPEN) ws.close();
      };

      ws.onmessage = (e) => {
        try {
          const data = JSON.parse(e.data);
          handleIncomingMessage(data);
        } catch (err) {
          console.error('WS Parse Error:', err);
        }
      };
    } catch (err) {
      console.error('WS Connection error:', err);
      reconnectTimer = setTimeout(connect, 2000);
    }
  }, [setConnected]);

  const handleIncomingMessage = (data: any) => {
    switch (data.type) {
      case 'init':
        updateInitPayload(data);
        break;
      case 'metrics':
        updateMetricsPayload(data);
        break;
      case 'event':
        if (data.event) {
          addEvent(data.event);
          if (data.event.type === 'boost' || data.event.type === 'warning' || data.event.type === 'crash') {
            addToast(data.event.type, data.event.message);
          }
        }
        break;
      case 'auth_success':
        setAuthenticated(true);
        break;
      case 'auth_result':
        setAuthenticated(!!data.authenticated);
        break;
      case 'auth_failed':
        setAuthenticated(false);
        addToast('error', 'Authentication failed');
        break;
      case 'auth_required':
        setAuthenticated(false);
        useDashboardStore.getState().setAuthModalOpen(true);
        break;
      case 'deep_clean_preview':
        setIsScanningClean(false);
        const cleanItems = data.data || data.items || [];
        setDeepCleanPreview(cleanItems);
        addToast('system', `Scanned ${data.total_files || cleanItems.length} junk targets (${data.total_size_mb || 0} MB)`);
        break;
      case 'deep_clean_result':
        setIsDeepCleaning(false);
        setDeepCleanPreview([]);
        const cleanRes = data.result || data.data || data;
        if (cleanRes && (cleanRes.success !== false || cleanRes.total_freed_mb !== undefined)) {
          addToast('system', `Cleaned ${cleanRes.total_freed_mb || cleanRes.freed_mb || 0} MB junk files`);
        } else {
          addToast('error', 'Deep clean completed with warnings');
        }
        break;
      case 'boost_result':
        if (data.result) {
          addToast('boost', `RAM Boost Complete: Purged Standby & Processes (Freed ${data.result.freed_mb || 0} MB)`);
        }
        break;
      case 'config_updated':
        if (data.auto_boost) {
          useDashboardStore.getState().updateAutoBoost(data.auto_boost);
          addToast('system', `Auto-Boost Configuration Updated (${data.auto_boost.enabled ? 'Armed' : 'Disarmed'})`);
        }
        break;
      case 'quick_scan_result':
        addToast('system', data.success ? 'Windows Defender Quick Scan Started in Background' : 'Quick Scan Initiated');
        break;
      case 'flush_dns_result':
        addToast('system', data.success ? 'DNS resolver cache flushed' : 'Failed to flush DNS');
        break;
      case 'mumu_trim_result':
        if (data.data?.success) {
          addToast('system', `Trimmed RAM for ${data.data.name || 'MuMu'} (Freed ${data.data.freed_mb} MB)`);
        }
        break;
    }
  };

  const sendCommand = useCallback(
    (command: string, payload: Record<string, any> = {}) => {
      const currentToken = useDashboardStore.getState().token;
      if (globalWs && globalWs.readyState === WebSocket.OPEN) {
        globalWs.send(JSON.stringify({ command, token: currentToken, ...payload }));
      } else {
        pendingCommands.push({ command, payload });
        addToast('info', 'Connecting... Command queued');
        connect();
      }
    },
    [connect, addToast]
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
