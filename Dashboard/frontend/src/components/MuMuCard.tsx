import React from 'react';
import { Gamepad2, Edit3, Scissors } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface MuMuCardProps {
  onTrimMemory: (pid: number, index: number) => void;
}

export const MuMuCard: React.FC<MuMuCardProps> = ({ onTrimMemory }) => {
  const mumu = useDashboardStore((s) => s.mumu);
  const openEditGameModal = useDashboardStore((s) => s.openEditGameModal);

  const devices = mumu?.devices || [];
  const runningCount = devices.length;

  return (
    <div className="cyber-card p-4 flex flex-col justify-start gap-3">
      {/* Header */}
      <div className="flex items-center justify-between">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Gamepad2 className="w-4 h-4 text-genesis-cyan" />
          MuMu Instances
        </span>
        <span className={`text-[10px] font-mono font-bold px-2 py-0.5 rounded border ${
          runningCount > 0
            ? 'bg-genesis-cyan/10 text-genesis-cyan border-genesis-cyan/30 shadow-[0_0_8px_rgba(0,229,255,0.2)]'
            : 'bg-white/[0.04] text-slate-500 border-white/[0.06]'
        }`}>
          {runningCount} {runningCount === 1 ? 'instance' : 'instances'} running
        </span>
      </div>

      {/* Responsive Table Container */}
      <div className="w-full overflow-x-auto rounded-lg border border-white/[0.06] bg-black/20">
        <table className="w-full text-left text-xs font-mono min-w-[500px]">
          <thead className="bg-white/[0.03] text-slate-400 border-b border-white/[0.06] text-[10px] uppercase">
            <tr>
              <th className="py-2 px-3">#</th>
              <th className="py-2 px-3">Type</th>
              <th className="py-2 px-3">Target Game</th>
              <th className="py-2 px-3">CPU%</th>
              <th className="py-2 px-3">RAM</th>
              <th className="py-2 px-3">Uptime</th>
              <th className="py-2 px-3 text-right">Action</th>
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
                const targetGame = dev.target_game || dev.target_game_name || 'Storage Hunters';

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
                          className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded bg-genesis-cyan/10 hover:bg-genesis-cyan/20 border border-genesis-cyan/30 text-genesis-cyan text-[11px] font-bold transition-all group"
                          title="Click to change target game / place ID"
                        >
                          <Gamepad2 className="w-3 h-3" />
                          <span>{targetGame}</span>
                          <Edit3 className="w-2.5 h-2.5 opacity-60 group-hover:opacity-100" />
                        </button>
                      ) : (
                        <span className="text-slate-500">—</span>
                      )}
                    </td>
                    <td className="py-2.5 px-3 text-slate-300">{dev.cpu_percent || 0}%</td>
                    <td className="py-2.5 px-3 text-genesis-blue font-bold">{dev.ram_mb} MB</td>
                    <td className="py-2.5 px-3 text-slate-400">{dev.uptime || '—'}</td>
                    <td className="py-2.5 px-3 text-right">
                      {isEmulator && (
                        <button
                          onClick={() => onTrimMemory(dev.pid, index)}
                          className="p-1 rounded bg-white/[0.04] hover:bg-genesis-accent/20 text-slate-400 hover:text-genesis-accent border border-white/10 hover:border-genesis-accent/30 transition-all"
                          title="Trim working set memory"
                        >
                          <Scissors className="w-3.5 h-3.5" />
                        </button>
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
