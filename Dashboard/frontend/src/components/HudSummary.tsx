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
      <div className="grid grid-cols-2 md:grid-cols-4 gap-2.5 sm:gap-3">
        {/* Tile 1: Server Uptime */}
        <div className="bg-white/[0.02] border border-white/[0.06] hover:border-genesis-cyan/30 rounded-lg p-2.5 sm:p-3 flex flex-col justify-between transition-all">
          <div className="flex items-center justify-between text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            <span className="flex items-center gap-1.5 text-genesis-cyan">
              <Clock className="w-3.5 h-3.5" />
              Uptime
            </span>
            <span className="text-[10px] px-1.5 py-0.5 rounded bg-genesis-green/10 text-genesis-green border border-genesis-green/20">
              ACTIVE
            </span>
          </div>
          <div className="mt-1">
            <span className="font-mono text-base sm:text-lg font-extrabold text-white">
              {days > 0 ? `${days}d ` : ''}{hours}h {mins}m
            </span>
            <p className="text-[10px] text-slate-500 font-mono mt-0.5">24/7 Supervisor Core</p>
          </div>
        </div>

        {/* Tile 2: RAM Boosts */}
        <div className="bg-white/[0.02] border border-white/[0.06] hover:border-genesis-accent/30 rounded-lg p-2.5 sm:p-3 flex flex-col justify-between transition-all">
          <div className="flex items-center justify-between text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            <span className="flex items-center gap-1.5 text-genesis-accent">
              <Zap className="w-3.5 h-3.5" />
              Boosts
            </span>
            <div className="flex items-center gap-1">
              <button
                onClick={onResetSession}
                className="text-[9px] px-1.5 py-0.5 rounded bg-white/[0.05] hover:bg-white/[0.1] text-slate-300 border border-white/10"
                title="Reset Session Boost Counter"
              >
                ↺ Session
              </button>
              <button
                onClick={onResetTotal}
                className="text-[9px] px-1.5 py-0.5 rounded bg-white/[0.05] hover:bg-white/[0.1] text-slate-400 border border-white/10"
                title="Reset Total Lifetime Counter (Requires PIN)"
              >
                ↺ Total
              </button>
            </div>
          </div>
          <div className="mt-1 flex items-baseline justify-between">
            <span className="font-mono text-base sm:text-lg font-extrabold text-genesis-accent">
              {summary?.session_boosts || 0}
            </span>
            <span className="font-mono text-[10px] text-slate-400 bg-white/[0.04] px-1.5 py-0.5 rounded border border-white/[0.06]">
              Lifetime: {summary?.total_boosts || 0}
            </span>
          </div>
        </div>

        {/* Tile 3: Standby Guard */}
        <div className="bg-white/[0.02] border border-white/[0.06] hover:border-genesis-green/30 rounded-lg p-2.5 sm:p-3 flex flex-col justify-between transition-all">
          <div className="flex items-center justify-between text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            <span className="flex items-center gap-1.5 text-genesis-green">
              <ShieldCheck className="w-3.5 h-3.5" />
              Standby Guard
            </span>
            <span className="text-[10px] px-1.5 py-0.5 rounded bg-genesis-green/10 text-genesis-green border border-genesis-green/20">
              MICRO-PURGE
            </span>
          </div>
          <div className="mt-1 flex items-baseline justify-between">
            <span className="font-mono text-base sm:text-lg font-extrabold text-white">
              {standbyPurges} <span className="text-xs text-slate-400 font-normal">purges</span>
            </span>
            <span className="font-mono text-[10px] text-genesis-green font-bold">
              {standbyReclaimed.toFixed(1)} GB Freed
            </span>
          </div>
        </div>

        {/* Tile 4: Storage NVMe */}
        <div className="bg-white/[0.02] border border-white/[0.06] hover:border-genesis-cyan/30 rounded-lg p-2.5 sm:p-3 flex flex-col justify-between transition-all">
          <div className="flex items-center justify-between text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            <span className="flex items-center gap-1.5 text-genesis-cyan">
              <HardDrive className="w-3.5 h-3.5" />
              NVMe SSD (C:)
            </span>
            <span className="text-[10px] font-mono text-slate-400">{diskPercent}% Used</span>
          </div>
          <div className="mt-1 flex items-baseline justify-between">
            <span className="font-mono text-base sm:text-lg font-extrabold text-white">
              {diskFreeGb.toFixed(1)} GB
            </span>
            <span className="text-[10px] text-slate-400">Free Space</span>
          </div>
        </div>

        {/* Tile 5: Watchdog Sentinel */}
        <div className="bg-white/[0.02] border border-white/[0.06] rounded-lg p-2 sm:p-2.5 flex items-center justify-between">
          <span className="text-[10px] font-bold text-slate-400 uppercase flex items-center gap-1">
            <ShieldAlert className="w-3 h-3 text-genesis-amber" />
            Watchdog Sentinel
          </span>
          <span className="font-mono text-xs font-bold text-white">
            {summary?.net_recoveries || 0} <span className="text-[10px] text-slate-500">Recoveries</span>
          </span>
        </div>

        {/* Tile 6: Cache Clean */}
        <div className="bg-white/[0.02] border border-white/[0.06] rounded-lg p-2 sm:p-2.5 flex items-center justify-between">
          <span className="text-[10px] font-bold text-slate-400 uppercase flex items-center gap-1">
            <Sparkles className="w-3 h-3 text-genesis-amber" />
            Last Cache Clean
          </span>
          <span className="font-mono text-xs font-bold text-slate-200">
            {summary?.last_clean_time ? summary.last_clean_time.split(' ')[1] || summary.last_clean_time : 'Scheduled'}
          </span>
        </div>

        {/* Tile 7: Windows Hardening */}
        <div className="bg-white/[0.02] border border-white/[0.06] rounded-lg p-2 sm:p-2.5 flex items-center justify-between">
          <span className="text-[10px] font-bold text-slate-400 uppercase flex items-center gap-1">
            <ShieldCheck className="w-3 h-3 text-genesis-green" />
            Hardening
          </span>
          <span
            className={`font-mono text-xs font-bold ${
              summary?.drift_detected ? 'text-genesis-amber' : 'text-genesis-green'
            }`}
          >
            {summary?.drift_detected ? 'Drift Detected' : '4/4 CIM Verified'}
          </span>
        </div>

        {/* Tile 8: CDN Edge Ping */}
        <div className="bg-white/[0.02] border border-white/[0.06] rounded-lg p-2 sm:p-2.5 flex items-center justify-between">
          <span className="text-[10px] font-bold text-slate-400 uppercase flex items-center gap-1">
            <Activity className="w-3 h-3 text-genesis-cyan" />
            Roblox CDN Ping
          </span>
          <span className="font-mono text-xs font-bold text-genesis-cyan">
            {robloxPing !== undefined ? `${robloxPing.toFixed(1)} ms` : '—'}
          </span>
        </div>
      </div>
    </div>
  );
};
