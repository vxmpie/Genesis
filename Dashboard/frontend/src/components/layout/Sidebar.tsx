import React from 'react';
import {
  PanelLeftClose,
  PanelLeftOpen,
  Terminal,
} from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { NAV_ITEMS } from './nav';

export const Sidebar: React.FC = () => {
  const activeView = useDashboardStore((s) => s.activeView);
  const setActiveView = useDashboardStore((s) => s.setActiveView);
  const collapsed = useDashboardStore((s) => s.sidebarCollapsed);
  const toggleCollapsed = useDashboardStore((s) => s.toggleSidebarCollapsed);
  const mumuCount = useDashboardStore((s) => s.mumu?.count ?? 0);
  const hasDrift = useDashboardStore((s) => s.hardening?.has_drift ?? false);
  const alertsFailed = useDashboardStore((s) => s.alertsStatus?.failed_count ?? 0);
  const tunnel = useDashboardStore((s) => s.tunnel);

  const hasAlertsIssue = alertsFailed > 0 || tunnel?.status === 'offline';

  const tunnelStatusDot =
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
    <aside
      aria-label="Primary navigation"
      className={`hidden lg:flex flex-col shrink-0 bg-ops-chrome border-r border-ops-border transition-[width] duration-150 ${
        collapsed ? 'w-16' : 'w-60'
      }`}
    >
      {/* Brand Header */}
      <div className="h-14 px-3.5 border-b border-ops-border flex items-center justify-between gap-2">
        <button
          type="button"
          onClick={() => setActiveView('overview')}
          className="flex items-center gap-2.5 min-w-0 text-left focus:outline-none"
          title="Genesis Operations Console"
        >
          <div className="w-8 h-8 rounded-md bg-ops-elevated border border-ops-borderStrong flex items-center justify-center shrink-0 text-ops-text">
            <Terminal className="w-4 h-4 text-ops-accent" />
          </div>
          {!collapsed && (
            <div className="min-w-0">
              <div className="text-sm font-semibold tracking-tight text-ops-text leading-tight truncate">
                Genesis
              </div>
              <div className="text-[10px] font-mono uppercase tracking-widest text-ops-muted leading-tight">
                Ops Console
              </div>
            </div>
          )}
        </button>
      </div>

      {/* Navigation Links */}
      <nav className="flex-1 p-2 space-y-1 overflow-y-auto">
        {NAV_ITEMS.map((item) => {
          const Icon = item.icon;
          const isActive = activeView === item.id;

          return (
            <button
              key={item.id}
              type="button"
              onClick={() => setActiveView(item.id)}
              title={collapsed ? `${item.label} (${item.shortcut})` : undefined}
              aria-current={isActive ? 'page' : undefined}
              className={`w-full flex items-center gap-2.5 px-2.5 py-2 rounded-md text-xs font-medium transition-colors duration-150 relative ${
                isActive
                  ? 'bg-ops-elevated text-ops-text border border-ops-borderStrong'
                  : 'text-ops-secondary hover:text-ops-text hover:bg-ops-elevated/50 border border-transparent'
              }`}
            >
              {isActive && (
                <span
                  aria-hidden="true"
                  className="absolute left-0 top-1.5 bottom-1.5 w-0.5 rounded-r bg-ops-accent"
                />
              )}
              <Icon
                className={`w-4 h-4 shrink-0 ${
                  isActive ? 'text-ops-accent' : 'text-ops-secondary'
                }`}
              />
              {!collapsed && (
                <>
                  <span className="flex-1 text-left truncate">{item.label}</span>
                  {item.id === 'instances' && mumuCount > 0 && (
                    <span className="num font-mono text-[10px] px-1.5 py-0.5 rounded bg-ops-inset border border-ops-border text-ops-text">
                      {mumuCount}
                    </span>
                  )}
                  {item.id === 'system' && hasDrift && (
                    <span
                      className="w-2 h-2 rounded-full bg-ops-warn shrink-0"
                      title="Hardening drift detected"
                    />
                  )}
                  {item.id === 'alerts' && hasAlertsIssue && (
                    <span
                      className="w-2 h-2 rounded-full bg-ops-danger shrink-0"
                      title="Alert delivery failure or tunnel offline"
                    />
                  )}
                </>
              )}
            </button>
          );
        })}
      </nav>

      {/* Footer: Tunnel Quick Indicator & Collapse Control */}
      <div className="p-2 border-t border-ops-border space-y-1.5">
        <button
          type="button"
          onClick={() => setActiveView('alerts')}
          title={tunnel?.tunnel_url || tunnel?.local_url || 'Inspect tunnel status'}
          className={`w-full flex items-center gap-2 px-2.5 py-2 rounded-md bg-ops-inset border border-ops-border hover:border-ops-borderStrong text-left transition-colors ${
            collapsed ? 'justify-center' : ''
          }`}
        >
          <span className={`w-2 h-2 rounded-full shrink-0 ${tunnelStatusDot}`} />
          {!collapsed && (
            <div className="min-w-0 flex-1">
              <div className="text-[11px] font-medium text-ops-text truncate capitalize">
                {tunnelLabel}
              </div>
              <div className="text-[10px] font-mono text-ops-muted truncate">
                {tunnel?.tunnel_url || tunnel?.local_url || '—'}
              </div>
            </div>
          )}
        </button>

        <button
          type="button"
          onClick={toggleCollapsed}
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          className={`w-full flex items-center gap-2 px-2.5 py-1.5 rounded-md text-xs text-ops-muted hover:text-ops-text hover:bg-ops-elevated/60 transition-colors ${
            collapsed ? 'justify-center' : ''
          }`}
        >
          {collapsed ? (
            <PanelLeftOpen className="w-4 h-4 shrink-0" />
          ) : (
            <>
              <PanelLeftClose className="w-4 h-4 shrink-0" />
              <span>Collapse</span>
            </>
          )}
        </button>
      </div>
    </aside>
  );
};
