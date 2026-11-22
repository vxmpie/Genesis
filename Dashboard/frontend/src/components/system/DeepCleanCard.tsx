import React, { useState } from 'react';
import {
  CheckCircle2,
  FolderPlus,
  HardDrive,
  Plus,
  Search,
  Sparkles,
  Trash2,
  X,
} from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import type { AutoCleanConfigUpdatePayload, DeepCleanSource } from '../../types/dashboard';
import {
  CardHeader,
  ConfirmButton,
  EmptyState,
  OpsCard,
  OpsSwitch,
  StatusBadge,
} from '../ui';

interface DeepCleanCardProps {
  onScan: () => void;
  onExecuteClean: () => void;
  onCompactVdi: () => void;
  onUpdateConfig: (updates: AutoCleanConfigUpdatePayload) => void;
  onAddCustomTarget: (payload: {
    name: string;
    category?: string;
    path: string;
    max_age_days?: number | null;
  }) => void;
  onRemoveCustomTarget: (name: string) => void;
}

const SOURCE_META: Record<DeepCleanSource, { label: string; tone: 'muted' | 'info' | 'accent' }> = {
  builtin: { label: 'Built-in', tone: 'muted' },
  discovered: { label: 'Auto-Discovered', tone: 'info' },
  custom: { label: 'Custom', tone: 'accent' },
};

const HOUR_OPTIONS = Array.from({ length: 24 }, (_, idx) => idx);

export const DeepCleanCard: React.FC<DeepCleanCardProps> = ({
  onScan,
  onExecuteClean,
  onCompactVdi,
  onUpdateConfig,
  onAddCustomTarget,
  onRemoveCustomTarget,
}) => {
  const deepCleanPreview = useDashboardStore((s) => s.deepCleanPreview);
  const autoCleanStatus = useDashboardStore((s) => s.autoCleanStatus);
  const isScanningClean = useDashboardStore((s) => s.isScanningClean);
  const isDeepCleaning = useDashboardStore((s) => s.isDeepCleaning);
  const isCompactingVdi = useDashboardStore((s) => s.isCompactingVdi);
  const lastResult = useDashboardStore((s) => s.lastDeepCleanResult);
  const lastVdiResult = useDashboardStore((s) => s.lastVdiCompactResult);
  const pendingOps = useDashboardStore((s) => s.pendingOps);

  const [addFormOpen, setAddFormOpen] = useState(false);
  const [targetName, setTargetName] = useState('');
  const [targetPath, setTargetPath] = useState('');
  const [targetMaxAge, setTargetMaxAge] = useState('');
  const [targetCategory, setTargetCategory] = useState('Custom');
  const [formError, setFormError] = useState('');

  const [thresholdInput, setThresholdInput] = useState<string | null>(null);
  const [cooldownInput, setCooldownInput] = useState<string | null>(null);

  const scanning = isScanningClean || Boolean(pendingOps['deepclean:scan']);
  const cleaning = isDeepCleaning || Boolean(pendingOps['deepclean:execute']) || Boolean(autoCleanStatus?.is_cleaning);
  const compacting =
    isCompactingVdi || Boolean(pendingOps['deepclean:compact_vdi']) || Boolean(autoCleanStatus?.is_compacting_vdi);
  const configPending = Boolean(pendingOps['deepclean:config']);
  const addingTarget = Boolean(pendingOps['deepclean:add_target']);

  const autoEnabled = autoCleanStatus?.auto_deep_clean_enabled ?? true;
  const cleanHour = autoCleanStatus?.auto_deep_clean_hour ?? 4;
  const thresholdMb = autoCleanStatus?.auto_deep_clean_threshold_mb ?? 500;
  const cooldownHours = autoCleanStatus?.auto_deep_clean_cooldown_hours ?? 6;
  const discoveryEnabled = autoCleanStatus?.auto_discovery_enabled ?? true;
  const vdiAutoCompact = autoCleanStatus?.vdi_auto_compact_enabled ?? true;
  const disabledTargets = autoCleanStatus?.disabled_clean_targets ?? [];
  const customTargets = autoCleanStatus?.custom_clean_targets ?? [];
  const discoveryExcludes = autoCleanStatus?.auto_discovery_excludes ?? [];

  const disabledLowerSet = new Set(disabledTargets.map((t) => t.toLowerCase()));

  const enabledPreviewItems = deepCleanPreview.filter(
    (item) => item.enabled !== false && !disabledLowerSet.has(item.name.toLowerCase())
  );
  const totalMb = enabledPreviewItems.reduce((acc, item) => acc + item.size_mb, 0);
  const totalFiles = enabledPreviewItems.reduce((acc, item) => acc + item.file_count, 0);

  const handleToggleTargetEnabled = (name: string, currentlyEnabled: boolean) => {
    const nextDisabled = currentlyEnabled
      ? Array.from(new Set([...disabledTargets, name]))
      : disabledTargets.filter((t) => t.toLowerCase() !== name.toLowerCase());
    onUpdateConfig({ disabled_clean_targets: nextDisabled });
  };

  const handleExcludeDiscovered = (pathOrName: string) => {
    if (discoveryExcludes.some((x) => x.toLowerCase() === pathOrName.toLowerCase())) {
      return;
    }
    onUpdateConfig({ auto_discovery_excludes: [...discoveryExcludes, pathOrName] });
  };

  const handleRemoveExclude = (item: string) => {
    onUpdateConfig({
      auto_discovery_excludes: discoveryExcludes.filter((x) => x !== item),
    });
  };

  const handleAddTargetSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');
    const name = targetName.trim();
    const path = targetPath.trim();
    if (!name || !path) {
      setFormError('Target name and path are required.');
      return;
    }
    const parsedAge = targetMaxAge.trim() ? Number(targetMaxAge.trim()) : null;
    if (parsedAge !== null && (!Number.isFinite(parsedAge) || parsedAge < 1)) {
      setFormError('Max Age Days must be at least 1.');
      return;
    }
    onAddCustomTarget({
      name,
      path,
      category: targetCategory.trim() || 'Custom',
      max_age_days: parsedAge !== null ? Math.round(parsedAge) : null,
    });
    setTargetName('');
    setTargetPath('');
    setTargetMaxAge('');
    setAddFormOpen(false);
  };

  const commitThreshold = () => {
    if (thresholdInput === null) return;
    const parsed = Number(thresholdInput);
    setThresholdInput(null);
    if (!Number.isFinite(parsed)) return;
    const clamped = Math.max(100, Math.min(100000, Math.round(parsed)));
    if (clamped !== thresholdMb) {
      onUpdateConfig({ auto_deep_clean_threshold_mb: clamped });
    }
  };

  const commitCooldown = () => {
    if (cooldownInput === null) return;
    const parsed = Number(cooldownInput);
    setCooldownInput(null);
    if (!Number.isFinite(parsed)) return;
    const clamped = Math.max(1, Math.min(168, Math.round(parsed)));
    if (clamped !== cooldownHours) {
      onUpdateConfig({ auto_deep_clean_cooldown_hours: clamped });
    }
  };

  return (
    <OpsCard className="space-y-3">
      <CardHeader
        icon={<Sparkles className="w-4 h-4 text-ops-warn" />}
        title="Deep Clean & Offline VDI Engine"
        subtitle="Hybrid scheduled/threshold cache cleaner, dynamic auto-discovery, custom targets, and offline MuMu VDI compaction."
        badge={
          <div className="flex items-center gap-1.5 flex-wrap">
            <StatusBadge tone={autoEnabled ? 'ok' : 'muted'} dot>
              {autoEnabled ? `Auto ${String(cleanHour).padStart(2, '0')}:00` : 'Auto Off'}
            </StatusBadge>
            {deepCleanPreview.length > 0 && (
              <StatusBadge tone="warn">
                {totalFiles} files ({totalMb.toFixed(1)} MB)
              </StatusBadge>
            )}
          </div>
        }
        actions={
          <div className="flex items-center gap-2 flex-wrap">
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
              tone="accent"
              label="Compact Stopped VMs"
              confirmLabel="Compact VDI"
              pendingLabel="Compacting VDI..."
              icon={<HardDrive className="w-3.5 h-3.5" />}
              pending={compacting}
              disabled={cleaning}
              title="Compact data.vdi for all stopped MuMu instances (running instances are skipped)"
              onConfirm={onCompactVdi}
            />

            <ConfirmButton
              tone="danger"
              label="Clean All"
              confirmLabel="Confirm Purge"
              pendingLabel="Purging Junk..."
              icon={<Trash2 className="w-3.5 h-3.5" />}
              pending={cleaning}
              disabled={scanning || enabledPreviewItems.length === 0}
              onConfirm={onExecuteClean}
            />
          </div>
        }
      />

      {/* Auto Deep Clean Controls */}
      <div className="p-3 rounded-md bg-ops-inset border border-ops-border space-y-2.5 text-xs">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-4">
            <label className="inline-flex items-center gap-2 cursor-pointer">
              <OpsSwitch
                ariaLabel="Toggle Auto Deep Clean"
                checked={autoEnabled}
                pending={configPending}
                tone="ok"
                onChange={(next) => onUpdateConfig({ auto_deep_clean_enabled: next })}
              />
              <span className="font-medium text-ops-text">Auto Deep Clean</span>
            </label>

            <label className="inline-flex items-center gap-2 cursor-pointer">
              <OpsSwitch
                ariaLabel="Toggle Auto-Discovery"
                checked={discoveryEnabled}
                pending={configPending}
                onChange={(next) => onUpdateConfig({ auto_discovery_enabled: next })}
              />
              <span className="text-ops-secondary">Auto-Discovery</span>
            </label>

            <label className="inline-flex items-center gap-2 cursor-pointer">
              <OpsSwitch
                ariaLabel="Toggle Auto VDI Compact"
                checked={vdiAutoCompact}
                pending={configPending}
                onChange={(next) => onUpdateConfig({ vdi_auto_compact_enabled: next })}
              />
              <span className="text-ops-secondary">Auto VDI Compact</span>
            </label>
          </div>

          <button
            type="button"
            onClick={() => {
              setFormError('');
              setAddFormOpen((v) => !v);
            }}
            className="ops-btn h-7 px-2.5 bg-ops-surface hover:bg-ops-elevated border border-ops-border text-[11px] text-ops-text"
          >
            <FolderPlus className="w-3.5 h-3.5 text-ops-accent" />
            <span>{addFormOpen ? 'Close Form' : 'Add Custom Target'}</span>
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 pt-2 border-t border-ops-border">
          <div className="flex items-center justify-between gap-2 px-2.5 py-1.5 rounded bg-ops-surface border border-ops-border">
            <label htmlFor="auto-clean-hour-select" className="text-[11px] text-ops-secondary">
              Daily Hour
            </label>
            <select
              id="auto-clean-hour-select"
              disabled={configPending}
              value={cleanHour}
              onChange={(e) => onUpdateConfig({ auto_deep_clean_hour: Number(e.target.value) })}
              className="ops-input num h-7 px-2 text-xs font-mono"
            >
              {HOUR_OPTIONS.map((h) => (
                <option key={h} value={h}>
                  {String(h).padStart(2, '0')}:00
                </option>
              ))}
            </select>
          </div>

          <div className="flex items-center justify-between gap-2 px-2.5 py-1.5 rounded bg-ops-surface border border-ops-border">
            <label htmlFor="auto-clean-threshold-input" className="text-[11px] text-ops-secondary">
              Threshold (MB)
            </label>
            <input
              id="auto-clean-threshold-input"
              type="number"
              min={100}
              max={100000}
              disabled={configPending}
              value={thresholdInput ?? String(thresholdMb)}
              onChange={(e) => setThresholdInput(e.target.value)}
              onBlur={commitThreshold}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  commitThreshold();
                }
              }}
              className="ops-input num w-20 h-7 px-2 text-xs font-mono text-right"
            />
          </div>

          <div className="flex items-center justify-between gap-2 px-2.5 py-1.5 rounded bg-ops-surface border border-ops-border">
            <label htmlFor="auto-clean-cooldown-input" className="text-[11px] text-ops-secondary">
              Cooldown (h)
            </label>
            <input
              id="auto-clean-cooldown-input"
              type="number"
              min={1}
              max={168}
              disabled={configPending}
              value={cooldownInput ?? String(cooldownHours)}
              onChange={(e) => setCooldownInput(e.target.value)}
              onBlur={commitCooldown}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  commitCooldown();
                }
              }}
              className="ops-input num w-16 h-7 px-2 text-xs font-mono text-right"
            />
          </div>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-2 text-[11px] font-mono text-ops-muted pt-1">
          <span>
            Last Auto Run:{' '}
            <span className="text-ops-secondary">
              {autoCleanStatus?.last_auto_clean_at
                ? `${autoCleanStatus.last_auto_clean_at} (${autoCleanStatus.last_auto_clean_freed_mb} MB, ${autoCleanStatus.last_trigger ?? 'auto'})`
                : 'Never'}
            </span>
          </span>
          <span>
            Next Scheduled:{' '}
            <span className="text-ops-secondary">
              {autoCleanStatus?.next_scheduled_run || 'Disabled'}
            </span>
          </span>
        </div>
      </div>

      {/* Add Custom Target Mini-Form */}
      {addFormOpen && (
        <form
          onSubmit={handleAddTargetSubmit}
          className="p-3 rounded-md bg-ops-inset border border-ops-accent/40 space-y-2.5 text-xs"
        >
          <div className="text-[11px] font-mono uppercase tracking-wider text-ops-accent">
            Register Custom Cache Target
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-12 gap-2">
            <input
              type="text"
              placeholder="Target Name (e.g. MyApp Cache)"
              value={targetName}
              onChange={(e) => setTargetName(e.target.value)}
              className="ops-input sm:col-span-3 h-8 px-2.5 text-xs"
            />
            <input
              type="text"
              placeholder="Absolute Path (e.g. %LOCALAPPDATA%\MyApp\Cache)"
              value={targetPath}
              onChange={(e) => setTargetPath(e.target.value)}
              className="ops-input sm:col-span-5 h-8 px-2.5 text-xs font-mono"
            />
            <input
              type="text"
              placeholder="Category"
              value={targetCategory}
              onChange={(e) => setTargetCategory(e.target.value)}
              className="ops-input sm:col-span-2 h-8 px-2.5 text-xs"
            />
            <input
              type="number"
              min={1}
              max={3650}
              placeholder="Max Age (d)"
              value={targetMaxAge}
              onChange={(e) => setTargetMaxAge(e.target.value)}
              className="ops-input num sm:col-span-2 h-8 px-2.5 text-xs font-mono"
            />
          </div>
          {formError && <div className="text-[11px] text-ops-danger">{formError}</div>}
          <div className="flex items-center justify-end gap-2">
            <button
              type="button"
              onClick={() => setAddFormOpen(false)}
              className="ops-btn h-7 px-2.5 bg-ops-elevated border border-ops-border text-[11px] text-ops-secondary"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={addingTarget}
              className="ops-btn h-7 px-3 bg-ops-accent hover:bg-blue-500 text-white text-[11px] font-semibold"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>{addingTarget ? 'Saving...' : 'Save Target'}</span>
            </button>
          </div>
        </form>
      )}

      {/* Configured Custom Targets & Discovery Excludes Summary */}
      {(customTargets.length > 0 || discoveryExcludes.length > 0) && (
        <div className="flex flex-wrap items-center gap-1.5 text-[11px]">
          {customTargets.map((ct) => (
            <span
              key={ct.name}
              title={ct.path}
              className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded bg-ops-accent/10 border border-ops-accent/30 text-ops-accent font-mono"
            >
              <span>Custom: {ct.name}</span>
              <button
                type="button"
                onClick={() => onRemoveCustomTarget(ct.name)}
                aria-label={`Remove custom target ${ct.name}`}
                className="hover:text-ops-danger"
              >
                <X className="w-3 h-3" />
              </button>
            </span>
          ))}
          {discoveryExcludes.map((exc) => (
            <span
              key={exc}
              className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded bg-ops-inset border border-ops-border text-ops-muted font-mono"
            >
              <span>Excluded: {exc}</span>
              <button
                type="button"
                onClick={() => handleRemoveExclude(exc)}
                aria-label={`Remove exclude ${exc}`}
                className="hover:text-ops-text"
              >
                <X className="w-3 h-3" />
              </button>
            </span>
          ))}
        </div>
      )}

      {/* Last Deep Clean Result */}
      {lastResult && !cleaning && (
        <div className="px-3 py-2 rounded-md bg-ops-ok/10 border border-ops-ok/30 text-xs font-mono text-ops-ok flex flex-wrap items-center justify-between gap-2">
          <span>
            Last clean ({lastResult.trigger || 'manual'}): freed {lastResult.total_freed_mb} MB (
            {lastResult.total_deleted} files deleted)
          </span>
          {lastResult.details.length > 0 && (
            <span className="text-ops-secondary">
              {lastResult.details
                .filter((d) => d.freed_mb > 0 || d.deleted > 0)
                .map((d) => `${d.name}: ${d.freed_mb} MB`)
                .join(' | ')}
            </span>
          )}
        </div>
      )}

      {/* Last VDI Compact Result */}
      {lastVdiResult && !compacting && (
        <div
          className={`p-2.5 rounded-md border text-xs space-y-1.5 ${
            lastVdiResult.ok
              ? 'bg-ops-telemetry/10 border-ops-telemetry/30'
              : 'bg-ops-warn/10 border-ops-warn/30'
          }`}
        >
          <div className="flex flex-wrap items-center justify-between gap-2 font-mono">
            <span className="font-semibold text-ops-text">
              VDI Compact ({lastVdiResult.trigger || 'manual'}): freed {lastVdiResult.total_freed_mb} MB
            </span>
            <span className="text-[11px] text-ops-secondary">
              {lastVdiResult.compacted_count} compacted | {lastVdiResult.skipped_count} running skipped
              {lastVdiResult.timestamp ? ` | ${lastVdiResult.timestamp}` : ''}
            </span>
          </div>
          {lastVdiResult.vms.length > 0 ? (
            <div className="flex flex-wrap gap-1.5">
              {lastVdiResult.vms.map((vm) => (
                <StatusBadge
                  key={vm.vm_name}
                  tone={
                    vm.status === 'compacted'
                      ? 'ok'
                      : vm.status === 'skipped_running'
                      ? 'warn'
                      : 'danger'
                  }
                  title={vm.error || `${vm.before_mb} MB -> ${vm.after_mb} MB`}
                >
                  {vm.vm_name}:{' '}
                  {vm.status === 'compacted'
                    ? `${vm.before_mb} -> ${vm.after_mb} MB (-${vm.freed_mb} MB)`
                    : vm.status === 'skipped_running'
                    ? `Running - Skipped (${vm.before_mb} MB)`
                    : `Error`}
                </StatusBadge>
              ))}
            </div>
          ) : (
            lastVdiResult.error && (
              <div className="text-[11px] font-mono text-ops-warn">{lastVdiResult.error}</div>
            )
          )}
        </div>
      )}

      {/* Target Cards */}
      {deepCleanPreview.length === 0 ? (
        <EmptyState
          title="No pending cleanup targets queued"
          description='Click "Scan Targets" to inspect Windows temp directories, updaters, auto-discovered app caches, and custom targets.'
          icon={<CheckCircle2 className="w-5 h-5" />}
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5 max-h-72 overflow-y-auto pr-1">
          {deepCleanPreview.map((item) => {
            const source: DeepCleanSource = item.source ?? 'builtin';
            const sourceMeta = SOURCE_META[source] ?? SOURCE_META.builtin;
            const isEnabled =
              item.enabled !== false && !disabledLowerSet.has(item.name.toLowerCase());

            return (
              <div
                key={`${source}-${item.name}-${item.path}`}
                className={`p-3 rounded-md bg-ops-inset border border-ops-border flex items-start justify-between gap-3 ${
                  isEnabled ? '' : 'opacity-60'
                }`}
              >
                <div className="min-w-0 space-y-1 flex-1">
                  <div className="flex flex-wrap items-center gap-1.5">
                    <span className="text-xs font-semibold text-ops-text">{item.name}</span>
                    <StatusBadge tone={sourceMeta.tone}>{sourceMeta.label}</StatusBadge>
                    {item.category && <StatusBadge tone="muted">{item.category}</StatusBadge>}
                    {item.max_age_days && (
                      <StatusBadge tone="info">&gt;{item.max_age_days}d old</StatusBadge>
                    )}
                    {item.requires_service_stop && (
                      <StatusBadge tone="warn">Stops {item.requires_service_stop}</StatusBadge>
                    )}
                  </div>
                  <div className="text-[11px] text-ops-secondary">{item.description}</div>
                  <div className="text-[10px] font-mono text-ops-muted truncate" title={item.path}>
                    {item.path}
                  </div>
                </div>

                <div className="flex flex-col items-end gap-1.5 shrink-0">
                  <div className="text-right font-mono">
                    <div className="num text-xs font-semibold text-ops-warn">{item.size_mb} MB</div>
                    <div className="num text-[10px] text-ops-muted">{item.file_count} files</div>
                  </div>
                  <div className="flex items-center gap-1.5">
                    {source === 'discovered' && (
                      <button
                        type="button"
                        onClick={() => handleExcludeDiscovered(item.path)}
                        className="ops-btn h-6 px-1.5 bg-ops-surface hover:bg-ops-elevated border border-ops-border text-[10px] text-ops-secondary"
                        title="Exclude from Auto-Discovery"
                      >
                        Exclude
                      </button>
                    )}
                    {source === 'custom' && (
                      <button
                        type="button"
                        onClick={() => onRemoveCustomTarget(item.name)}
                        className="ops-btn h-6 px-1.5 bg-ops-danger/10 hover:bg-ops-danger/20 border border-ops-danger/30 text-[10px] text-ops-danger"
                        title="Remove custom target"
                      >
                        Remove
                      </button>
                    )}
                    <OpsSwitch
                      ariaLabel={`Toggle ${item.name}`}
                      checked={isEnabled}
                      onChange={() => handleToggleTargetEnabled(item.name, isEnabled)}
                    />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </OpsCard>
  );
};
