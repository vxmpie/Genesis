import React from 'react';
import { Cpu, Zap, Activity } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

export const CpuCoresCard: React.FC = () => {
  const perCore = useDashboardStore((s) => s.metrics?.cpu?.per_core) || [];
  const cpuCount = useDashboardStore((s) => s.metrics?.cpu?.count) || 16;
  const cpuGhz = useDashboardStore((s) => s.metrics?.cpu?.frequency_ghz);

  const pCores = perCore.slice(0, 8);
  const eCores = perCore.slice(8, 16);

  const pCoreAvg = pCores.length ? Math.round(pCores.reduce((a, b) => a + b, 0) / pCores.length) : 0;
  const eCoreAvg = eCores.length ? Math.round(eCores.reduce((a, b) => a + b, 0) / eCores.length) : 0;

  return (
    <div className="cyber-card p-4">
      {/* Main Header */}
      <div className="flex flex-wrap items-center justify-between gap-2 mb-4 pb-2 border-b border-white/[0.06]">
        <div className="flex items-center gap-2">
          <Cpu className="w-4 h-4 text-genesis-cyan" />
          <span className="text-xs font-bold text-white uppercase tracking-wider">
            CPU Core Telemetry Matrix
          </span>
          <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-white/[0.04] text-slate-400 border border-white/[0.08]">
            {cpuCount} Logical Threads {cpuGhz ? `• ${cpuGhz.toFixed(1)} GHz` : ''}
          </span>
        </div>

        {/* Global Averages */}
        <div className="flex items-center gap-3 text-xs font-mono">
          <span className="flex items-center gap-1.5 text-genesis-accent font-bold">
            <span className="w-2 h-2 rounded-full bg-genesis-accent animate-pulse" />
            P-Avg: {pCoreAvg}%
          </span>
          <span className="flex items-center gap-1.5 text-genesis-cyan font-bold">
            <span className="w-2 h-2 rounded-full bg-genesis-cyan animate-pulse" />
            E-Avg: {eCoreAvg}%
          </span>
        </div>
      </div>

      {/* Two Dedicated Sub-Panels: P-Cores vs E-Cores */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Panel 1: Performance Cores (0-7) */}
        <div className="bg-black/30 border border-red-500/20 rounded-xl p-3 flex flex-col justify-between">
          <div className="flex items-center justify-between mb-2">
            <span className="flex items-center gap-1.5 text-xs font-bold text-genesis-accent">
              <Zap className="w-3.5 h-3.5" />
              P-Cores (Threads 0 – 7)
            </span>
            <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-red-500/10 text-red-400 border border-red-500/20">
              High Performance
            </span>
          </div>

          {/* 8 P-Core Vertical Bars */}
          <div className="grid grid-cols-8 gap-1.5 sm:gap-2 items-end h-32 pt-2">
            {Array.from({ length: 8 }).map((_, i) => {
              const load = pCores[i] !== undefined ? Math.round(pCores[i]) : 0;
              return (
                <div key={`p_${i}`} className="flex flex-col items-center justify-end h-full gap-1 group">
                  {/* Live Value % above bar */}
                  <span className={`font-mono text-[9px] font-bold transition-colors ${load > 70 ? 'text-red-400 font-extrabold' : 'text-slate-300 group-hover:text-genesis-accent'}`}>
                    {load}%
                  </span>

                  {/* Load Bar Container */}
                  <div
                    className="w-full bg-white/[0.04] rounded-t-md flex items-end overflow-hidden relative border-b border-red-500/40"
                    style={{ height: '84px' }}
                  >
                    <div
                      className="w-full bg-gradient-to-t from-red-600 via-genesis-accent to-orange-400 rounded-t-sm transition-all duration-300 ease-out"
                      style={{
                        height: `${Math.min(Math.max(load, 4), 100)}%`,
                        boxShadow: load > 15 ? '0 0 10px rgba(255, 60, 60, 0.5)' : 'none',
                      }}
                      title={`P-Core #${i}: ${load}%`}
                    />
                  </div>

                  {/* Core Label */}
                  <span className="font-mono text-[9px] font-bold text-slate-500 group-hover:text-white transition-colors">
                    #{i}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Panel 2: Efficiency Cores (8-15) */}
        <div className="bg-black/30 border border-genesis-cyan/20 rounded-xl p-3 flex flex-col justify-between">
          <div className="flex items-center justify-between mb-2">
            <span className="flex items-center gap-1.5 text-xs font-bold text-genesis-cyan">
              <Activity className="w-3.5 h-3.5" />
              E-Cores (Cores 8 – 15)
            </span>
            <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
              High Efficiency
            </span>
          </div>

          {/* 8 E-Core Vertical Bars */}
          <div className="grid grid-cols-8 gap-1.5 sm:gap-2 items-end h-32 pt-2">
            {Array.from({ length: 8 }).map((_, i) => {
              const coreIdx = i + 8;
              const load = eCores[i] !== undefined ? Math.round(eCores[i]) : 0;
              return (
                <div key={`e_${coreIdx}`} className="flex flex-col items-center justify-end h-full gap-1 group">
                  {/* Live Value % above bar */}
                  <span className={`font-mono text-[9px] font-bold transition-colors ${load > 70 ? 'text-cyan-300 font-extrabold' : 'text-slate-300 group-hover:text-genesis-cyan'}`}>
                    {load}%
                  </span>

                  {/* Load Bar Container */}
                  <div
                    className="w-full bg-white/[0.04] rounded-t-md flex items-end overflow-hidden relative border-b border-genesis-cyan/40"
                    style={{ height: '84px' }}
                  >
                    <div
                      className="w-full bg-gradient-to-t from-blue-600 via-genesis-cyan to-teal-300 rounded-t-sm transition-all duration-300 ease-out"
                      style={{
                        height: `${Math.min(Math.max(load, 4), 100)}%`,
                        boxShadow: load > 15 ? '0 0 10px rgba(0, 229, 255, 0.5)' : 'none',
                      }}
                      title={`E-Core #${coreIdx}: ${load}%`}
                    />
                  </div>

                  {/* Core Label */}
                  <span className="font-mono text-[9px] font-bold text-slate-500 group-hover:text-white transition-colors">
                    #{coreIdx}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};
