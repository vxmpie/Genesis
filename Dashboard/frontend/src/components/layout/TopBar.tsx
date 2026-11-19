import React from 'react';
import { Lock, Search, Terminal, Unlock } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { disconnectAndReconnect } from '../../hooks/useWebSocket';
import { formatUptime } from '../../lib/format';
import { NAV_ITEMS } from './nav';

export const TopBar: React.FC = () => {
  const activeView = useDashboardStore((s) => s.activeView);
  const setActiveView = useDashboardStore((s) => s.setActiveView);
  const connectionState = useDashboardStore((s) => s.connectionState);
  const authenticated = useDashboardStore((s) => s.authenticated);
  const authRequired = useDashboardStore((s) => s.authRequired);
  const summary = useDashboardStore((s) => s.summary);
  const mumuCount = useDashboardStore((s) => s.mumu?.count ?? 0);
  const hasDrift = useDashboardStore((s) => s.hardening?.has_drift ?? false);
  const alertsFailed = useDashboardStore((s) => s.alertsStatus?.failed_count ?? 0);
  const tunnel = useDashboardStore((s) => s.tunnel);
  const setCmdPaletteOpen = useDashboardStore((s) => s.setCmdPaletteOpen);
  const setAuthModalOpen = useDashboardStore((s) => s.setAuthModalOpen);
  const clearSession = useDashboardStore((s) => s.clearSession);
  const addToast = useDashboardStore((s) => s.addToast);

  const currentNav = NAV_ITEMS.find((item) => item.id === activeView) ?? NAV_ITEMS[0];
  const hasAlertsIssue = alertsFailed > 0 || tunnel?.status === 'offline';

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

  const tunnelDot =
    tunnel?.status === 'online'
      ? 'bg-ops-ok'
      : tunnel?.status === 'connecting' || tunnel?.status === 'restarting'
      ? 'bg-ops-warn'
      : tunnel?.status === 'offline'
      ? 'bg-ops-danger'
      : 'bg-ops-muted';

  const tunnelLabel =
    tunnel?.status === 'online'
      ? `${tunnel.provider} online`
      : tunnel?.status === 'local_only'
      ? 'Local only'
      : tunnel?.status
      ? `${tunnel.provider} ${tunnel.status}`
      : 'Tunnel pending';

  return (
    <header className="sticky top-0 z-30 bg-ops-chrome/95 backdrop-blur-md border-b border-ops-border safe-top-bar">
      {/* Tier 1: Brand & Status Chrome (Center kept clear for iPad multitasking pill) */}
      <div className="max-w-[1440px] mx-auto px-3 sm:px-5 lg:px-6 min-h-[52px] py-2 flex items-center justify-between gap-3">
        {/* Left: Brand (Tablet/Desktop) or Active Room Label (Mobile) */}
        <div className="flex items-center gap-2.5 min-w-0 shrink-0">
          <button
            type="button"
            onClick={() => setActiveView('overview')}
            aria-label="Genesis Operations Console"
            className="flex items-center gap-2.5 text-left rounded-md focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ops-accent/50 group"
            title="Genesis Operations Console"
          >
            <div className="w-8 h-8 rounded-md bg-ops-elevated border border-ops-borderStrong group-hover:border-ops-accent/50 flex items-center justify-center shrink-0 transition-colors">
              <Terminal className="w-4 h-4 text-ops-accent" />
            </div>
            <div className="hidden md:flex items-center gap-2 shrink-0 whitespace-nowrap">
              <span className="text-sm font-semibold tracking-tight text-ops-text">
                Genesis
              </span>
              <span className="text-ops-borderStrong">/</span>
              <span className="text-[11px] font-mono uppercase tracking-wider text-ops-muted">
                Ops Console
              </span>
            </div>
          </button>

          <h1 className="md:hidden text-sm font-semibold text-ops-text tracking-tight whitespace-nowrap shrink-0">
            {currentNav.label}
          </h1>
        </div>

        {/* Right: Command Palette, Auth Status, Live Connection & Uptime */}
        <div className="flex items-center gap-2 shrink-0">
          <button
            type="button"
            onClick={() => setCmdPaletteOpen(true)}
            className="ops-btn h-8 px-2.5 bg-ops-surface hover:bg-ops-elevated border border-ops-border hover:border-ops-borderStrong text-xs text-ops-secondary hover:text-ops-text"
            title="Open Command Palette (Ctrl+K)"
          >
            <Search className="w-3.5 h-3.5 text-ops-muted shrink-0" />
            <span className="hidden md:inline">Commands</span>
            <kbd className="hidden xl:inline font-mono text-[10px] px-1.5 py-0.5 rounded bg-ops-inset border border-ops-border text-ops-muted">
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
            <span className="font-mono text-[11px] text-ops-text whitespace-nowrap">{connLabel}</span>
            <span className="hidden sm:inline text-ops-borderStrong">|</span>
            <span className="hidden sm:inline num font-mono text-[11px] text-ops-secondary whitespace-nowrap">
              {formatUptime(summary?.uptime_seconds)}
            </span>
          </div>
        </div>
      </div>

      {/* Tier 2: Workspace Tab Bar (Tablet & Desktop) */}
      <div className="hidden md:block border-t border-ops-border/70">
        <div className="max-w-[1440px] mx-auto px-3 sm:px-5 lg:px-6 flex items-center justify-between gap-4">
          <nav
            aria-label="Primary navigation"
            className="flex items-center gap-1 -mb-px overflow-x-auto"
          >
            {NAV_ITEMS.map((item) => {
              const Icon = item.icon;
              const isActive = activeView === item.id;

              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => setActiveView(item.id)}
                  aria-current={isActive ? 'page' : undefined}
                  title={`${item.label} (${item.shortcut}) — ${item.description}`}
                  className={`px-3 py-2.5 text-xs font-medium inline-flex items-center gap-2 whitespace-nowrap border-b-2 transition-colors shrink-0 ${
                    isActive
                      ? 'border-ops-accent text-ops-text'
                      : 'border-transparent text-ops-secondary hover:text-ops-text hover:border-ops-borderStrong'
                  }`}
                >
                  <Icon
                    className={`w-3.5 h-3.5 shrink-0 ${
                      isActive ? 'text-ops-accent' : 'text-ops-secondary'
                    }`}
                  />
                  <span>{item.label}</span>
                  {item.id === 'instances' && mumuCount > 0 && (
                    <span className="num font-mono text-[10px] px-1.5 py-0.5 rounded bg-ops-inset border border-ops-border text-ops-text">
                      {mumuCount}
                    </span>
                  )}
                  {item.id === 'system' && hasDrift && (
                    <span
                      className="w-1.5 h-1.5 rounded-full bg-ops-warn shrink-0"
                      title="Hardening drift detected"
                    />
                  )}
                  {item.id === 'alerts' && hasAlertsIssue && (
                    <span
                      className="w-1.5 h-1.5 rounded-full bg-ops-danger shrink-0"
                      title="Alert delivery failure or tunnel offline"
                    />
                  )}
                </button>
              );
            })}
          </nav>

          <button
            type="button"
            onClick={() => setActiveView('alerts')}
            title={tunnel?.tunnel_url || tunnel?.local_url || 'Inspect public tunnel status'}
            className="hidden lg:inline-flex items-center gap-2 px-2.5 py-1 rounded-md bg-ops-inset border border-ops-border hover:border-ops-borderStrong text-[11px] font-mono text-ops-secondary hover:text-ops-text transition-colors shrink-0 whitespace-nowrap"
          >
            <span className={`w-1.5 h-1.5 rounded-full shrink-0 ${tunnelDot}`} />
            <span className="capitalize">{tunnelLabel}</span>
          </button>
        </div>
      </div>
    </header>
  );
};
