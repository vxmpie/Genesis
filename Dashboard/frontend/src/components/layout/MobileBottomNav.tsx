import React from 'react';
import { useDashboardStore } from '../../store/useDashboard';
import { NAV_ITEMS } from './nav';

export const MobileBottomNav: React.FC = () => {
  const activeView = useDashboardStore((s) => s.activeView);
  const setActiveView = useDashboardStore((s) => s.setActiveView);
  const mumuCount = useDashboardStore((s) => s.mumu?.count ?? 0);
  const hasDrift = useDashboardStore((s) => s.hardening?.has_drift ?? false);
  const alertsFailed = useDashboardStore((s) => s.alertsStatus?.failed_count ?? 0);
  const tunnelStatus = useDashboardStore((s) => s.tunnel?.status);

  const hasAlertsIssue = alertsFailed > 0 || tunnelStatus === 'offline';

  return (
    <nav
      aria-label="Mobile navigation"
      className="lg:hidden fixed bottom-0 inset-x-0 z-40 bg-ops-chrome/95 backdrop-blur-sm border-t border-ops-border pb-[env(safe-area-inset-bottom)]"
    >
      <div className="grid grid-cols-5">
        {NAV_ITEMS.map((item) => {
          const Icon = item.icon;
          const isActive = activeView === item.id;
          return (
            <button
              key={item.id}
              type="button"
              onClick={() => setActiveView(item.id)}
              aria-current={isActive ? 'page' : undefined}
              className={`relative min-h-[56px] px-1 py-1.5 flex flex-col items-center justify-center gap-1 transition-colors ${
                isActive ? 'text-ops-text' : 'text-ops-muted hover:text-ops-secondary'
              }`}
            >
              {isActive && (
                <span
                  aria-hidden="true"
                  className="absolute top-0 inset-x-3 h-0.5 bg-ops-accent rounded-b"
                />
              )}
              <div className="relative">
                <Icon className={`w-4 h-4 ${isActive ? 'text-ops-accent' : ''}`} />
                {item.id === 'instances' && mumuCount > 0 && (
                  <span className="num absolute -top-1.5 -right-2.5 min-w-[14px] h-[14px] px-0.5 rounded-full bg-ops-accent text-white font-mono text-[9px] font-semibold flex items-center justify-center">
                    {mumuCount}
                  </span>
                )}
                {item.id === 'system' && hasDrift && (
                  <span className="absolute -top-0.5 -right-1 w-2 h-2 rounded-full bg-ops-warn" />
                )}
                {item.id === 'alerts' && hasAlertsIssue && (
                  <span className="absolute -top-0.5 -right-1 w-2 h-2 rounded-full bg-ops-danger" />
                )}
              </div>
              <span className="text-[10px] font-medium truncate max-w-full">
                {item.shortLabel}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
};
