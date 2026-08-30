import React, { useState } from 'react';
import { Gamepad2, Edit3, Scissors, RotateCcw, Square } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface MuMuCardProps {
  onTrimMemory: (pid: number, index: number) => void;
  onGovernorAction?: (instance: number, action: 'restart_game' | 'trim_ram' | 'kill_game') => void;
}

export const MuMuCard: React.FC<MuMuCardProps> = ({ onTrimMemory, onGovernorAction }) => {
  const mumu = useDashboardStore((s) => s.mumu);
  const openEditGameModal = useDashboardStore((s) => s.openEditGameModal);
  const [activeAction, setActiveAction] = useState<string | null>(null);

  const devices = mumu?.devices || [];
  const runningCount = devices.length;

  const handleAction = (index: number, pid: number, action: 'restart_game' | 'trim_ram' | 'kill_game') => {
    const key = `${index}_${action}`;
    setActiveAction(key);
    if (action === 'trim_ram') {
      onTrimMemory(pid, index);
    }
    if (onGovernorAction) {
      onGovernorAction(index, action);
    }
    setTimeout(() => setActiveAction(null), 1200);
  };

  return (
    <div className="cyber-card p-4 flex flex-col justify-start gap-3">
      {/* Header */}
      <div className="flex items-center justify-between">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Gamepad2 className="w-4 h-4 text-genesis-cyan animate-pulse" />
          MuMu Instances & Governor
        </span>
        <span className={`text-[10px] font-mono font-bold px-2 py-0.5 rounded border ${
          runningCount > 0
            ? 'bg-genesis-cyan/10 text-genesis-cyan border-genesis-cyan/30 shadow-[0_0_8px_rgba(0,229,255,0.2)]'
            : 'bg-white/[0.04] text-slate-500 border-white/[0.06]'
        }`}>
          {runningCount} {runningCount === 1 ? 'instance' : 'instances'} active
        </span>
      </div>

      {/* Responsive Table Container */}
      <div className="w-full overflow-x-auto rounded-lg border border-white/[0.06] bg-black/20">
        <table className="w-full text-left text-xs font-mono min-w-[540px]">
          <thead className="bg-white/[0.03] text-slate-400 border-b border-white/[0.06] text-[10px] uppercase">
            <tr>
              <th className="py-2 px-3">#</th>
              <th className="py-2 px-3">Type</th>
              <th className="py-2 px-3">Active Game / Target</th>
              <th className="py-2 px-3">CPU%</th>
              <th className="py-2 px-3">RAM</th>
              <th className="py-2 px-3">Uptime</th>
              <th className="py-2 px-3 text-right">Governor Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/[0.04] text-slate-200">
            {devices.length === 0 ? (
              <tr>
                <td colSpan={7} className="py-6 text-center text-slate-500 font-sans">
                  No active MuMu Player instances detected
                </td>
              </tr>
            ) : (
              devices.map((dev, idx) => {
                const index = dev.index ?? dev.instance_index ?? (idx + 1);
                const isEmulator = (dev.type || '').toLowerCase().includes('emulator') || (dev.name || '').toLowerCase().includes('device');
                const targetGame = dev.active_game || dev.target_game || dev.target_game_name || 'Storage Hunters';
                const isBusyRestart = activeAction === `${index}_restart_game`;
                const isBusyTrim = activeAction === `${index}_trim_ram`;
                const isBusyKill = activeAction === `${index}_kill_game`;

                return (
                  <tr key={dev.pid || index} className="hover:bg-white/[0.02] transition-colors">
                    <td className="py-2.5 px-3 font-bold text-white">#{index}</td>
                    <td className="py-2.5 px-3">
                      <span
                        className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${
                          isEmulator
                            ? 'bg-genesis-cyan/10 text-genesis-cyan border border-genesis-cyan/30'
                            : 'bg-slate-800 text-slate-400 border border-slate-700'
                        }`}
                      >
                        {isEmulator ? 'Emulator' : (dev.type || 'Launcher')}
                      </span>
                    </td>
                    <td className="py-2.5 px-3">
                      {isEmulator ? (
                        <button
                          onClick={() => openEditGameModal(dev)}
                          className={`btn-cyber inline-flex items-center gap-1.5 px-2 py-1 rounded border text-[11px] font-bold active:scale-95 transition-all group ${
                            dev.presence_status === 'InGame'
                              ? 'bg-emerald-500/15 hover:bg-emerald-500/25 border-emerald-500/40 text-emerald-300 shadow-[0_0_10px_rgba(16,185,129,0.2)]'
                              : dev.presence_status === 'Online'
                              ? 'bg-amber-500/15 hover:bg-amber-500/25 border-amber-500/40 text-amber-300'
                              : 'bg-genesis-cyan/10 hover:bg-genesis-cyan/20 border-genesis-cyan/30 text-genesis-cyan'
                          }`}
                          title="Click to change target game / bind Roblox username for live auto-detection"
                        >
                          <Gamepad2 className={`w-3.5 h-3.5 group-hover:rotate-12 transition-transform ${dev.presence_status === 'InGame' ? 'text-emerald-400 animate-pulse' : ''}`} />
                          <div className="flex flex-col items-start text-left leading-tight">
                            <div className="flex items-center gap-1">
                              {dev.presence_status === 'InGame' && (
                                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping inline-block" />
                              )}
                              <span>{targetGame}</span>
                            </div>
                            {dev.username && (
                              <span className="text-[9px] opacity-75 font-normal">
                                @{dev.username} {dev.presence_status === 'InGame' ? '• Playing' : `• ${dev.presence_status}`}
                              </span>
                            )}
                          </div>
                          <Edit3 className="w-2.5 h-2.5 opacity-60 group-hover:opacity-100 ml-1" />
                        </button>
                      ) : (
                        <span className="text-slate-500">—</span>
                      )}
                    </td>
                    <td className="py-2.5 px-3 text-slate-300">{dev.cpu_percent || 0}%</td>
                    <td className="py-2.5 px-3 text-genesis-blue font-bold">{dev.ram_mb} MB</td>
                    <td className="py-2.5 px-3 text-slate-400">{dev.uptime || '—'}</td>
                    <td className="py-2.5 px-3 text-right">
                      {isEmulator ? (
                        <div className="inline-flex items-center gap-1.5 justify-end">
                          {/* Restart Roblox */}
                          <button
                            onClick={() => handleAction(index, dev.pid, 'restart_game')}
                            disabled={isBusyRestart}
                            className={`btn-cyber p-1.5 rounded border transition-all active:scale-90 ${
                              isBusyRestart
                                ? 'bg-genesis-green text-black border-genesis-green shadow-[0_0_8px_rgba(0,230,118,0.4)]'
                                : 'bg-white/[0.04] hover:bg-genesis-green/20 text-slate-400 hover:text-genesis-green border-white/10 hover:border-genesis-green/30'
                            }`}
                            title="Soft Restart Roblox on Instance"
                          >
                            <RotateCcw className={`w-3.5 h-3.5 ${isBusyRestart ? 'animate-spin' : 'hover:scale-110'} transition-transform`} />
                          </button>

                          {/* Trim RAM */}
                          <button
                            onClick={() => handleAction(index, dev.pid, 'trim_ram')}
                            disabled={isBusyTrim}
                            className={`btn-cyber p-1.5 rounded border transition-all active:scale-90 ${
                              isBusyTrim
                                ? 'bg-genesis-accent text-white border-genesis-accent animate-pulse shadow-glow-accent'
                                : 'bg-white/[0.04] hover:bg-genesis-accent/20 text-slate-400 hover:text-genesis-accent border-white/10 hover:border-genesis-accent/30'
                            }`}
                            title="Trim RAM & Drop Caches on Instance"
                          >
                            <Scissors className={`w-3.5 h-3.5 ${isBusyTrim ? 'animate-spin' : 'hover:scale-110'} transition-transform`} />
                          </button>

                          {/* Kill Roblox */}
                          <button
                            onClick={() => handleAction(index, dev.pid, 'kill_game')}
                            disabled={isBusyKill}
                            className={`btn-cyber p-1.5 rounded border transition-all active:scale-90 ${
                              isBusyKill
                                ? 'bg-red-500 text-white border-red-500 animate-pulse'
                                : 'bg-white/[0.04] hover:bg-red-500/20 text-slate-400 hover:text-red-400 border-white/10 hover:border-red-500/30'
                            }`}
                            title="Force Stop Roblox on Instance"
                          >
                            <Square className="w-3.5 h-3.5 hover:scale-110 transition-transform" />
                          </button>
                        </div>
                      ) : (
                        <span className="text-slate-500">—</span>
                      )}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
