import React, { useMemo, useState } from 'react';
import { RefreshCw } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatIsoToLocalTime } from '../../lib/format';
import type { AlertDeliveryStatus, AlertSeverity } from '../../types/dashboard';

interface AlertDeliveryLogCardProps {
  onRefresh: () => void;
}

type StatusFilter = 'all' | AlertDeliveryStatus;

export const AlertDeliveryLogCard: React.FC<AlertDeliveryLogCardProps> = ({ onRefresh }) => {
  const alertsHistory = useDashboardStore((s) => s.alertsHistory);
  const [filter, setFilter] = useState<StatusFilter>('all');
  const [refreshing, setRefreshing] = useState(false);

  const counts = useMemo(() => {
    let delivered = 0;
    let failed = 0;
    let suppressed = 0;
    for (const item of alertsHistory) {
      if (item.status === 'delivered') delivered += 1;
      else if (item.status === 'failed') failed += 1;
      else suppressed += 1;
    }
    return {
      all: alertsHistory.length,
      delivered,
      failed,
      suppressed,
    };
  }, [alertsHistory]);

  const filtered = useMemo(() => {
    if (filter === 'all') return alertsHistory;
    return alertsHistory.filter((entry) => entry.status === filter);
  }, [alertsHistory, filter]);

  const handleRefresh = () => {
    setRefreshing(true);
    onRefresh();
    setTimeout(() => setRefreshing(false), 600);
  };

  const severityBadge = (sev: AlertSeverity) => {
    switch (sev) {
      case 'critical':
        return 'bg-ops-danger/10 text-ops-danger border-ops-danger/30';
      case 'warning':
        return 'bg-ops-warn/10 text-ops-warn border-ops-warn/30';
      case 'recovery':
        return 'bg-ops-ok/10 text-ops-ok border-ops-ok/30';
      default:
        return 'bg-ops-accent/10 text-ops-accent border-ops-accent/30';
    }
  };

  const statusBadge = (status: AlertDeliveryStatus) => {
    switch (status) {
      case 'delivered':
        return 'bg-ops-ok/10 text-ops-ok border-ops-ok/30';
      case 'failed':
        return 'bg-ops-danger/10 text-ops-danger border-ops-danger/30';
      default:
        return 'bg-ops-warn/10 text-ops-warn border-ops-warn/30';
    }
  };

  return (
    <div className="ops-card p-4 space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2.5">
        <div>
          <h2 className="text-xs font-semibold text-ops-text uppercase tracking-wider">
            Delivery History (Last 50)
          </h2>
          <p className="text-xs text-ops-secondary mt-0.5">
            Live queue outcomes across delivered, failed, and cooldown-suppressed dispatches.
          </p>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <div className="flex items-center bg-ops-inset p-0.5 rounded-md border border-ops-border text-[11px] font-mono">
            {(['all', 'delivered', 'failed', 'suppressed'] as const).map((key) => (
              <button
                key={key}
                type="button"
                onClick={() => setFilter(key)}
                className={`num px-2.5 py-1 rounded capitalize transition-colors ${
                  filter === key
                    ? 'bg-ops-elevated text-ops-text border border-ops-borderStrong'
                    : 'text-ops-muted hover:text-ops-text border border-transparent'
                }`}
              >
                {key} ({counts[key]})
              </button>
            ))}
          </div>

          <button
            type="button"
            onClick={handleRefresh}
            className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text"
            title="Refresh delivery history"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${refreshing ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      <div className="overflow-x-auto max-h-80 rounded-md border border-ops-border bg-ops-inset">
        <table className="w-full text-left text-xs font-mono min-w-[680px]">
          <thead className="sticky top-0 bg-ops-chrome text-[10px] uppercase text-ops-muted border-b border-ops-border">
            <tr>
              <th className="py-2 px-3">Time</th>
              <th className="py-2 px-3">Severity</th>
              <th className="py-2 px-3">Event / Title</th>
              <th className="py-2 px-3">Status</th>
              <th className="py-2 px-3">HTTP / Tries</th>
              <th className="py-2 px-3">Details</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-ops-border text-ops-text">
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={6} className="py-8 text-center text-ops-muted font-sans">
                  No alert delivery records match this filter.
                </td>
              </tr>
            ) : (
              filtered.map((entry) => (
                <tr key={entry.id} className="hover:bg-ops-elevated/50 transition-colors">
                  <td
                    className="num py-2 px-3 text-ops-secondary whitespace-nowrap"
                    title={entry.timestamp}
                  >
                    {formatIsoToLocalTime(entry.timestamp)}
                  </td>
                  <td className="py-2 px-3">
                    <span
                      className={`text-[10px] px-1.5 py-0.5 rounded border uppercase ${severityBadge(
                        entry.severity
                      )}`}
                    >
                      {entry.severity}
                    </span>
                  </td>
                  <td className="py-2 px-3 font-sans">
                    <div className="text-ops-text font-medium truncate max-w-[260px]" title={entry.title}>
                      {entry.title}
                    </div>
                    <div className="font-mono text-[10px] text-ops-muted truncate max-w-[260px]">
                      {entry.event_type} ({entry.dedupe_key})
                    </div>
                  </td>
                  <td className="py-2 px-3">
                    <span
                      className={`text-[10px] px-1.5 py-0.5 rounded border capitalize ${statusBadge(
                        entry.status
                      )}`}
                    >
                      {entry.status}
                    </span>
                  </td>
                  <td className="num py-2 px-3 text-ops-secondary whitespace-nowrap">
                    {entry.http_status !== null ? `HTTP ${entry.http_status}` : '—'} / {entry.attempts}x
                  </td>
                  <td
                    className="py-2 px-3 text-ops-secondary font-sans truncate max-w-[260px]"
                    title={entry.error || undefined}
                  >
                    {entry.error || '—'}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
