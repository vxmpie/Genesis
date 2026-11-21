import React, { useMemo, useState } from 'react';
import {
  BookmarkPlus,
  Check,
  Edit3,
  Loader2,
  Plus,
  Sparkles,
  Trash2,
  X,
} from 'lucide-react';
import { useDashboardStore } from '../../store/useDashboard';
import { parsePositivePlaceId, useRobloxPlaceResolver } from '../../hooks/useRobloxPlaceResolver';
import type { GamePreset } from '../../types/dashboard';
import { CardHeader, ConfirmButton, EmptyState, OpsCard, StatusBadge } from '../ui';

interface GamePresetsCardProps {
  onAddPreset: (placeId: number, name: string) => void;
  onUpdatePreset: (originalPlaceId: number, placeId: number, name: string) => void;
  onDeletePreset: (placeId: number) => void;
}

interface DetectedLiveGame {
  placeId: number;
  name: string;
  instances: number[];
}

export const GamePresetsCard: React.FC<GamePresetsCardProps> = ({
  onAddPreset,
  onUpdatePreset,
  onDeletePreset,
}) => {
  const mumu = useDashboardStore((s) => s.mumu);
  const config = useDashboardStore((s) => s.config);
  const pendingOps = useDashboardStore((s) => s.pendingOps);

  const [showAddForm, setShowAddForm] = useState(false);
  const [addPlaceId, setAddPlaceId] = useState('');
  const [addName, setAddName] = useState('');

  const [editingOriginalPid, setEditingOriginalPid] = useState<number | null>(null);
  const [editPlaceId, setEditPlaceId] = useState('');
  const [editName, setEditName] = useState('');

  const mumuPresets = mumu?.game_presets;
  const configPresets = config?.mumu.game_presets;
  const mumuDevices = mumu?.devices;

  const presets: GamePreset[] = useMemo(
    () => mumuPresets ?? configPresets ?? [],
    [mumuPresets, configPresets]
  );

  const devices = useMemo(() => mumuDevices ?? [], [mumuDevices]);

  const detectedLiveGames: DetectedLiveGame[] = useMemo(() => {
    const presetIds = new Set(presets.map((p) => p.place_id));
    const grouped = new Map<number, DetectedLiveGame>();
    for (const dev of devices) {
      if (dev.presence_status !== 'InGame') continue;
      const pid = dev.active_place_id;
      if (typeof pid !== 'number' || pid <= 0 || presetIds.has(pid)) continue;
      const existing = grouped.get(pid);
      const displayName = (dev.live_game_name || dev.active_game || `Place ${pid}`).trim();
      if (existing) {
        if (!existing.instances.includes(dev.index)) {
          existing.instances.push(dev.index);
        }
      } else {
        grouped.set(pid, {
          placeId: pid,
          name: displayName,
          instances: [dev.index],
        });
      }
    }
    return Array.from(grouped.values());
  }, [devices, presets]);

  const addValidPid = parsePositivePlaceId(addPlaceId);
  const { resolvedName: addResolvedName, isResolving: addResolving } =
    useRobloxPlaceResolver(addValidPid);
  const addInvalid = addPlaceId.trim().length > 0 && addValidPid === null;
  const addDuplicate = addValidPid !== null && presets.some((p) => p.place_id === addValidPid);
  const addPending = Boolean(pendingOps['preset:add']);

  const editValidPid = parsePositivePlaceId(editPlaceId);
  const { resolvedName: editResolvedName, isResolving: editResolving } =
    useRobloxPlaceResolver(editingOriginalPid !== null ? editValidPid : null);
  const editInvalid = editPlaceId.trim().length > 0 && editValidPid === null;
  const editDuplicate =
    editingOriginalPid !== null &&
    editValidPid !== null &&
    editValidPid !== editingOriginalPid &&
    presets.some((p) => p.place_id === editValidPid);

  const startEdit = (preset: GamePreset) => {
    setEditingOriginalPid(preset.place_id);
    setEditPlaceId(String(preset.place_id));
    setEditName(preset.name);
  };

  const cancelEdit = () => {
    setEditingOriginalPid(null);
    setEditPlaceId('');
    setEditName('');
  };

  const handleAddSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (addValidPid === null || addDuplicate) return;
    const resolvedFallback =
      addResolvedName && addResolvedName !== `Place ${addValidPid}` ? addResolvedName : '';
    const finalName = addName.trim() || resolvedFallback;
    onAddPreset(addValidPid, finalName);
    setAddPlaceId('');
    setAddName('');
    setShowAddForm(false);
  };

  const handleEditSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (editingOriginalPid === null || editValidPid === null || editDuplicate) return;
    const finalName = editName.trim();
    onUpdatePreset(editingOriginalPid, editValidPid, finalName);
    cancelEdit();
  };

  return (
    <OpsCard className="space-y-3">
      <CardHeader
        icon={<BookmarkPlus className="w-4 h-4 text-ops-telemetry" />}
        title="Auto-Rejoin Game Presets"
        subtitle="Manage reusable Roblox Place ID presets for instant slot assignment and Auto-Rejoin targets."
        badge={
          <StatusBadge tone={presets.length > 0 ? 'info' : 'muted'}>
            {presets.length} {presets.length === 1 ? 'preset' : 'presets'}
          </StatusBadge>
        }
        actions={
          <button
            type="button"
            onClick={() => setShowAddForm((v) => !v)}
            className="ops-btn h-8 px-2.5 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-text"
          >
            {showAddForm ? <X className="w-3.5 h-3.5" /> : <Plus className="w-3.5 h-3.5 text-ops-accent" />}
            <span>{showAddForm ? 'Close' : 'Add Preset'}</span>
          </button>
        }
      />

      {/* Detected Live Games Quick-Add */}
      {detectedLiveGames.length > 0 && (
        <div className="space-y-1.5">
          {detectedLiveGames.map((item) => {
            const quickPending = Boolean(pendingOps['preset:add']);
            return (
              <div
                key={item.placeId}
                className="px-3 py-2 rounded-md bg-ops-telemetry/10 border border-ops-telemetry/30 flex flex-wrap items-center justify-between gap-2"
              >
                <div className="flex items-center gap-2 min-w-0 text-xs">
                  <Sparkles className="w-3.5 h-3.5 text-ops-telemetry shrink-0" />
                  <span className="text-ops-text font-medium truncate">
                    Detected Live Game: {item.name}
                  </span>
                  <span className="num font-mono text-[11px] text-ops-secondary shrink-0">
                    ID:{item.placeId}
                  </span>
                  <span className="num font-mono text-[10px] text-ops-muted shrink-0">
                    ({item.instances.map((i) => `#${i}`).join(', ')})
                  </span>
                </div>
                <button
                  type="button"
                  disabled={quickPending}
                  onClick={() => onAddPreset(item.placeId, item.name)}
                  className="ops-btn h-7 px-2.5 bg-ops-telemetry/20 hover:bg-ops-telemetry/30 border border-ops-telemetry/40 text-[11px] font-semibold text-ops-text shrink-0"
                >
                  {quickPending ? (
                    <Loader2 className="w-3 h-3 animate-spin" />
                  ) : (
                    <Plus className="w-3 h-3" />
                  )}
                  <span>Save to Presets</span>
                </button>
              </div>
            );
          })}
        </div>
      )}

      {/* Add Preset Form */}
      {showAddForm && (
        <form
          onSubmit={handleAddSubmit}
          className="p-3 rounded-md bg-ops-inset border border-ops-borderStrong space-y-3"
        >
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
            <div>
              <div className="flex items-center justify-between gap-2 mb-1">
                <label
                  htmlFor="add-preset-place-id"
                  className="text-[10px] font-mono uppercase tracking-wider text-ops-secondary"
                >
                  Place ID
                </label>
                <span className="text-[10px] font-mono text-ops-telemetry flex items-center gap-1 truncate max-w-[160px]">
                  {addResolving && <Loader2 className="w-2.5 h-2.5 animate-spin shrink-0" />}
                  {addResolvedName || ''}
                </span>
              </div>
              <input
                id="add-preset-place-id"
                type="text"
                inputMode="numeric"
                value={addPlaceId}
                onChange={(e) => setAddPlaceId(e.target.value)}
                placeholder="e.g. 93898234979111"
                className="ops-input num w-full h-8 px-2.5 text-xs font-mono"
              />
            </div>

            <div>
              <label
                htmlFor="add-preset-name"
                className="block text-[10px] font-mono uppercase tracking-wider text-ops-secondary mb-1"
              >
                Preset Name (Optional)
              </label>
              <input
                id="add-preset-name"
                type="text"
                maxLength={100}
                value={addName}
                onChange={(e) => setAddName(e.target.value)}
                placeholder={addResolvedName || 'Auto-detect from Roblox if empty'}
                className="ops-input w-full h-8 px-2.5 text-xs"
              />
            </div>
          </div>

          {(addInvalid || addDuplicate) && (
            <p className="text-[11px] font-mono text-ops-danger">
              {addInvalid
                ? 'Place ID must be a positive integer.'
                : 'This Place ID is already saved in presets.'}
            </p>
          )}

          <div className="flex items-center justify-end gap-2">
            <button
              type="button"
              onClick={() => {
                setShowAddForm(false);
                setAddPlaceId('');
                setAddName('');
              }}
              className="ops-btn h-8 px-3 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-secondary"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={addValidPid === null || addDuplicate || addPending}
              className="ops-btn h-8 px-3 bg-ops-accent hover:bg-blue-500 text-white text-xs font-semibold"
            >
              {addPending ? (
                <Loader2 className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <Check className="w-3.5 h-3.5" />
              )}
              <span>Save Preset</span>
            </button>
          </div>
        </form>
      )}

      {/* Presets Grid */}
      {presets.length === 0 ? (
        <EmptyState
          title="No Auto-Rejoin game presets saved"
          description="Add a Roblox Place ID above or save a live detected game to manage presets from the dashboard."
          icon={<BookmarkPlus className="w-5 h-5" />}
        />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2.5">
          {presets.map((preset) => {
            const isEditing = editingOriginalPid === preset.place_id;
            const editPending = Boolean(pendingOps[`preset:edit:${preset.place_id}`]);
            const deletePending = Boolean(pendingOps[`preset:delete:${preset.place_id}`]);
            const activeSlots = devices.filter(
              (d) => (d.configured_place_id || d.target_place_id) === preset.place_id
            );

            if (isEditing) {
              return (
                <form
                  key={preset.place_id}
                  onSubmit={handleEditSubmit}
                  className="p-3 rounded-md bg-ops-elevated border border-ops-accent/50 space-y-2.5"
                >
                  <div>
                    <label
                      htmlFor={`edit-preset-name-${preset.place_id}`}
                      className="block text-[10px] font-mono uppercase text-ops-secondary mb-1"
                    >
                      Game Name
                    </label>
                    <input
                      id={`edit-preset-name-${preset.place_id}`}
                      type="text"
                      maxLength={100}
                      value={editName}
                      onChange={(e) => setEditName(e.target.value)}
                      placeholder="Leave empty to auto-resolve"
                      className="ops-input w-full h-8 px-2.5 text-xs"
                    />
                  </div>

                  <div>
                    <div className="flex items-center justify-between gap-2 mb-1">
                      <label
                        htmlFor={`edit-preset-pid-${preset.place_id}`}
                        className="text-[10px] font-mono uppercase text-ops-secondary"
                      >
                        Place ID
                      </label>
                      {editResolving ? (
                        <Loader2 className="w-3 h-3 animate-spin text-ops-telemetry" />
                      ) : (
                        editResolvedName &&
                        editResolvedName !== editName.trim() && (
                          <button
                            type="button"
                            onClick={() => setEditName(editResolvedName)}
                            className="text-[10px] font-mono text-ops-telemetry hover:underline truncate max-w-[150px]"
                            title={`Fill name: ${editResolvedName}`}
                          >
                            Use {editResolvedName}
                          </button>
                        )
                      )}
                    </div>
                    <input
                      id={`edit-preset-pid-${preset.place_id}`}
                      type="text"
                      inputMode="numeric"
                      value={editPlaceId}
                      onChange={(e) => setEditPlaceId(e.target.value)}
                      className="ops-input num w-full h-8 px-2.5 text-xs font-mono"
                    />
                  </div>

                  {(editInvalid || editDuplicate) && (
                    <p className="text-[10px] font-mono text-ops-danger">
                      {editInvalid
                        ? 'Place ID must be a positive integer.'
                        : 'Another preset already uses this Place ID.'}
                    </p>
                  )}

                  <div className="flex items-center justify-end gap-1.5 pt-1">
                    <button
                      type="button"
                      onClick={cancelEdit}
                      className="ops-btn h-7 px-2.5 bg-ops-inset hover:bg-ops-border border border-ops-border text-[11px] text-ops-secondary"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      disabled={editValidPid === null || editDuplicate || editPending}
                      className="ops-btn h-7 px-2.5 bg-ops-accent hover:bg-blue-500 text-white text-[11px] font-semibold"
                    >
                      {editPending ? (
                        <Loader2 className="w-3 h-3 animate-spin" />
                      ) : (
                        <Check className="w-3 h-3" />
                      )}
                      <span>Save</span>
                    </button>
                  </div>
                </form>
              );
            }

            return (
              <div
                key={preset.place_id}
                className="p-3 rounded-md bg-ops-inset border border-ops-border flex flex-col justify-between gap-2.5"
              >
                <div className="min-w-0 space-y-1">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-xs font-semibold text-ops-text truncate" title={preset.name}>
                      {preset.name}
                    </span>
                    {activeSlots.length > 0 && (
                      <StatusBadge tone="ok">{activeSlots.length} active</StatusBadge>
                    )}
                  </div>
                  <div className="num text-[11px] font-mono text-ops-muted">
                    ID: {preset.place_id}
                  </div>
                </div>

                <div className="flex items-center justify-end gap-1.5 pt-2 border-t border-ops-border">
                  <button
                    type="button"
                    onClick={() => startEdit(preset)}
                    title={`Edit preset ${preset.name}`}
                    className="ops-btn h-7 px-2 bg-ops-elevated hover:bg-ops-border border border-ops-border text-[11px] text-ops-text"
                  >
                    <Edit3 className="w-3 h-3 text-ops-telemetry" />
                    <span>Edit</span>
                  </button>

                  <ConfirmButton
                    compact
                    tone="danger"
                    label="Delete"
                    confirmLabel="Confirm"
                    pendingLabel="Deleting..."
                    icon={<Trash2 className="w-3 h-3" />}
                    pending={deletePending}
                    title={`Delete preset ${preset.name}`}
                    onConfirm={() => onDeletePreset(preset.place_id)}
                  />
                </div>
              </div>
            );
          })}
        </div>
      )}
    </OpsCard>
  );
};
