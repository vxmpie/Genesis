import React, { useState, useEffect } from 'react';
import { Gamepad2, X, Check } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface EditGameModalProps {
  onSave: (instance: number, placeId: number) => void;
}

export const EditGameModal: React.FC<EditGameModalProps> = ({ onSave }) => {
  const isOpen = useDashboardStore((s) => s.editGameModalOpen);
  const close = useDashboardStore((s) => s.closeEditGameModal);
  const device = useDashboardStore((s) => s.editingDevice);

  const [placeId, setPlaceId] = useState<string>('');

  const presets = [
    { name: 'Storage Hunters', placeId: '98800969324557' },
    { name: 'Gym League', placeId: '17450551531' },
    { name: 'Anime Defenders', placeId: '17017769292' },
    { name: 'Blox Fruits', placeId: '2753915549' },
  ];

  useEffect(() => {
    if (device) {
      setPlaceId(String(device.place_id || '98800969324557'));
    }
  }, [device]);

  if (!isOpen || !device) return null;

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    const pidNum = parseInt(placeId.trim());
    if (isNaN(pidNum) || pidNum <= 0) return;
    onSave(device.index, pidNum);
    close();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-fadeIn">
      <div className="w-full max-w-md bg-genesis-card border border-white/10 rounded-xl p-5 shadow-2xl relative">
        <button
          onClick={close}
          className="absolute top-4 right-4 text-slate-400 hover:text-white p-1"
        >
          <X className="w-4 h-4" />
        </button>

        <div className="flex items-center gap-2 mb-3">
          <Gamepad2 className="w-5 h-5 text-genesis-cyan" />
          <h2 className="text-sm font-extrabold text-white">
            Set Target Game — Instance #{device.index}
          </h2>
        </div>
        <p className="text-xs text-slate-400 mb-4">
          Configure the Roblox Place ID that watchdog will automatically reconnect into.
        </p>

        {/* Preset Buttons */}
        <div className="mb-4">
          <label className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">
            Quick Presets
          </label>
          <div className="grid grid-cols-2 gap-1.5">
            {presets.map((p) => (
              <button
                key={p.placeId}
                type="button"
                onClick={() => setPlaceId(p.placeId)}
                className={`p-2 rounded border text-left text-xs font-mono transition-all ${
                  placeId === p.placeId
                    ? 'bg-genesis-cyan/15 border-genesis-cyan/40 text-genesis-cyan font-bold'
                    : 'bg-white/[0.03] border-white/[0.06] text-slate-300 hover:bg-white/[0.06]'
                }`}
              >
                <div>{p.name}</div>
                <div className="text-[10px] text-slate-500">{p.placeId}</div>
              </button>
            ))}
          </div>
        </div>

        {/* Form */}
        <form onSubmit={handleSave} className="space-y-4">
          <div>
            <label className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">
              Custom Roblox Place ID
            </label>
            <input
              type="text"
              value={placeId}
              onChange={(e) => setPlaceId(e.target.value)}
              placeholder="e.g. 98800969324557"
              className="w-full px-3 py-2 bg-black/50 border border-white/15 rounded-lg text-xs font-mono text-white outline-none focus:border-genesis-cyan"
            />
          </div>

          <div className="flex items-center justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={close}
              className="px-3 py-1.5 rounded-lg text-xs text-slate-400 hover:text-white bg-white/[0.04]"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-1.5 rounded-lg text-xs font-bold text-black bg-genesis-cyan hover:opacity-90 shadow-glow-cyan flex items-center gap-1.5"
            >
              <Check className="w-3.5 h-3.5" />
              Save Target
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
