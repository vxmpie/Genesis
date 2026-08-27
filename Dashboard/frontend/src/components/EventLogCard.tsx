import React from 'react';
import { Terminal, Zap, AlertTriangle, AlertOctagon, Info, Trash2 } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import type { EventLogEntry } from '../types/dashboard';

export const EventLogCard: React.FC = () => {
  const eventHistory = useDashboardStore((s) => s.eventHistory);
  const clearEvents = useDashboardStore((s) => s.clearEvents);

  const getEventIcon = (type: EventLogEntry['type']) => {
    switch (type) {
      case 'boost':
        return <Zap className="w-3.5 h-3.5 text-genesis-accent shrink-0 animate-pulse" />;
      case 'warning':
        return <AlertTriangle className="w-3.5 h-3.5 text-genesis-amber shrink-0 animate-bounce" />;
      case 'crash':
      case 'error':
      case 'kill':
        return <AlertOctagon className="w-3.5 h-3.5 text-red-500 shrink-0 animate-pulse" />;
      default:
        return <Info className="w-3.5 h-3.5 text-genesis-cyan shrink-0" />;
    }
  };

  return (
    <div className="cyber-card p-4 flex flex-col justify-start h-full">
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Terminal className="w-4 h-4 text-slate-300 animate-pulse" />
          Event Log
        </span>
        <button
          onClick={clearEvents}
          className="btn-cyber text-[10px] font-mono text-slate-400 hover:text-red-400 px-2 py-0.5 rounded bg-white/[0.04] hover:bg-red-500/10 border border-white/10 hover:border-red-500/30 transition-all flex items-center gap-1 active:scale-90"
        >
          <Trash2 className="w-3 h-3 hover:scale-110 transition-transform" />
          Clear
        </button>
      </div>

      {/* Log Console - Matches Top Processes Table Height */}
      <div className="h-[380px] sm:h-[390px] overflow-y-auto rounded-lg border border-white/[0.06] bg-black/40 p-2.5 space-y-1.5 font-mono text-xs">
        {eventHistory.length === 0 ? (
          <div className="h-full flex items-center justify-center text-slate-500 font-sans text-xs">
            No events recorded yet.
          </div>
        ) : (
          eventHistory.map((entry, idx) => {
            const timeDisplay = entry.time?.includes(' ') ? entry.time.split(' ')[1] : (entry.time || '');
            return (
              <div key={`${entry.time}-${idx}`} className="flex items-start gap-2 text-slate-300 hover:bg-white/[0.04] hover:text-white p-1 rounded transition-all duration-150">
                <span className="text-[10px] text-slate-500 shrink-0 font-mono pt-0.5">{timeDisplay}</span>
                {getEventIcon(entry.type)}
                <span className="text-xs break-all leading-tight">{entry.message}</span>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
