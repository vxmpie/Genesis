import React from 'react';
import { Lock, Search, Terminal, Unlock } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { disconnectAndReconnect } from '../../hooks/useWebSocket';
import { formatUptime } from '../../lib/format';
import { NAV_ITEMS } from './nav';

export const TopBar: React.FC = () => {
  const activeView = useDashboardStore((s) => s.activeView);
  const connectionState = useDashboardStore((s) => s.connectionState);
  const authenticated = useDashboardStore((s) => s.authenticated);
  const authRequired = useDashboardStore((s) => s.authRequired);
  const summary = useDashboardStore((s) => s.summary);
  const setCmdPaletteOpen = useDashboardStore((s) => s.setCmdPaletteOpen);
  const setAuthModalOpen = useDashboardStore((s) => s.setAuthModalOpen);
  const clearSession = useDashboardStore((s) => s.clearSession);
  const addToast = useDashboardStore((s) => s.addToast);

  const currentNav = NAV_ITEMS.find((item) => item.id === activeView) ?? NAV_ITEMS[0];

  const handleAuthPillClick = () => {
    if (authenticated) {
      clearSession();
      disconnectAndReconnect();
      addToast('info', 'Control session locked');
    } else {
      setAuthModalOpen(true);
    }
  };

  const connDot =
    connectionState === 'connected'
      ? 'bg-ops-ok'
      : connectionState === 'reconnecting' || connectionState === 'connecting'
      ? 'bg-ops-warn'
      : 'bg-ops-danger';

  const connLabel =
    connectionState === 'connected'
      ? 'Live'
      : connectionState === 'reconnecting'
      ? 'Reconnecting'
      : connectionState === 'connecting'
      ? 'Connecting'
      : 'Offline';

  return (
    <header className="sticky top-0 z-30 h-14 bg-ops-chrome/95 backdrop-blur-sm border-b border-ops-border px-3 sm:px-5 lg:px-6 flex items-center justify-between gap-3">
      {/* Left: Mobile Brand + Current Workspace Title */}
      <div className="flex items-center gap-2.5 min-w-0">
        <div className="lg:hidden w-8 h-8 rounded-md bg-ops-elevated border border-ops-borderStrong flex items-center justify-center shrink-0">
          <Terminal className="w-4 h-4 text-ops-accent" />
        </div>
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <h1 className="text-sm font-semibold text-ops-text tracking-tight truncate">
              {currentNav.label}
            </h1>
            <span className="hidden md:inline-block text-ops-borderStrong">/</span>
            <span className="hidden md:inline-block text-xs text-ops-muted truncate">
              {currentNav.description}
            </span>
          </div>
        </div>
      </div>

      {/* Right: Command Palette, Auth Status, Live Connection & Uptime */}
      <div className="flex items-center gap-2 shrink-0">
        <button
          type="button"
          onClick={() => setCmdPaletteOpen(true)}
          className="ops-btn h-8 px-2.5 bg-ops-surface hover:bg-ops-elevated border border-ops-border hover:border-ops-borderStrong text-xs text-ops-secondary hover:text-ops-text"
          title="Open Command Palette (Ctrl+K)"
        >
          <Search className="w-3.5 h-3.5 text-ops-muted" />
          <span className="hidden md:inline">Commands</span>
          <kbd className="hidden md:inline font-mono text-[10px] px-1.5 py-0.5 rounded bg-ops-inset border border-ops-border text-ops-muted">
            Ctrl K
          </kbd>
        </button>

        {authRequired && (
          <button
            type="button"
            onClick={handleAuthPillClick}
            title={authenticated ? 'Click to lock session' : 'Click to unlock PIN controls'}
            className={`ops-btn h-8 px-2.5 text-xs font-medium border ${
              authenticated
                ? 'bg-ops-ok/10 text-ops-ok border-ops-ok/30 hover:bg-ops-ok/15'
                : 'bg-ops-warn/10 text-ops-warn border-ops-warn/30 hover:bg-ops-warn/15'
            }`}
          >
            {authenticated ? (
              <Unlock className="w-3.5 h-3.5 shrink-0" />
            ) : (
              <Lock className="w-3.5 h-3.5 shrink-0" />
            )}
            <span className="hidden sm:inline">{authenticated ? 'Unlocked' : 'Locked'}</span>
          </button>
        )}

        <div
          className="h-8 px-2.5 rounded-md bg-ops-surface border border-ops-border flex items-center gap-2 text-xs"
          title={`WebSocket: ${connLabel}`}
        >
          <span className={`w-2 h-2 rounded-full shrink-0 ${connDot}`} />
          <span className="font-mono text-[11px] text-ops-text">{connLabel}</span>
          <span className="hidden sm:inline text-ops-borderStrong">|</span>
          <span className="hidden sm:inline num font-mono text-[11px] text-ops-secondary">
            {formatUptime(summary?.uptime_seconds)}
          </span>
        </div>
      </div>
    </header>
  );
};
