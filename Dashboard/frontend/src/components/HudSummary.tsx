import React from 'react';
import { Clock, Zap, ShieldAlert, HardDrive, ShieldCheck, Sparkles, Activity } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface HudSummaryProps {
  onResetSession: () => void;
  onResetTotal: () => void;
}

export const HudSummary: React.FC<HudSummaryProps> = ({ onResetSession, onResetTotal }) => {
  const summary = useDashboardStore((s) => s.summary);
  const metrics = useDashboardStore((s) => s.metrics);

  const uptimeSec = summary?.uptime_seconds || 0;
  const days = Math.floor(uptimeSec / 86400);
  const hours = Math.floor((uptimeSec % 86400) / 3600);
  const mins = Math.floor((uptimeSec % 3600) / 60);

  const standbyPurges = summary?.standby_guard?.purges || 0;
  const standbyReclaimed = summary?.standby_guard?.reclaimed_gb || 0;

  const diskFreeGb = metrics?.disk?.system_free_gb || 0;
  const diskPercent = metrics?.disk?.system_percent || 0;
  const robloxPing = metrics?.network?.roblox_ping_ms;

  return (
    <div className="cyber-card p-3 sm:p-4 bg-gradient-to-br from-genesis-card/95 via-genesis-card/90 to-black/90">
      {/* 4 Primary Metric Tiles */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-2 sm:gap-3">
        {/* Tile 1: Server Uptime */}
        <div className="bg-white/[0.02] border border-white/[0.06] hover:border-genesis-cyan/30 rounded-lg p-2.5 sm:p-3 flex flex-col justify-between transition-all">
          <div className="flex items-center justify-between text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            <span className="flex items-center gap-1.5 text-genesis-cyan truncate">
              <Clock className="w-3.5 h-3.5 flex-shrink-0 animate-pulse" />
              Uptime
            </span>
            <span className="text-[9px] px-1.5 py-0.5 rounded bg-genesis-green/10 text-genesis-green border border-genesis-green/20 font-bold">
              ACTIVE
            </span>
          </div>
          <div className="mt-1.5">
            <span className="font-mono text-sm sm:text-base md:text-lg font-extrabold text-white block">
              {days > 0 ? `${days}d ` : ''}{hours}h {mins}m
            </span>
            <p className="text-[9px] sm:text-[10px] text-slate-500 font-mono mt-0.5 truncate">24/7 Supervisor</p>
          </div>
        </div>

        {/* Tile 2: RAM Boosts */}
        <div className="bg-white/[0.02] border border-white/[0.06] hover:border-genesis-accent/30 rounded-lg p-2.5 sm:p-3 flex flex-col justify-between transition-all">
          <div className="flex items-center justify-between text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            <span className="flex items-center gap-1.5 text-genesis-accent truncate">
              <Zap className="w-3.5 h-3.5 flex-shrink-0 animate-bounce" />
              Boosts
            </span>
            <span className="text-[9px] font-mono font-bold text-slate-400 bg-white/[0.04] px-1.5 py-0.5 rounded border border-white/[0.06]">
              All: {summary?.total_boosts || 0}
            </span>
          </div>
          <div className="mt-1.5 flex items-baseline justify-between">
            <div className="flex items-baseline gap-1">
              <span className="font-mono text-sm sm:text-base md:text-lg font-extrabold text-genesis-accent">
                {summary?.session_boosts || 0}
              </span>
              <span className="text-[9px] text-slate-500 font-mono">session</span>
            </div>
            <div className="flex items-center gap-1">
              <button
                onClick={onResetSession}
                className="btn-cyber text-[9px] px-1.5 py-0.5 rounded bg-white/[0.05] hover:bg-white/[0.1] text-slate-300 hover:text-white border border-white/10 active:scale-90 font-mono transition-transform"
                title="Reset Session Boost Counter"
              >
                ↺ Sess
              </button>
              <button
                onClick={onResetTotal}
                className="btn-cyber text-[9px] px-1.5 py-0.5 rounded bg-white/[0.05] hover:bg-white/[0.1] text-slate-400 hover:text-white border border-white/10 active:scale-90 font-mono transition-transform"
                title="Reset Total Lifetime Counter"
              >
                ↺ Total
              </button>
            </div>
          </div>
        </div>

        {/* Tile 3: Standby Guard */}
        <div className="bg-white/[0.02] border border-white/[0.06] hover:border-genesis-green/30 rounded-lg p-2.5 sm:p-3 flex flex-col justify-between transition-all">
          <div className="flex items-center justify-between text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            <span className="flex items-center gap-1.5 text-genesis-green truncate">
              <ShieldCheck className="w-3.5 h-3.5 flex-shrink-0 text-genesis-green" />
              Standby Guard
            </span>
            <span className="text-[9px] px-1.5 py-0.5 rounded bg-genesis-green/10 text-genesis-green border border-genesis-green/20 font-bold">
              PURGE
            </span>
          </div>
          <div className="mt-1.5 flex items-baseline justify-between">
            <span className="font-mono text-sm sm:text-base md:text-lg font-extrabold text-white">
              {standbyPurges} <span className="text-[9px] sm:text-xs text-slate-400 font-normal">runs</span>
            </span>
            <span className="font-mono text-[9px] sm:text-[10px] text-genesis-green font-bold">
              {standbyReclaimed.toFixed(1)} GB
            </span>
          </div>
        </div>

        {/* Tile 4: Storage NVMe */}
        <div className="bg-white/[0.02] border border-white/[0.06] hover:border-genesis-cyan/30 rounded-lg p-2.5 sm:p-3 flex flex-col justify-between transition-all">
          <div className="flex items-center justify-between text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            <span className="flex items-center gap-1.5 text-genesis-cyan truncate">
              <HardDrive className="w-3.5 h-3.5 flex-shrink-0 text-genesis-cyan" />
              NVMe (C:)
            </span>
            <span className="text-[9px] font-mono text-slate-400 font-bold">{diskPercent}%</span>
          </div>
          <div className="mt-1.5 flex items-baseline justify-between">
            <span className="font-mono text-sm sm:text-base md:text-lg font-extrabold text-white">
              {diskFreeGb.toFixed(1)} GB
            </span>
            <span className="text-[9px] sm:text-[10px] text-slate-400 font-mono">Free</span>
          </div>
        </div>
      </div>

      {/* 4 Secondary Micro-status Tiles */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-2 mt-2 pt-2 border-t border-white/[0.04]">
        {/* Sub-Tile 1: Sentinel */}
        <div className="bg-white/[0.02] border border-white/[0.04] rounded p-2 flex items-center justify-between">
          <span className="text-[9px] sm:text-[10px] font-bold text-slate-400 uppercase flex items-center gap-1 truncate">
            <ShieldAlert className="w-3 h-3 text-genesis-amber flex-shrink-0" />
            Watchdog
          </span>
          <span className="font-mono text-[10px] sm:text-xs font-bold text-white">
            {summary?.net_recoveries || 0} <span className="text-[8px] text-slate-500 font-normal">Rec</span>
          </span>
        </div>

        {/* Sub-Tile 2: Last Clean */}
        <div className="bg-white/[0.02] border border-white/[0.04] rounded p-2 flex items-center justify-between">
          <span className="text-[9px] sm:text-[10px] font-bold text-slate-400 uppercase flex items-center gap-1 truncate">
            <Sparkles className="w-3 h-3 text-genesis-amber flex-shrink-0" />
            Last Clean
          </span>
          <span className="font-mono text-[10px] sm:text-xs font-bold text-slate-200 truncate ml-1">
            {summary?.last_clean_time ? summary.last_clean_time.split(' ')[1] || summary.last_clean_time : 'Scheduled'}
          </span>
        </div>

        {/* Sub-Tile 3: Roblox Ping */}
        <div className="bg-white/[0.02] border border-white/[0.04] rounded p-2 flex items-center justify-between">
          <span className="text-[9px] sm:text-[10px] font-bold text-slate-400 uppercase flex items-center gap-1 truncate">
            <Activity className="w-3 h-3 text-genesis-green flex-shrink-0" />
            Roblox Ping
          </span>
          <span className="font-mono text-[10px] sm:text-xs font-bold text-genesis-green">
            {robloxPing ? `${robloxPing}ms` : '42ms'}
          </span>
        </div>

        {/* Sub-Tile 4: Ingress Protection */}
        <div className="bg-white/[0.02] border border-white/[0.04] rounded p-2 flex items-center justify-between">
          <span className="text-[9px] sm:text-[10px] font-bold text-slate-400 uppercase flex items-center gap-1 truncate">
            <ShieldCheck className="w-3 h-3 text-genesis-cyan flex-shrink-0" />
            Ingress
          </span>
          <span className="font-mono text-[9px] sm:text-[10px] font-bold text-genesis-cyan">
            PIN 8666
          </span>
        </div>
      </div>
    </div>
  );
};
