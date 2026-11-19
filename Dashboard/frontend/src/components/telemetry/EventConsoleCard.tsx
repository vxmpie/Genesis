import React, { useMemo, useState } from 'react';
import { Pause, Play, Search, Terminal, Trash2 } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { formatEventTime } from '../../lib/format';
import type { EventLogEntry } from '../../types/dashboard';
import { CardHeader, OpsCard, StatusBadge, type SemanticTone } from '../ui';

type EventFilterKey =
  | 'all'
  | 'critical'
  | 'warning'
  | 'boost'
  | 'maintenance'
  | 'mumu'
  | 'system';

const STORAGE_KEY = 'genesis_event_filter';

const FILTER_OPTIONS: ReadonlyArray<{ key: EventFilterKey; label: string }> = [
  { key: 'all', label: 'All' },
  { key: 'critical', label: 'Critical' },
  { key: 'warning', label: 'Warning' },
  { key: 'boost', label: 'Boost' },
  { key: 'maintenance', label: 'Clean/Kill' },
  { key: 'mumu', label: 'MuMu' },
  { key: 'system', label: 'System' },
];

function getInitialFilter(): EventFilterKey {
  if (typeof window === 'undefined') return 'all';
  const saved = sessionStorage.getItem(STORAGE_KEY) as EventFilterKey | null;
  return FILTER_OPTIONS.some((f) => f.key === saved) && saved ? saved : 'all';
}

function matchesGroup(type: string, filter: EventFilterKey): boolean {
  if (filter === 'all') return true;
  if (filter === 'critical') return type === 'crash' || type === 'error';
  if (filter === 'warning') return type === 'warning';
  if (filter === 'boost') return type === 'boost' || type === 'standby';
  if (filter === 'maintenance') return type === 'clean' || type === 'kill';
  if (filter === 'mumu') return type === 'mumu';
  return type === 'system' || type === 'info' || !['crash', 'error', 'warning', 'boost', 'standby', 'clean', 'kill', 'mumu'].includes(type);
}

function getLevelTone(type: string): SemanticTone {
  switch (type) {
    case 'crash':
    case 'error':
    case 'kill':
      return 'danger';
    case 'warning':
      return 'warn';
    case 'boost':
    case 'standby':
    case 'clean':
      return 'accent';
    case 'mumu':
      return 'info';
    default:
      return 'muted';
  }
}

function formatRelativeAge(epoch: number | undefined): string | null {
  if (typeof epoch !== 'number' || !Number.isFinite(epoch)) return null;
  const diffSec = Math.max(0, Math.floor(Date.now() / 1000 - epoch));
  if (diffSec < 60) return `${diffSec}s ago`;
  if (diffSec < 3600) return `${Math.floor(diffSec / 60)}m ago`;
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)}h ago`;
  return `${Math.floor(diffSec / 86400)}d ago`;
}

export const EventConsoleCard: React.FC = () => {
  const eventHistory = useDashboardStore((s) => s.eventHistory);
  const clearEvents = useDashboardStore((s) => s.clearEvents);

  const [filter, setFilter] = useState<EventFilterKey>(getInitialFilter);
  const [search, setSearch] = useState('');
  const [pausedSnapshot, setPausedSnapshot] = useState<EventLogEntry[] | null>(null);

  const isPaused = pausedSnapshot !== null;
  const activeSource = pausedSnapshot ?? eventHistory;

  const queuedCount = useMemo(() => {
    if (!pausedSnapshot) return 0;
    const seen = new Set(pausedSnapshot.map((e) => `${e.time}|${e.message}`));
    return eventHistory.filter((e) => !seen.has(`${e.time}|${e.message}`)).length;
  }, [eventHistory, pausedSnapshot]);

  const counts = useMemo(() => {
    const result: Record<EventFilterKey, number> = {
      all: activeSource.length,
      critical: 0,
      warning: 0,
      boost: 0,
      maintenance: 0,
      mumu: 0,
      system: 0,
    };
    for (const entry of activeSource) {
      for (const opt of FILTER_OPTIONS) {
        if (opt.key !== 'all' && matchesGroup(entry.type, opt.key)) {
          result[opt.key] += 1;
        }
      }
    }
    return result;
  }, [activeSource]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return activeSource
      .filter((entry) => {
        if (!matchesGroup(entry.type, filter)) return false;
        if (!q) return true;
        return (
          entry.message.toLowerCase().includes(q) ||
          entry.type.toLowerCase().includes(q)
        );
      })
      .slice(0, 150);
  }, [activeSource, filter, search]);

  const handleSelectFilter = (next: EventFilterKey) => {
    setFilter(next);
    if (typeof window !== 'undefined') {
      sessionStorage.setItem(STORAGE_KEY, next);
    }
  };

  const togglePause = () => {
    if (isPaused) {
      setPausedSnapshot(null);
    } else {
      setPausedSnapshot(eventHistory);
    }
  };

  const handleClear = () => {
    setPausedSnapshot(null);
    clearEvents();
  };

  return (
    <OpsCard className="space-y-3">
      <CardHeader
        icon={<Terminal className="w-4 h-4 text-ops-telemetry" />}
        title="Full Event Console"
        subtitle="Real-time host, watchdog, and maintenance log stream (latest 150 entries)."
        badge={
          isPaused ? (
            <StatusBadge tone="warn">
              Paused{queuedCount > 0 ? ` (+${queuedCount} new)` : ''}
            </StatusBadge>
          ) : (
            <StatusBadge tone="ok" dot>
              Streaming
            </StatusBadge>
          )
        }
        actions={
          <div className="flex items-center gap-1.5">
            <button
              type="button"
              onClick={togglePause}
              className={`ops-btn h-8 px-2.5 border text-xs ${
                isPaused
                  ? 'bg-ops-warn/10 border-ops-warn/30 text-ops-warn'
                  : 'bg-ops-elevated hover:bg-ops-border border-ops-border text-ops-text'
              }`}
            >
              {isPaused ? (
                <>
                  <Play className="w-3.5 h-3.5" />
                  <span>Resume</span>
                </>
              ) : (
                <>
                  <Pause className="w-3.5 h-3.5" />
                  <span>Pause</span>
                </>
              )}
            </button>
            <button
              type="button"
              onClick={handleClear}
              className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-danger/15 border border-ops-border hover:border-ops-danger/30 text-xs text-ops-secondary hover:text-ops-danger"
            >
              <Trash2 className="w-3.5 h-3.5" />
              <span>Clear</span>
            </button>
          </div>
        }
      />

      {/* Filter Chips & Search */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-2.5">
        <div className="flex items-center gap-1.5 flex-wrap">
          {FILTER_OPTIONS.map((opt) => {
            const active = filter === opt.key;
            return (
              <button
                key={opt.key}
                type="button"
                onClick={() => handleSelectFilter(opt.key)}
                className={`num px-2.5 py-1 rounded-md text-[11px] font-mono border transition-colors ${
                  active
                    ? 'bg-ops-elevated text-ops-text border-ops-borderStrong font-semibold'
                    : 'bg-ops-inset text-ops-muted border-ops-border hover:text-ops-secondary'
                }`}
              >
                {opt.label} ({counts[opt.key]})
              </button>
            );
          })}
        </div>

        <div className="relative w-full lg:w-64 shrink-0">
          <Search className="w-3.5 h-3.5 text-ops-muted absolute left-2.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Filter log messages..."
            aria-label="Filter log messages"
            className="ops-input w-full h-8 pl-8 pr-3 text-xs font-mono"
          />
        </div>
      </div>

      {/* Console Log Stream */}
      <div className="h-[360px] overflow-y-auto rounded-md border border-ops-border bg-ops-inset divide-y divide-ops-border font-mono text-xs">
        {filtered.length === 0 ? (
          <div className="h-full flex items-center justify-center text-ops-muted font-sans text-xs">
            No matching events recorded.
          </div>
        ) : (
          filtered.map((entry, idx) => {
            const relAge = formatRelativeAge(entry.epoch);
            return (
              <div
                key={`${entry.epoch ?? entry.time}-${idx}`}
                className="px-3 py-2 flex items-start gap-2.5 hover:bg-ops-elevated/40 transition-colors"
              >
                <div className="shrink-0 w-24 text-[11px] text-ops-muted">
                  <div className="num text-ops-secondary">{formatEventTime(entry.time)}</div>
                  {relAge && <div className="num text-[10px]">{relAge}</div>}
                </div>

                <div className="shrink-0 pt-0.5">
                  <StatusBadge tone={getLevelTone(entry.type)}>
                    {entry.type.toUpperCase()}
                  </StatusBadge>
                </div>

                <div className="min-w-0 flex-1 text-ops-text font-sans text-xs leading-snug break-words">
                  {entry.message}
                </div>
              </div>
            );
          })
        )}
      </div>
    </OpsCard>
  );
};
