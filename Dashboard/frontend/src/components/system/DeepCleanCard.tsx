import React from 'react';
import { CheckCircle2, Search, Sparkles, Trash2 } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { CardHeader, ConfirmButton, EmptyState, OpsCard, StatusBadge } from '../ui';

interface DeepCleanCardProps {
  onScan: () => void;
  onExecuteClean: () => void;
}

export const DeepCleanCard: React.FC<DeepCleanCardProps> = ({ onScan, onExecuteClean }) => {
  const deepCleanPreview = useDashboardStore((s) => s.deepCleanPreview);
  const isScanningClean = useDashboardStore((s) => s.isScanningClean);
  const isDeepCleaning = useDashboardStore((s) => s.isDeepCleaning);
  const lastResult = useDashboardStore((s) => s.lastDeepCleanResult);
  const pendingOps = useDashboardStore((s) => s.pendingOps);

  const scanning = isScanningClean || Boolean(pendingOps['deepclean:scan']);
  const cleaning = isDeepCleaning || Boolean(pendingOps['deepclean:execute']);

  const totalMb = deepCleanPreview.reduce((acc, item) => acc + item.size_mb, 0);
  const totalFiles = deepCleanPreview.reduce((acc, item) => acc + item.file_count, 0);

  return (
    <OpsCard className="space-y-3">
      <CardHeader
        icon={<Sparkles className="w-4 h-4 text-ops-warn" />}
        title="Deep Clean Engine"
        subtitle="Scan temporary logs, Windows caches, and crash dumps before authorized removal."
        badge={
          deepCleanPreview.length > 0 ? (
            <StatusBadge tone="warn">
              {totalFiles} files ({totalMb.toFixed(1)} MB)
            </StatusBadge>
          ) : undefined
        }
        actions={
          <div className="flex items-center gap-2">
            <button
              type="button"
              disabled={scanning || cleaning}
              onClick={onScan}
              className="ops-btn h-8 px-3 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text"
            >
              <Search className={`w-3.5 h-3.5 ${scanning ? 'animate-spin text-ops-telemetry' : ''}`} />
              <span>{scanning ? 'Scanning...' : 'Scan Targets'}</span>
            </button>

            <ConfirmButton
              tone="danger"
              label="Clean All"
              confirmLabel="Confirm Purge"
              pendingLabel="Purging Junk..."
              icon={<Trash2 className="w-3.5 h-3.5" />}
              pending={cleaning}
              disabled={scanning || deepCleanPreview.length === 0}
              onConfirm={onExecuteClean}
            />
          </div>
        }
      />

      {lastResult && !cleaning && (
        <div className="px-3 py-2 rounded-md bg-ops-ok/10 border border-ops-ok/30 text-xs font-mono text-ops-ok flex flex-wrap items-center justify-between gap-2">
          <span>
            Last clean completed: freed {lastResult.total_freed_mb} MB ({lastResult.total_deleted} files deleted)
          </span>
          {lastResult.details.length > 0 && (
            <span className="text-ops-secondary">
              {lastResult.details.map((d) => `${d.name}: ${d.freed_mb} MB`).join(' | ')}
            </span>
          )}
        </div>
      )}

      {deepCleanPreview.length === 0 ? (
        <EmptyState
          title="No pending cleanup targets queued"
          description='Click "Scan Targets" to inspect Windows temp directories, memory dumps, and MuMu caches.'
          icon={<CheckCircle2 className="w-5 h-5" />}
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5 max-h-64 overflow-y-auto pr-1">
          {deepCleanPreview.map((item) => (
            <div
              key={`${item.category}-${item.name}`}
              className="p-3 rounded-md bg-ops-inset border border-ops-border flex items-start justify-between gap-3"
            >
              <div className="min-w-0 space-y-1">
                <div className="flex flex-wrap items-center gap-1.5">
                  <span className="text-xs font-semibold text-ops-text">{item.name}</span>
                  {item.category && <StatusBadge tone="muted">{item.category}</StatusBadge>}
                  {item.requires_service_stop && (
                    <StatusBadge tone="warn">Stops {item.requires_service_stop}</StatusBadge>
                  )}
                </div>
                <div className="text-[11px] text-ops-secondary">{item.description}</div>
                <div className="text-[10px] font-mono text-ops-muted truncate" title={item.path}>
                  {item.path}
                </div>
              </div>

              <div className="text-right font-mono shrink-0">
                <div className="num text-xs font-semibold text-ops-warn">{item.size_mb} MB</div>
                <div className="num text-[10px] text-ops-muted">{item.file_count} files</div>
              </div>
            </div>
          ))}
        </div>
      )}
    </OpsCard>
  );
};
