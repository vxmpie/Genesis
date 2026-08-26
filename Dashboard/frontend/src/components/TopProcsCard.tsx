import React from 'react';
import { BarChart3 } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

export const TopProcsCard: React.FC = () => {
  const topProcesses = useDashboardStore((s) => s.topProcesses);

  return (
    <div className="cyber-card p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <BarChart3 className="w-4 h-4 text-genesis-amber" />
          Top Processes
        </span>
        <span className="text-[10px] font-mono text-slate-400">By Memory</span>
      </div>

      {/* Table */}
      <div className="w-full overflow-x-auto rounded-lg border border-white/[0.06] bg-black/20">
        <table className="w-full text-left text-xs font-mono">
          <thead className="bg-white/[0.03] text-slate-400 border-b border-white/[0.06] text-[10px] uppercase">
            <tr>
              <th className="py-2 px-3">Process Name</th>
              <th className="py-2 px-3">PID</th>
              <th className="py-2 px-3">RAM</th>
              <th className="py-2 px-3">CPU%</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/[0.04] text-slate-200">
            {topProcesses.length === 0 ? (
              <tr>
                <td colSpan={4} className="py-6 text-center text-slate-500 font-sans">
                  Sampling processes...
                </td>
              </tr>
            ) : (
              topProcesses.map((p, idx) => (
                <tr key={`${p.pid}_${idx}`} className="hover:bg-white/[0.02]">
                  <td className="py-2 px-3 font-semibold text-slate-100 truncate max-w-[180px]" title={p.name}>
                    {p.name}
                  </td>
                  <td className="py-2 px-3 text-slate-400">{p.pid}</td>
                  <td className="py-2 px-3 text-genesis-blue font-bold">{p.ram_mb} MB</td>
                  <td className="py-2 px-3 text-slate-300">{p.cpu_percent}%</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
