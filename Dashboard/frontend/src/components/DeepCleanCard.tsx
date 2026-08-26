import React from 'react';
import { Sparkles, Trash2, Search, Zap, CheckCircle2 } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface DeepCleanCardProps {
  onScan: () => void;
  onExecuteClean: () => void;
}

export const DeepCleanCard: React.FC<DeepCleanCardProps> = ({ onScan, onExecuteClean }) => {
  const deepCleanPreview = useDashboardStore((s) => s.deepCleanPreview);
  const isScanning = useDashboardStore((s) => s.isScanningClean);
  const isCleaning = useDashboardStore((s) => s.isDeepCleaning);

  const totalMb = deepCleanPreview.reduce((acc, item) => acc + item.size_mb, 0);
  const totalFiles = deepCleanPreview.reduce((acc, item) => acc + item.file_count, 0);

  return (
    <div className="cyber-card p-4 relative overflow-hidden">
      {/* Laser Sweep Effect while Cleaning */}
      {isCleaning && (
        <div className="absolute inset-0 bg-gradient-to-r from-transparent via-red-500/10 to-transparent animate-pulse pointer-events-none z-10" />
      )}

      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Sparkles className="w-4 h-4 text-genesis-amber" />
          Deep Clean Engine
        </span>
        <div className="flex items-center gap-2">
          <button
            onClick={onScan}
            disabled={isScanning || isCleaning}
            className="px-3 py-1 text-xs font-medium text-slate-300 bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 rounded-md transition-all flex items-center gap-1.5 disabled:opacity-50"
          >
            <Search className={`w-3.5 h-3.5 ${isScanning ? 'animate-spin text-genesis-cyan' : ''}`} />
            <span>{isScanning ? 'Scanning...' : 'Scan'}</span>
          </button>
          <button
            onClick={onExecuteClean}
            disabled={isCleaning || deepCleanPreview.length === 0}
            className={`px-3 py-1 text-xs font-bold rounded-md transition-all flex items-center gap-1.5 ${
              deepCleanPreview.length > 0 && !isCleaning
                ? 'bg-gradient-to-r from-genesis-accent to-red-600 hover:brightness-110 text-white shadow-glow-accent'
                : isCleaning
                ? 'bg-red-500/20 text-red-400 border border-red-500/40 animate-pulse cursor-wait'
                : 'bg-white/[0.02] text-slate-500 border border-white/[0.06] cursor-not-allowed'
            }`}
          >
            {isCleaning ? (
              <Zap className="w-3.5 h-3.5 animate-spin text-genesis-accent" />
            ) : (
              <Trash2 className="w-3.5 h-3.5" />
            )}
            <span>{isCleaning ? 'Purging Junk...' : 'Clean All'}</span>
          </button>
        </div>
      </div>

      {/* Preview Section */}
      {deepCleanPreview.length === 0 ? (
        <div className="py-6 text-center text-xs text-slate-400 font-mono bg-black/20 rounded-lg border border-white/[0.04] flex flex-col items-center justify-center gap-1.5">
          <CheckCircle2 className="w-4 h-4 text-slate-500" />
          <span>System storage is clean. Click "Scan" to check for temporary logs & memory dumps</span>
        </div>
      ) : (
        <div className="space-y-2">
          <div className="flex items-center justify-between text-xs font-mono px-2 text-slate-300">
            <span className="flex items-center gap-1.5">
              {isCleaning && <span className="w-2 h-2 rounded-full bg-genesis-accent animate-ping" />}
              {isCleaning ? 'Purging in progress...' : 'Found Cleanable Files:'}
            </span>
            <span className="text-genesis-accent font-bold font-mono">
              {totalFiles} files ({totalMb.toFixed(1)} MB)
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 max-h-48 overflow-y-auto pr-1">
            {deepCleanPreview.map((item, idx) => (
              <div
                key={idx}
                className={`p-2.5 rounded border transition-all duration-500 flex items-center justify-between text-xs font-mono relative overflow-hidden ${
                  isCleaning
                    ? 'bg-red-500/10 border-red-500/30 scale-[0.99] opacity-75'
                    : 'bg-white/[0.02] hover:bg-white/[0.04] border-white/[0.06]'
                }`}
              >
                {isCleaning && (
                  <div
                    className="absolute inset-y-0 left-0 bg-genesis-accent/20 transition-all duration-1000"
                    style={{ width: `${((idx + 1) / deepCleanPreview.length) * 100}%` }}
                  />
                )}
                <div className="relative z-10">
                  <div className="font-bold text-slate-200">{item.name}</div>
                  <div className="text-[10px] text-slate-400">{item.description}</div>
                </div>
                <div className="text-right relative z-10">
                  <div className="text-genesis-amber font-bold">{item.size_mb} MB</div>
                  <div className="text-[10px] text-slate-400">{item.file_count} files</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
