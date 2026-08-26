import React from 'react';
import { Cpu } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

export const CpuCoresCard: React.FC = () => {
  const perCore = useDashboardStore((s) => s.metrics?.cpu?.per_core) || [];

  return (
    <div className="cyber-card p-4">
      {/* Header & Legend */}
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Cpu className="w-4 h-4 text-genesis-cyan" />
          CPU Per-Core Usage
        </span>
        <div className="flex items-center gap-3 text-[11px] font-bold">
          <span className="flex items-center gap-1 text-genesis-accent">
            <span className="w-2 h-2 rounded-full bg-genesis-accent" />
            P-Cores (0-7)
          </span>
          <span className="flex items-center gap-1 text-genesis-blue">
            <span className="w-2 h-2 rounded-full bg-genesis-blue" />
            E-Cores (8-15)
          </span>
        </div>
      </div>

      {/* Responsive Grid: 16 cols on desktop, 8 cols (2 rows) on mobile */}
      <div className="grid grid-cols-8 md:grid-cols-16 gap-1.5 sm:gap-2 items-end h-28 sm:h-24 pt-2">
        {Array.from({ length: 16 }).map((_, i) => {
          const load = perCore[i] || 0;
          const isPCore = i < 8;

          return (
            <div key={i} className="flex flex-col items-center justify-end h-full gap-1 group">
              {/* Load Bar Container */}
              <div className="w-full h-20 sm:h-16 bg-white/[0.04] rounded-t-sm flex items-end overflow-hidden relative">
                <div
                  className={`w-full transition-all duration-500 rounded-t-sm ${
                    isPCore
                      ? 'bg-gradient-to-t from-red-600 to-genesis-accent shadow-glow-accent'
                      : 'bg-gradient-to-t from-blue-600 to-genesis-blue shadow-[0_0_8px_rgba(59,130,246,0.3)]'
                  }`}
                  style={{ height: `${Math.max(load, 3)}%` }}
                  title={`Core #${i}: ${load}%`}
                />
              </div>

              {/* Core Index Label */}
              <span className="font-mono text-[9px] font-bold text-slate-400 group-hover:text-white transition-colors">
                {i}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};
