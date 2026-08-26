import React from 'react';
import { Sparkles, Trash2, Search } from 'lucide-react';
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
    <div className="cyber-card p-4">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
        <span className="flex items-center gap-2 text-xs font-bold text-white uppercase tracking-wider">
          <Sparkles className="w-4 h-4 text-genesis-amber" />
          Deep Clean Engine
        </span>
        <div className="flex items-center gap-2">
          <button
            onClick={onScan}
            disabled={isScanning}
            className="px-3 py-1 text-xs font-medium text-slate-300 bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 rounded-md transition-all flex items-center gap-1.5"
          >
            <Search className={`w-3.5 h-3.5 ${isScanning ? 'animate-spin text-genesis-cyan' : ''}`} />
            <span>{isScanning ? 'Scanning...' : 'Scan'}</span>
          </button>
          <button
            onClick={onExecuteClean}
            disabled={isCleaning || deepCleanPreview.length === 0}
            className={`px-3 py-1 text-xs font-bold rounded-md transition-all flex items-center gap-1.5 ${
              deepCleanPreview.length > 0 && !isCleaning
                ? 'bg-genesis-accent hover:opacity-90 text-white shadow-glow-accent'
                : 'bg-white/[0.02] text-slate-500 border border-white/[0.06] cursor-not-allowed'
            }`}
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>{isCleaning ? 'Cleaning...' : 'Clean All'}</span>
          </button>
        </div>
      </div>

      {/* Preview Section */}
      {deepCleanPreview.length === 0 ? (
        <div className="py-6 text-center text-xs text-slate-500 font-mono bg-black/20 rounded-lg border border-white/[0.04]">
          Click "Scan" to preview cleanable system junk & crash dumps
        </div>
      ) : (
        <div className="space-y-2">
          <div className="flex items-center justify-between text-xs font-mono px-2 text-slate-300">
            <span>Found Cleanable Files:</span>
            <span className="text-genesis-accent font-bold">
              {totalFiles} files ({totalMb.toFixed(1)} MB)
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 max-h-48 overflow-y-auto pr-1">
            {deepCleanPreview.map((item, idx) => (
              <div
                key={idx}
                className="p-2.5 rounded bg-white/[0.02] border border-white/[0.06] flex items-center justify-between text-xs font-mono"
              >
                <div>
                  <div className="font-bold text-slate-200">{item.name}</div>
                  <div className="text-[10px] text-slate-500">{item.description}</div>
                </div>
                <div className="text-right">
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
