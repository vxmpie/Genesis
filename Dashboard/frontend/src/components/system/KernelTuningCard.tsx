import React from 'react';
import { Cpu, Layers, Search, Sliders, Timer, Trash2 } from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { CardHeader, ConfirmButton, OpsCard, OpsSwitch, StatusBadge } from '../ui';

interface KernelTuningCardProps {
  onToggleTimerResolution: (enabled: boolean) => void;
  onTogglePcoreAffinity: (enabled: boolean) => void;
  onScanShaderCache: () => void;
  onFlushShaderCache: () => void;
}

export const KernelTuningCard: React.FC<KernelTuningCardProps> = ({
  onToggleTimerResolution,
  onTogglePcoreAffinity,
  onScanShaderCache,
  onFlushShaderCache,
}) => {
  const timerResolution = useDashboardStore((s) => s.timerResolution);
  const pcoreAffinity = useDashboardStore((s) => s.pcoreAffinity);
  const shaderCache = useDashboardStore((s) => s.shaderCache);
  const pendingOps = useDashboardStore((s) => s.pendingOps);

  const timerPending = Boolean(pendingOps['timer']);
  const affinityPending = Boolean(pendingOps['affinity']);
  const shaderScanning = Boolean(pendingOps['shader:scan']);
  const shaderFlushing = Boolean(pendingOps['shader:flush']);

  const shaderOk = shaderCache && shaderCache.success !== false ? shaderCache : null;
  const shaderErr = shaderCache && shaderCache.success === false ? shaderCache.error : null;

  return (
    <OpsCard className="flex flex-col gap-4">
      <div className="space-y-3">
        <CardHeader
          icon={<Sliders className="w-4 h-4 text-ops-telemetry" />}
          title="Kernel & GPU Tuning"
          subtitle="High-resolution NT timer, emulator core affinity binding, and DirectX/GPU shader cache control."
        />

        <div className="space-y-2.5">
          {/* 1. Kernel Timer Resolution */}
          <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-1.5">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2 min-w-0">
                <Timer className="w-4 h-4 text-ops-ok shrink-0" />
                <div className="min-w-0">
                  <div className="text-xs font-medium text-ops-text">
                    High-Precision Kernel Timer (0.5 ms)
                  </div>
                  <div className="num text-[11px] font-mono text-ops-secondary">
                    {timerResolution
                      ? `Current: ${timerResolution.resolution_ms} ms${
                          typeof timerResolution.min_ms === 'number' &&
                          typeof timerResolution.max_ms === 'number'
                            ? ` (Range ${timerResolution.min_ms}–${timerResolution.max_ms} ms)`
                            : ''
                        }`
                      : 'Waiting for timer telemetry...'}
                  </div>
                </div>
              </div>
              <OpsSwitch
                ariaLabel="Toggle 0.5ms Kernel Timer Resolution"
                checked={Boolean(timerResolution?.active)}
                pending={timerPending}
                disabled={!timerResolution}
                tone="ok"
                onChange={onToggleTimerResolution}
              />
            </div>

            {timerResolution?.error && (
              <div className="text-[11px] font-mono text-ops-danger">
                {timerResolution.error}
              </div>
            )}
          </div>

          {/* 2. CPU Core Affinity */}
          <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-1.5">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2 min-w-0">
                <Cpu className="w-4 h-4 text-ops-telemetry shrink-0" />
                <div className="min-w-0">
                  <div className="text-xs font-medium text-ops-text">
                    MuMu Primary Core Affinity Lock
                  </div>
                  <div className="num text-[11px] font-mono text-ops-secondary truncate">
                    {pcoreAffinity
                      ? `${pcoreAffinity.mode} (${pcoreAffinity.p_cores_count}/${pcoreAffinity.total_cores} threads)`
                      : 'Waiting for affinity telemetry...'}
                  </div>
                </div>
              </div>
              <OpsSwitch
                ariaLabel="Toggle Primary Core CPU Affinity"
                checked={Boolean(pcoreAffinity?.enabled)}
                pending={affinityPending}
                disabled={!pcoreAffinity}
                tone="accent"
                onChange={onTogglePcoreAffinity}
              />
            </div>

            {typeof pcoreAffinity?.applied_count === 'number' && (
              <div className="num text-[11px] font-mono text-ops-muted">
                Last applied to {pcoreAffinity.applied_count} emulator process(es).
              </div>
            )}
          </div>

          {/* 3. DirectX / GPU Shader Cache */}
          <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2.5">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="flex items-center gap-2 min-w-0">
                <Layers className="w-4 h-4 text-ops-warn shrink-0" />
                <div>
                  <div className="text-xs font-medium text-ops-text">GPU / DirectX Shader Cache</div>
                  <div className="num text-[11px] font-mono text-ops-secondary">
                    {shaderOk
                      ? `${shaderOk.total_files} files (${shaderOk.total_size_mb} MB)`
                      : shaderErr
                      ? shaderErr
                      : '—'}
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-1.5 shrink-0">
                <button
                  type="button"
                  disabled={shaderScanning || shaderFlushing}
                  onClick={onScanShaderCache}
                  className="ops-btn h-7 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-[11px] text-ops-text"
                >
                  <Search className={`w-3 h-3 ${shaderScanning ? 'animate-spin' : ''}`} />
                  <span>{shaderScanning ? 'Scanning...' : 'Scan'}</span>
                </button>

                <ConfirmButton
                  compact
                  tone="warn"
                  label="Flush Cache"
                  confirmLabel="Confirm Flush"
                  pendingLabel="Flushing..."
                  icon={<Trash2 className="w-3 h-3" />}
                  pending={shaderFlushing}
                  disabled={shaderScanning}
                  title="Delete NVIDIA/AMD/DirectX shader cache files (PIN required)"
                  onConfirm={onFlushShaderCache}
                />
              </div>
            </div>

            {shaderOk && shaderOk.cleaned_files > 0 && (
              <div className="flex items-center justify-between pt-2 border-t border-ops-border text-[11px] font-mono">
                <StatusBadge tone="ok">Flushed</StatusBadge>
                <span className="num text-ops-secondary">
                  Removed {shaderOk.cleaned_files} files ({shaderOk.cleaned_mb} MB)
                </span>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="pt-2 border-t border-ops-border text-[11px] font-mono text-ops-muted">
        All kernel and shader cache changes require an unlocked operator PIN session.
      </div>
    </OpsCard>
  );
};
