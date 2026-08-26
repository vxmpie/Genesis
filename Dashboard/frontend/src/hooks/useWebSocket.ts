import { useEffect, useRef, useCallback } from 'react';
import { useDashboardStore } from '../store/useDashboard';

export function useWebSocket() {
  const wsRef = useRef<WebSocket | null>(null);
  const pendingCommandsRef = useRef<{ command: string; payload: Record<string, any> }[]>([]);
  const reconnectTimeoutRef = useRef<any>(null);

  const token = useDashboardStore((s) => s.token);
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
    if (wsRef.current && (wsRef.current.readyState === WebSocket.OPEN || wsRef.current.readyState === WebSocket.CONNECTING)) {
      return;
    }

    const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
    const host = window.location.host;
    const tokenQuery = token ? `?token=${encodeURIComponent(token)}` : '';
    // In local dev vite mode (port 5173), proxy to port 7700 or use current host
    const url = host.includes('5173') 
      ? `ws://127.0.0.1:7700/ws${tokenQuery}`
      : `${proto}://${host}/ws${tokenQuery}`;

    try {
      const ws = new WebSocket(url);
      wsRef.current = ws;

      ws.onopen = () => {
        setConnected(true);
        if (token) {
          ws.send(JSON.stringify({ command: 'auth', token }));
        }

        // Flush pending queued commands
        if (pendingCommandsRef.current.length > 0) {
          pendingCommandsRef.current.forEach(({ command, payload }) => {
            ws.send(JSON.stringify({ command, token, ...payload }));
          });
          pendingCommandsRef.current = [];
        }
      };

      ws.onclose = () => {
        setConnected(false);
        wsRef.current = null;
        clearTimeout(reconnectTimeoutRef.current);
        reconnectTimeoutRef.current = setTimeout(connect, 1500);
      };

      ws.onerror = () => {
        ws.close();
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
      reconnectTimeoutRef.current = setTimeout(connect, 2000);
    }
  }, [token, setConnected]);

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
      case 'auth_result':
        setAuthenticated(data.authenticated);
        if (!data.authenticated) {
          addToast('error', 'Session locked: Invalid PIN');
        }
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
      if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
        wsRef.current.send(JSON.stringify({ command, token, ...payload }));
      } else {
        pendingCommandsRef.current.push({ command, payload });
        addToast('info', 'Connecting... Command queued');
        connect();
      }
    },
    [token, connect, addToast]
  );

  useEffect(() => {
    connect();

    const handleVisibility = () => {
      if (document.visibilityState === 'visible') {
        if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
          connect();
        }
      }
    };

    document.addEventListener('visibilitychange', handleVisibility);
    window.addEventListener('focus', handleVisibility);

    return () => {
      clearTimeout(reconnectTimeoutRef.current);
      document.removeEventListener('visibilitychange', handleVisibility);
      window.removeEventListener('focus', handleVisibility);
      if (wsRef.current) wsRef.current.close();
    };
  }, [connect]);

  return { sendCommand };
}
