import React, { useState } from 'react';
import { Zap } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface AutoBoostCardProps {
  onToggle: (enabled: boolean) => void;
  onSetThreshold: (val: number) => void;
  onSetMode: (mode: 'auto' | 'scheduled') => void;
  onSetInterval: (minutes: number) => void;
  onBoostNow: () => void;
}

export const AutoBoostCard: React.FC<AutoBoostCardProps> = ({
  onToggle,
  onSetThreshold,
  onSetMode,
  onSetInterval,
  onBoostNow,
}) => {
  const autoBoost = useDashboardStore((s) => s.autoBoost);
  const [boosting, setBoosting] = useState(false);

  const enabled = autoBoost?.enabled ?? true;
  const threshold = autoBoost?.threshold ?? 40;
  const mode = autoBoost?.mode ?? 'scheduled';
  const intervalMinutes = autoBoost?.interval_minutes ?? 60;

  const handleBoost = () => {
    setBoosting(true);
    onBoostNow();
    setTimeout(() => setBoosting(false), 1200);
  };

  return (
    <div className="cyber-card p-4 flex flex-col justify-between">
      {/* Header */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
            <Zap className="w-4 h-4 text-genesis-accent animate-pulse" />
            Auto-Boost Engine
          </span>
          <span
            className={`text-[10px] font-bold px-2 py-0.5 rounded-full border transition-all ${
              enabled
                ? 'bg-genesis-green/10 text-genesis-green border-genesis-green/30 shadow-glow-green'
                : 'bg-slate-800 text-slate-400 border-slate-700'
            }`}
          >
            {enabled ? 'ARMED' : 'DISARMED'}
          </span>
        </div>

        {/* Control Rows */}
        <div className="flex flex-col gap-2.5 divide-y divide-white/[0.06]">
          {/* 1. Status Toggle */}
          <div className="flex items-center justify-between pt-1">
            <label className="text-xs font-medium text-slate-300">Autonomous Sentinel</label>
            <button
              onClick={() => onToggle(!enabled)}
              className={`w-11 h-6 rounded-full transition-all relative p-0.5 btn-cyber active:scale-90 ${
                enabled ? 'bg-genesis-green shadow-glow-green' : 'bg-slate-700'
              }`}
            >
              <div
                className={`w-5 h-5 rounded-full bg-white transition-all transform duration-200 ${
                  enabled ? 'translate-x-5' : 'translate-x-0'
                }`}
              />
            </button>
          </div>

          {/* 2. Threshold Stepper */}
          <div className="flex items-center justify-between pt-2">
            <label className="text-xs font-medium text-slate-300">RAM Threshold</label>
            <div className="flex items-center gap-2">
              <button
                onClick={() => onSetThreshold(Math.max(10, Math.floor((threshold - 1) / 5) * 5))}
                className="btn-cyber w-7 h-7 rounded bg-white/[0.06] hover:bg-white/[0.12] hover:text-white flex items-center justify-center text-slate-300 border border-white/10 font-mono text-sm font-bold active:scale-90"
              >
                -
              </button>
              <span className="font-mono text-xs font-bold text-genesis-amber min-w-[36px] text-center">
                {threshold}%
              </span>
              <button
                onClick={() => onSetThreshold(Math.min(95, Math.ceil((threshold + 1) / 5) * 5))}
                className="btn-cyber w-7 h-7 rounded bg-white/[0.06] hover:bg-white/[0.12] hover:text-white flex items-center justify-center text-slate-300 border border-white/10 font-mono text-sm font-bold active:scale-90"
              >
                +
              </button>
            </div>
          </div>

          {/* 3. Mode Selector */}
          <div className="flex items-center justify-between pt-2">
            <label className="text-xs font-medium text-slate-300">Operating Mode</label>
            <select
              value={mode}
              onChange={(e) => onSetMode(e.target.value as any)}
              className="bg-black/50 border border-white/10 rounded px-2.5 py-1 text-xs font-mono text-slate-200 outline-none focus:border-genesis-accent hover:border-white/20 transition-colors"
            >
              <option value="scheduled">Scheduled Clock</option>
              <option value="auto">Dynamic Threshold</option>
            </select>
          </div>

          {/* 4. Interval Selector (if in scheduled mode) */}
          {mode === 'scheduled' && (
            <div className="flex items-center justify-between pt-2">
              <label className="text-xs font-medium text-slate-300">Interval</label>
              <select
                value={intervalMinutes}
                onChange={(e) => onSetInterval(Number(e.target.value))}
                className="bg-black/50 border border-white/10 rounded px-2.5 py-1 text-xs font-mono text-slate-200 outline-none focus:border-genesis-accent hover:border-white/20 transition-colors"
              >
                <option value={15}>15 min</option>
                <option value={30}>30 min</option>
                <option value={60}>60 min (Clock :00)</option>
                <option value={120}>2 hours</option>
              </select>
            </div>
          )}
        </div>
      </div>

      {/* Boost Status Info (Last Boost & Next Scheduled Boost) */}
      <div className="mt-4 pt-2 border-t border-white/[0.06]">
        <div className="text-[11px] font-mono mb-2.5 flex flex-col sm:flex-row sm:items-center justify-between gap-1 p-2 rounded bg-black/30 border border-white/[0.04]">
          <div className="flex items-center gap-1.5 truncate">
            <span className="text-slate-500">Last:</span>
            <span className="text-genesis-accent font-bold">{autoBoost?.last_boost_time || 'Never'}</span>
          </div>
          <div className="flex items-center gap-1.5 truncate">
            <span className="text-slate-500">Next:</span>
            <span className="text-genesis-cyan font-bold">{autoBoost?.next_boost?.text || (enabled ? 'Scheduled' : 'Disabled')}</span>
          </div>
        </div>

        <button
          onClick={handleBoost}
          disabled={boosting}
          className={`btn-cyber w-full py-2.5 px-4 rounded-lg font-bold text-xs uppercase tracking-wider flex items-center justify-center gap-2 transition-all duration-200 active:scale-95 ${
            boosting
              ? 'bg-gradient-to-r from-orange-600 via-genesis-accent to-red-600 text-white animate-pulse shadow-glow-accent'
              : 'bg-gradient-to-r from-red-600 via-genesis-accent to-orange-500 hover:brightness-110 text-white shadow-glow-accent'
          }`}
        >
          <Zap className={`w-4 h-4 ${boosting ? 'animate-spin text-white' : 'animate-bounce'}`} />
          <span>{boosting ? 'Purging Standby & Processes...' : 'Boost RAM Now'}</span>
        </button>
      </div>
    </div>
  );
};
