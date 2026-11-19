import React, { useEffect, useState } from 'react';
import { Activity, Check, Gamepad2, Loader2, Save, User, X } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import { resolveRobloxPlace } from '../lib/api';
import type { MuMuDevice } from '../types/dashboard';
import { OpsSwitch, StatusBadge, type SemanticTone } from './ui';

export interface EditGameModalProps {
  onSave: (
    instance: number,
    updates: { placeId?: number; username?: string; autoRejoin?: boolean }
  ) => void;
}

export const EditGameModal: React.FC<EditGameModalProps> = ({ onSave }) => {
  const isOpen = useDashboardStore((s) => s.editGameModalOpen);
  const close = useDashboardStore((s) => s.closeEditGameModal);
  const device = useDashboardStore((s) => s.editingDevice);

  if (!isOpen || !device) return null;

  return <EditGameModalInner key={device.pid} device={device} onClose={close} onSave={onSave} />;
};

interface EditGameModalInnerProps {
  device: MuMuDevice;
  onClose: () => void;
  onSave: (
    instance: number,
    updates: { placeId?: number; username?: string; autoRejoin?: boolean }
  ) => void;
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

const EditGameModalInner: React.FC<EditGameModalInnerProps> = ({ device, onClose, onSave }) => {
  const mumu = useDashboardStore((s) => s.mumu);
  const config = useDashboardStore((s) => s.config);

  const initialPlaceId =
    device.target_place_id > 0
      ? String(device.target_place_id)
      : device.place_id > 0
      ? String(device.place_id)
      : '';
  const initialUsername = device.username || '';
  const rowSupported = device.auto_rejoin !== undefined;
  const globalRejoin = Boolean(mumu?.auto_rejoin_global ?? true);
  const initialAutoRejoin = device.auto_rejoin ?? true;

  const [placeId, setPlaceId] = useState<string>(initialPlaceId);
  const [username, setUsername] = useState<string>(initialUsername);
  const [autoRejoin, setAutoRejoin] = useState<boolean>(initialAutoRejoin);
  const [resolvedEntry, setResolvedEntry] = useState<{ pid: number; name: string | null } | null>(
    null
  );
  const [resolvingPid, setResolvingPid] = useState<number | null>(null);

  const presets = mumu?.game_presets ?? config?.mumu.game_presets ?? [];

  const trimmedPlace = placeId.trim();
  const parsedPlace = Number(trimmedPlace);
  const validPid =
    trimmedPlace.length > 0 && Number.isInteger(parsedPlace) && parsedPlace > 0
      ? parsedPlace
      : null;

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  useEffect(() => {
    if (validPid === null) return;

    const controller = new AbortController();
    const timer = setTimeout(async () => {
      setResolvingPid(validPid);
      const result = await resolveRobloxPlace(validPid, controller.signal);
      if (!controller.signal.aborted) {
        setResolvedEntry({ pid: validPid, name: result ? result.game_name : null });
        setResolvingPid((prev) => (prev === validPid ? null : prev));
      }
    }, 180);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [validPid]);

  const resolvedName =
    validPid !== null && resolvedEntry?.pid === validPid ? resolvedEntry.name : null;
  const isResolving = validPid !== null && resolvingPid === validPid;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const updates: { placeId?: number; username?: string; autoRejoin?: boolean } = {};

    if (validPid !== null && trimmedPlace !== initialPlaceId) {
      updates.placeId = validPid;
    }

    const trimmedUser = username.trim();
    if (trimmedUser !== initialUsername) {
      updates.username = trimmedUser;
    }

    if (rowSupported && autoRejoin !== initialAutoRejoin) {
      updates.autoRejoin = autoRejoin;
    }

    if (Object.keys(updates).length > 0) {
      onSave(device.index, updates);
    }
    onClose();
  };

  const invalidPlaceInput = trimmedPlace.length > 0 && validPid === null;

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
      <div className="w-full max-w-md bg-ops-surface border border-ops-borderStrong rounded-lg p-5 shadow-xl relative space-y-4">
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
              Instance #{device.index} — Target & Auto-Rejoin
            </h2>
            <p className="text-xs text-ops-secondary mt-0.5">
              Bind a Roblox username for presence tracking, configure Place ID, or toggle Auto-Rejoin.
            </p>
          </div>
        </div>

        {/* Live Presence Readout */}
        <div className="p-2.5 rounded-md bg-ops-inset border border-ops-border flex items-center justify-between gap-2">
          <div className="flex items-center gap-2 text-xs text-ops-secondary">
            <Activity className="w-3.5 h-3.5 text-ops-telemetry shrink-0" />
            <span>Live Status</span>
          </div>
          <StatusBadge tone={getPresenceTone(device.presence_status)} dot>
            {device.presence_status === 'InGame'
              ? `In-Game (${device.active_game || 'Playing'})`
              : device.presence_status === 'Online'
              ? 'In App / Website'
              : device.presence_status || 'Offline'}
          </StatusBadge>
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
              ariaLabel={`Auto-Rejoin Instance #${device.index}`}
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

          {/* Backend Presets */}
          <div>
            <div className="text-[11px] font-mono uppercase tracking-wider text-ops-secondary mb-1.5">
              Configured Presets
            </div>
            {presets.length === 0 ? (
              <div className="p-2.5 rounded-md bg-ops-inset border border-ops-border text-xs text-ops-muted font-mono">
                No game presets configured in backend config.
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-1.5">
                {presets.map((p) => {
                  const idStr = String(p.place_id);
                  const active = placeId.trim() === idStr;
                  return (
                    <button
                      key={p.place_id}
                      type="button"
                      onClick={() => setPlaceId(idStr)}
                      className={`p-2 rounded-md border text-left text-xs font-mono transition-colors ${
                        active
                          ? 'bg-ops-accent/10 border-ops-accent/40 text-ops-text'
                          : 'bg-ops-inset border-ops-border text-ops-secondary hover:border-ops-borderStrong'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-1">
                        <span className="font-sans font-medium truncate">{p.name}</span>
                        {active && <Check className="w-3 h-3 text-ops-accent shrink-0" />}
                      </div>
                      <div className="num text-[10px] text-ops-muted">{idStr}</div>
                    </button>
                  );
                })}
              </div>
            )}
          </div>

          {/* Manual Place ID */}
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
