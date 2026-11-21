import React, { useEffect, useState } from 'react';
import {
  Activity,
  Check,
  Edit3,
  Gamepad2,
  Loader2,
  Plus,
  Save,
  Trash2,
  User,
  X,
} from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import { parsePositivePlaceId, useRobloxPlaceResolver } from '../hooks/useRobloxPlaceResolver';
import type { GamePreset, MuMuDevice } from '../types/dashboard';
import { OpsSwitch, StatusBadge, type SemanticTone } from './ui';

export interface GameTargetUpdates {
  placeId?: number;
  username?: string;
  autoRejoin?: boolean;
  saveAsPreset?: boolean;
  presetName?: string;
}

export interface EditGameModalProps {
  onSave: (instance: number, updates: GameTargetUpdates) => void;
  onAddPreset: (placeId: number, name: string) => void;
  onUpdatePreset: (originalPlaceId: number, placeId: number, name: string) => void;
  onDeletePreset: (placeId: number) => void;
}

export const EditGameModal: React.FC<EditGameModalProps> = ({
  onSave,
  onAddPreset,
  onUpdatePreset,
  onDeletePreset,
}) => {
  const isOpen = useDashboardStore((s) => s.editGameModalOpen);
  const close = useDashboardStore((s) => s.closeEditGameModal);
  const device = useDashboardStore((s) => s.editingDevice);

  if (!isOpen || !device) return null;

  return (
    <EditGameModalInner
      key={device.pid}
      device={device}
      onClose={close}
      onSave={onSave}
      onAddPreset={onAddPreset}
      onUpdatePreset={onUpdatePreset}
      onDeletePreset={onDeletePreset}
    />
  );
};

interface EditGameModalInnerProps {
  device: MuMuDevice;
  onClose: () => void;
  onSave: (instance: number, updates: GameTargetUpdates) => void;
  onAddPreset: (placeId: number, name: string) => void;
  onUpdatePreset: (originalPlaceId: number, placeId: number, name: string) => void;
  onDeletePreset: (placeId: number) => void;
}

function getPresenceTone(status: string): SemanticTone {
  switch (status) {
    case 'InGame':
      return 'ok';
    case 'Online':
      return 'info';
    case 'InStudio':
      return 'accent';
    default:
      return 'muted';
  }
}

const EditGameModalInner: React.FC<EditGameModalInnerProps> = ({
  device,
  onClose,
  onSave,
  onAddPreset,
  onUpdatePreset,
  onDeletePreset,
}) => {
  const mumu = useDashboardStore((s) => s.mumu);
  const config = useDashboardStore((s) => s.config);
  const liveDevice = useDashboardStore(
    (s) => s.mumu?.devices.find((d) => d.pid === device.pid || d.index === device.index) ?? device
  );

  const savedPlaceId =
    mumu?.instance_places?.[String(liveDevice.index)] ?? liveDevice.configured_place_id ?? 0;

  const initialPlaceId =
    savedPlaceId > 0
      ? String(savedPlaceId)
      : liveDevice.active_place_id && liveDevice.active_place_id > 0
      ? String(liveDevice.active_place_id)
      : '';
  const initialUsername = liveDevice.username || '';
  const rowSupported = liveDevice.auto_rejoin !== undefined;
  const globalRejoin = Boolean(mumu?.auto_rejoin_global ?? true);
  const initialAutoRejoin = liveDevice.auto_rejoin ?? true;

  const [placeId, setPlaceId] = useState<string>(initialPlaceId);
  const [username, setUsername] = useState<string>(initialUsername);
  const [autoRejoin, setAutoRejoin] = useState<boolean>(initialAutoRejoin);
  const [saveAsPreset, setSaveAsPreset] = useState<boolean>(true);
  const [customPresetName, setCustomPresetName] = useState<string>('');

  const [showQuickAdd, setShowQuickAdd] = useState<boolean>(false);
  const [quickAddPid, setQuickAddPid] = useState<string>('');
  const [quickAddName, setQuickAddName] = useState<string>('');

  const [editingPresetPid, setEditingPresetPid] = useState<number | null>(null);
  const [editPresetPid, setEditPresetPid] = useState<string>('');
  const [editPresetName, setEditPresetName] = useState<string>('');
  const [confirmDeletePid, setConfirmDeletePid] = useState<number | null>(null);

  const presets = mumu?.game_presets ?? config?.mumu.game_presets ?? [];

  const trimmedPlace = placeId.trim();
  const validPid = parsePositivePlaceId(placeId);
  const { resolvedName, isResolving } = useRobloxPlaceResolver(validPid);

  const quickAddValidPid = parsePositivePlaceId(quickAddPid);
  const { resolvedName: quickAddResolved, isResolving: quickAddResolving } =
    useRobloxPlaceResolver(showQuickAdd ? quickAddValidPid : null);
  const quickAddDuplicate =
    quickAddValidPid !== null && presets.some((p) => p.place_id === quickAddValidPid);

  const editPresetValidPid = parsePositivePlaceId(editPresetPid);
  const editPresetDuplicate =
    editingPresetPid !== null &&
    editPresetValidPid !== null &&
    editPresetValidPid !== editingPresetPid &&
    presets.some((p) => p.place_id === editPresetValidPid);

  const isNewPreset = validPid !== null && !presets.some((p) => p.place_id === validPid);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const liveSuggestedName =
    validPid !== null && liveDevice.active_place_id === validPid
      ? (liveDevice.live_game_name || liveDevice.active_game || '').trim()
      : '';
  const presetNameSuggestion =
    liveSuggestedName ||
    (resolvedName && validPid !== null && resolvedName !== `Place ${validPid}` ? resolvedName : '');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const updates: GameTargetUpdates = {};

    const clearingSavedPlace = trimmedPlace === '' && savedPlaceId > 0;
    const shouldSavePreset = isNewPreset && saveAsPreset;

    if (validPid !== null && (validPid !== savedPlaceId || shouldSavePreset)) {
      updates.placeId = validPid;
      if (shouldSavePreset) {
        updates.saveAsPreset = true;
        const derivedName = customPresetName.trim() || presetNameSuggestion;
        if (derivedName) {
          updates.presetName = derivedName;
        }
      }
    } else if (clearingSavedPlace) {
      updates.placeId = 0;
    }

    const trimmedUser = username.trim();
    if (trimmedUser !== initialUsername) {
      updates.username = trimmedUser;
    }

    if (rowSupported && autoRejoin !== initialAutoRejoin) {
      updates.autoRejoin = autoRejoin;
    }

    if (Object.keys(updates).length > 0) {
      onSave(liveDevice.index, updates);
    }
    onClose();
  };

  const handleQuickAddSave = () => {
    if (quickAddValidPid === null || quickAddDuplicate) return;
    const fallback =
      quickAddResolved && quickAddResolved !== `Place ${quickAddValidPid}` ? quickAddResolved : '';
    onAddPreset(quickAddValidPid, quickAddName.trim() || fallback);
    setPlaceId(String(quickAddValidPid));
    setQuickAddPid('');
    setQuickAddName('');
    setShowQuickAdd(false);
  };

  const startPresetEdit = (preset: GamePreset) => {
    setConfirmDeletePid(null);
    setShowQuickAdd(false);
    setEditingPresetPid(preset.place_id);
    setEditPresetPid(String(preset.place_id));
    setEditPresetName(preset.name);
  };

  const handlePresetEditSave = () => {
    if (editingPresetPid === null || editPresetValidPid === null || editPresetDuplicate) return;
    onUpdatePreset(editingPresetPid, editPresetValidPid, editPresetName.trim());
    if (placeId.trim() === String(editingPresetPid)) {
      setPlaceId(String(editPresetValidPid));
    }
    setEditingPresetPid(null);
  };

  const invalidPlaceInput = trimmedPlace.length > 0 && validPid === null;
  const hasLiveGame =
    liveDevice.presence_status === 'InGame' &&
    typeof liveDevice.active_place_id === 'number' &&
    liveDevice.active_place_id > 0;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-sm"
      role="dialog"
      aria-modal="true"
      aria-labelledby="edit-game-modal-title"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="w-full max-w-md max-h-[90vh] overflow-y-auto bg-ops-surface border border-ops-borderStrong rounded-lg p-5 shadow-xl relative space-y-4">
        <button
          type="button"
          onClick={onClose}
          aria-label="Close instance configuration modal"
          className="absolute top-3.5 right-3.5 p-1.5 rounded-md text-ops-muted hover:text-ops-text hover:bg-ops-elevated transition-colors"
        >
          <X className="w-4 h-4" />
        </button>

        <div className="flex items-start gap-2.5 pr-6">
          <div className="w-9 h-9 rounded-md bg-ops-elevated border border-ops-borderStrong flex items-center justify-center text-ops-telemetry shrink-0">
            <Gamepad2 className="w-4 h-4" />
          </div>
          <div>
            <h2 id="edit-game-modal-title" className="text-sm font-semibold text-ops-text">
              Instance #{liveDevice.index} — Target & Auto-Rejoin
            </h2>
            <p className="text-xs text-ops-secondary mt-0.5">
              Bind a Roblox username for presence tracking, configure Place ID, or manage presets.
            </p>
          </div>
        </div>

        {/* Live Presence Readout */}
        <div className="p-2.5 rounded-md bg-ops-inset border border-ops-border space-y-1.5">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2 text-xs text-ops-secondary">
              <Activity className="w-3.5 h-3.5 text-ops-telemetry shrink-0" />
              <span>Live Status</span>
            </div>
            <StatusBadge tone={getPresenceTone(liveDevice.presence_status)} dot>
              {liveDevice.presence_status === 'InGame'
                ? `In-Game (${liveDevice.live_game_name || liveDevice.active_game || 'Playing'})`
                : liveDevice.presence_status === 'Online'
                ? 'In App / Website'
                : liveDevice.presence_status || 'Offline'}
            </StatusBadge>
          </div>

          {hasLiveGame && (
            <div className="flex items-center justify-between gap-2 text-[11px] font-mono pt-1 border-t border-ops-border/60">
              <span className="num text-ops-muted">Live ID: {liveDevice.active_place_id}</span>
              {placeId.trim() !== String(liveDevice.active_place_id) && (
                <button
                  type="button"
                  onClick={() => setPlaceId(String(liveDevice.active_place_id))}
                  className="text-ops-telemetry hover:underline font-medium"
                >
                  Use Live ID
                </button>
              )}
            </div>
          )}
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Per-Instance Auto-Rejoin */}
          <div className="p-3 rounded-md bg-ops-inset border border-ops-border flex items-center justify-between gap-3">
            <div className="min-w-0">
              <div className="text-xs font-medium text-ops-text">Auto-Rejoin Target Map</div>
              <div className="text-[11px] text-ops-muted">
                {!rowSupported
                  ? 'Restart elevated server to enable per-instance toggle.'
                  : !globalRejoin
                  ? 'Master switch Auto-Rejoin (All) is currently off.'
                  : autoRejoin
                  ? 'Watchdog & heartbeat keep Roblox attached to target map.'
                  : 'Paused for this slot. Stored Place ID & username stay saved.'}
              </div>
            </div>
            <OpsSwitch
              ariaLabel={`Auto-Rejoin Instance #${liveDevice.index}`}
              checked={autoRejoin && globalRejoin}
              disabled={!rowSupported || !globalRejoin}
              tone="ok"
              onChange={setAutoRejoin}
            />
          </div>

          {/* Roblox Username Binding */}
          <div>
            <label
              htmlFor="edit-game-username"
              className="text-[11px] font-mono uppercase tracking-wider text-ops-secondary flex items-center gap-1.5 mb-1.5"
            >
              <User className="w-3 h-3 text-ops-telemetry" />
              <span>Roblox Username (Optional)</span>
            </label>
            <input
              id="edit-game-username"
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="Leave empty to clear username binding"
              className="ops-input w-full h-9 px-3 text-xs font-mono"
            />
          </div>

          {/* Backend Presets with Inline CRUD */}
          <div className="space-y-2">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[11px] font-mono uppercase tracking-wider text-ops-secondary">
                Configured Presets
              </span>
              <button
                type="button"
                onClick={() => {
                  setEditingPresetPid(null);
                  setConfirmDeletePid(null);
                  setShowQuickAdd((v) => !v);
                }}
                className="inline-flex items-center gap-1 text-[11px] font-mono text-ops-telemetry hover:text-ops-text"
              >
                {showQuickAdd ? <X className="w-3 h-3" /> : <Plus className="w-3 h-3" />}
                <span>{showQuickAdd ? 'Close' : 'Add'}</span>
              </button>
            </div>

            {showQuickAdd && (
              <div className="p-2.5 rounded-md bg-ops-inset border border-ops-borderStrong space-y-2">
                <div className="grid grid-cols-2 gap-2">
                  <input
                    type="text"
                    inputMode="numeric"
                    value={quickAddPid}
                    onChange={(e) => setQuickAddPid(e.target.value)}
                    placeholder="Place ID"
                    className="ops-input num h-8 px-2 text-xs font-mono"
                  />
                  <input
                    type="text"
                    maxLength={100}
                    value={quickAddName}
                    onChange={(e) => setQuickAddName(e.target.value)}
                    placeholder={
                      quickAddResolving
                        ? 'Resolving...'
                        : quickAddResolved || 'Game name (optional)'
                    }
                    className="ops-input h-8 px-2 text-xs"
                  />
                </div>
                {quickAddDuplicate && (
                  <p className="text-[10px] font-mono text-ops-danger">
                    Preset already exists for this Place ID.
                  </p>
                )}
                <div className="flex justify-end gap-1.5">
                  <button
                    type="button"
                    onClick={() => setShowQuickAdd(false)}
                    className="ops-btn h-7 px-2 bg-ops-elevated border border-ops-border text-[11px] text-ops-secondary"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    disabled={quickAddValidPid === null || quickAddDuplicate}
                    onClick={handleQuickAddSave}
                    className="ops-btn h-7 px-2.5 bg-ops-accent hover:bg-blue-500 text-white text-[11px] font-semibold"
                  >
                    <Check className="w-3 h-3" />
                    <span>Save Preset</span>
                  </button>
                </div>
              </div>
            )}

            {editingPresetPid !== null && (
              <div className="p-2.5 rounded-md bg-ops-elevated border border-ops-accent/50 space-y-2">
                <div className="text-[10px] font-mono uppercase text-ops-secondary">
                  Edit Preset (ID: {editingPresetPid})
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <input
                    type="text"
                    maxLength={100}
                    value={editPresetName}
                    onChange={(e) => setEditPresetName(e.target.value)}
                    placeholder="Game name"
                    className="ops-input h-8 px-2 text-xs"
                  />
                  <input
                    type="text"
                    inputMode="numeric"
                    value={editPresetPid}
                    onChange={(e) => setEditPresetPid(e.target.value)}
                    placeholder="Place ID"
                    className="ops-input num h-8 px-2 text-xs font-mono"
                  />
                </div>
                {editPresetDuplicate && (
                  <p className="text-[10px] font-mono text-ops-danger">
                    Another preset already uses this Place ID.
                  </p>
                )}
                <div className="flex justify-end gap-1.5">
                  <button
                    type="button"
                    onClick={() => setEditingPresetPid(null)}
                    className="ops-btn h-7 px-2 bg-ops-inset border border-ops-border text-[11px] text-ops-secondary"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    disabled={editPresetValidPid === null || editPresetDuplicate}
                    onClick={handlePresetEditSave}
                    className="ops-btn h-7 px-2.5 bg-ops-accent hover:bg-blue-500 text-white text-[11px] font-semibold"
                  >
                    <Check className="w-3 h-3" />
                    <span>Update</span>
                  </button>
                </div>
              </div>
            )}

            {presets.length === 0 ? (
              <div className="p-2.5 rounded-md bg-ops-inset border border-ops-border text-xs text-ops-muted font-mono">
                No game presets configured. Add one above or save a Place ID below.
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-1.5">
                {presets.map((p) => {
                  const idStr = String(p.place_id);
                  const active = placeId.trim() === idStr;
                  const confirmingDelete = confirmDeletePid === p.place_id;

                  return (
                    <div
                      key={p.place_id}
                      className={`p-2 rounded-md border text-xs font-mono transition-colors flex items-start justify-between gap-1 ${
                        active
                          ? 'bg-ops-accent/10 border-ops-accent/40 text-ops-text'
                          : 'bg-ops-inset border-ops-border text-ops-secondary hover:border-ops-borderStrong'
                      }`}
                    >
                      <button
                        type="button"
                        onClick={() => {
                          setPlaceId(idStr);
                          setConfirmDeletePid(null);
                        }}
                        className="min-w-0 flex-1 text-left"
                      >
                        <div className="flex items-center gap-1 min-w-0">
                          <span className="font-sans font-medium truncate">{p.name}</span>
                          {active && <Check className="w-3 h-3 text-ops-accent shrink-0" />}
                        </div>
                        <div className="num text-[10px] text-ops-muted">{idStr}</div>
                      </button>

                      <div className="flex items-center gap-0.5 shrink-0">
                        {confirmingDelete ? (
                          <>
                            <button
                              type="button"
                              onClick={() => {
                                onDeletePreset(p.place_id);
                                setConfirmDeletePid(null);
                              }}
                              className="px-1.5 py-0.5 rounded bg-ops-danger text-white text-[10px] font-semibold"
                              title="Confirm delete preset"
                            >
                              Del
                            </button>
                            <button
                              type="button"
                              onClick={() => setConfirmDeletePid(null)}
                              className="p-0.5 rounded text-ops-muted hover:text-ops-text"
                              aria-label="Cancel delete preset"
                            >
                              <X className="w-3 h-3" />
                            </button>
                          </>
                        ) : (
                          <>
                            <button
                              type="button"
                              onClick={() => startPresetEdit(p)}
                              aria-label={`Edit preset ${p.name}`}
                              title={`Edit ${p.name}`}
                              className="p-1 rounded text-ops-muted hover:text-ops-telemetry hover:bg-ops-elevated"
                            >
                              <Edit3 className="w-3 h-3" />
                            </button>
                            <button
                              type="button"
                              onClick={() => setConfirmDeletePid(p.place_id)}
                              aria-label={`Delete preset ${p.name}`}
                              title={`Delete ${p.name}`}
                              className="p-1 rounded text-ops-muted hover:text-ops-danger hover:bg-ops-elevated"
                            >
                              <Trash2 className="w-3 h-3" />
                            </button>
                          </>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* Manual Place ID */}
          <div className="space-y-2">
            <div>
              <div className="flex items-center justify-between gap-2 mb-1.5">
                <label
                  htmlFor="edit-game-place-id"
                  className="text-[11px] font-mono uppercase tracking-wider text-ops-secondary"
                >
                  Target Place ID
                </label>
                <span className="text-[11px] font-mono text-ops-telemetry flex items-center gap-1 truncate max-w-[200px]">
                  {isResolving && <Loader2 className="w-3 h-3 animate-spin shrink-0" />}
                  {resolvedName || (placeId.trim() ? '—' : 'Unassigned')}
                </span>
              </div>
              <input
                id="edit-game-place-id"
                type="text"
                inputMode="numeric"
                value={placeId}
                onChange={(e) => setPlaceId(e.target.value)}
                placeholder="Enter numeric Roblox Place ID"
                className="ops-input num w-full h-9 px-3 text-xs font-mono"
              />
              {invalidPlaceInput && (
                <p className="text-[11px] text-ops-danger font-mono mt-1">
                  Place ID must be a positive integer.
                </p>
              )}
            </div>

            {isNewPreset && (
              <div className="p-2.5 rounded-md bg-ops-inset border border-ops-border space-y-2">
                <label className="flex items-center gap-2 text-xs text-ops-text cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={saveAsPreset}
                    onChange={(e) => setSaveAsPreset(e.target.checked)}
                    className="rounded border-ops-borderStrong bg-ops-surface text-ops-accent"
                  />
                  <span>Also save to Game Presets</span>
                </label>
                {saveAsPreset && (
                  <input
                    type="text"
                    maxLength={100}
                    value={customPresetName}
                    onChange={(e) => setCustomPresetName(e.target.value)}
                    placeholder={
                      presetNameSuggestion
                        ? `Preset name (default: ${presetNameSuggestion})`
                        : `Preset name (auto-resolve for ${validPid})`
                    }
                    className="ops-input w-full h-8 px-2.5 text-xs"
                  />
                )}
              </div>
            )}
          </div>

          <div className="flex items-center justify-end gap-2 pt-2 border-t border-ops-border">
            <button
              type="button"
              onClick={onClose}
              className="ops-btn h-9 px-3 bg-ops-elevated hover:bg-ops-border border border-ops-border text-xs text-ops-secondary"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={invalidPlaceInput}
              className="ops-btn h-9 px-4 bg-ops-accent hover:bg-blue-500 text-white text-xs font-semibold"
            >
              <Save className="w-3.5 h-3.5" />
              <span>Save & Apply</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
