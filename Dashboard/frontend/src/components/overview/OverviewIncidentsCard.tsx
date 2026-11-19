import React, { useMemo, useState } from 'react';
import { ArrowRight, BellRing, Terminal } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatEventTime, formatIsoToLocalTime } from '../../lib/format';
import type { AlertDeliveryStatus, EventLogEntry } from '../../types/dashboard';

type IncidentTab = 'events' | 'discord';
type EventFilter = 'all' | 'alerts' | 'boosts';

export const OverviewIncidentsCard: React.FC = () => {
  const eventHistory = useDashboardStore((s) => s.eventHistory);
  const alertsHistory = useDashboardStore((s) => s.alertsHistory);
  const setActiveView = useDashboardStore((s) => s.setActiveView);

  const [tab, setTab] = useState<IncidentTab>('events');
  const [filter, setFilter] = useState<EventFilter>('all');

  const filteredEvents = useMemo(() => {
    const items = eventHistory.filter((entry) => {
      if (filter === 'alerts') {
        return entry.type === 'warning' || entry.type === 'error' || entry.type === 'crash';
      }
      if (filter === 'boosts') {
        return entry.type === 'boost' || entry.type === 'clean' || entry.type === 'standby';
      }
      return true;
    });
    return items.slice(0, 8);
  }, [eventHistory, filter]);

  const recentAlerts = useMemo(() => alertsHistory.slice(0, 6), [alertsHistory]);

  const getEventDot = (type: EventLogEntry['type']) => {
    switch (type) {
      case 'crash':
      case 'error':
      case 'kill':
        return 'bg-ops-danger';
      case 'warning':
        return 'bg-ops-warn';
      case 'boost':
      case 'clean':
      case 'standby':
        return 'bg-ops-accent';
      default:
        return 'bg-ops-telemetry';
    }
  };

  const getDeliveryBadge = (status: AlertDeliveryStatus) => {
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
    <div className="ops-card p-4 flex flex-col gap-3 h-full">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          {tab === 'events' ? (
            <Terminal className="w-4 h-4 text-ops-telemetry shrink-0" />
          ) : (
            <BellRing className="w-4 h-4 text-ops-warn shrink-0" />
          )}
          <div className="flex items-center bg-ops-inset p-0.5 rounded-md border border-ops-border text-xs">
            <button
              type="button"
              onClick={() => setTab('events')}
              className={`px-2.5 py-1 rounded transition-colors ${
                tab === 'events'
                  ? 'bg-ops-elevated text-ops-text font-medium'
                  : 'text-ops-muted hover:text-ops-text'
              }`}
            >
              Recent Events
            </button>
            <button
              type="button"
              onClick={() => setTab('discord')}
              className={`px-2.5 py-1 rounded transition-colors ${
                tab === 'discord'
                  ? 'bg-ops-elevated text-ops-text font-medium'
                  : 'text-ops-muted hover:text-ops-text'
              }`}
            >
              Discord Log
            </button>
          </div>
        </div>

        <button
          type="button"
          onClick={() => setActiveView(tab === 'events' ? 'telemetry' : 'alerts')}
          className="text-xs text-ops-accent hover:text-blue-400 font-medium inline-flex items-center gap-1"
        >
          <span>View All</span>
          <ArrowRight className="w-3.5 h-3.5" />
        </button>
      </div>

      {/* Sub-filters for Events */}
      {tab === 'events' && (
        <div className="flex items-center gap-1.5 text-[11px] font-mono">
          {(['all', 'alerts', 'boosts'] as const).map((key) => (
            <button
              key={key}
              type="button"
              onClick={() => setFilter(key)}
              className={`px-2 py-0.5 rounded border capitalize transition-colors ${
                filter === key
                  ? 'bg-ops-elevated text-ops-text border-ops-borderStrong'
                  : 'bg-ops-inset text-ops-muted border-ops-border hover:text-ops-secondary'
              }`}
            >
              {key}
            </button>
          ))}
        </div>
      )}

      {/* List Body */}
      <div className="flex-1 min-h-[180px] rounded-md border border-ops-border bg-ops-inset p-2 overflow-y-auto max-h-64">
        {tab === 'events' ? (
          filteredEvents.length === 0 ? (
            <div className="h-full min-h-[160px] flex items-center justify-center text-xs font-mono text-ops-muted">
              No matching events recorded.
            </div>
          ) : (
            <div className="divide-y divide-ops-border">
              {filteredEvents.map((entry, idx) => (
                <div
                  key={`${entry.epoch ?? entry.time}-${idx}`}
                  className="py-1.5 px-1.5 flex items-start gap-2 text-xs"
                >
                  <span
                    className={`w-1.5 h-1.5 rounded-full mt-1.5 shrink-0 ${getEventDot(entry.type)}`}
                  />
                  <span className="num font-mono text-[11px] text-ops-muted shrink-0">
                    {formatEventTime(entry.time)}
                  </span>
                  <span className="text-ops-text break-words leading-snug">{entry.message}</span>
                </div>
              ))}
            </div>
          )
        ) : recentAlerts.length === 0 ? (
          <div className="h-full min-h-[160px] flex items-center justify-center text-xs font-mono text-ops-muted">
            No Discord alert deliveries recorded yet.
          </div>
        ) : (
          <div className="divide-y divide-ops-border">
            {recentAlerts.map((entry) => (
              <div
                key={entry.id}
                className="py-2 px-1.5 flex items-center justify-between gap-2 text-xs"
              >
                <div className="min-w-0">
                  <div className="text-ops-text font-medium truncate">{entry.title}</div>
                  <div className="text-[11px] font-mono text-ops-muted truncate">
                    {entry.event_type}
                    {entry.error ? ` - ${entry.error}` : ''}
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <span
                    className={`text-[10px] font-mono px-1.5 py-0.5 rounded border capitalize ${getDeliveryBadge(
                      entry.status
                    )}`}
                  >
                    {entry.status}
                  </span>
                  <span className="num font-mono text-[11px] text-ops-muted">
                    {formatIsoToLocalTime(entry.timestamp)}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
