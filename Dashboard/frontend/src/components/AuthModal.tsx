import React, { useState } from 'react';
import { Lock, X } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import { useWebSocket } from '../hooks/useWebSocket';

interface AuthModalProps {
  onSuccess?: () => void;
}

export const AuthModal: React.FC<AuthModalProps> = ({ onSuccess }) => {
  const isOpen = useDashboardStore((s) => s.authModalOpen);
  const setOpen = useDashboardStore((s) => s.setAuthModalOpen);
  const setToken = useDashboardStore((s) => s.setToken);
  const setAuthenticated = useDashboardStore((s) => s.setAuthenticated);
  const addToast = useDashboardStore((s) => s.addToast);

  const { sendCommand } = useWebSocket();

  const [pin, setPin] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!pin.trim()) return;

    setLoading(true);
    setError('');

    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pin: pin.trim() }),
      });

      const data = await res.json();

      if (res.ok && data.token) {
        setToken(data.token);
        setAuthenticated(true);
        sendCommand('auth', { token: data.token });
        addToast('system', 'Security Core Unlocked (PIN 8666 Verified)');
        setOpen(false);
        setPin('');
        if (onSuccess) onSuccess();
      } else {
        setError(data.error || 'Invalid PIN code. Please try again.');
      }
    } catch (err) {
      setError('Connection error. Could not verify PIN.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-fadeIn">
      <div className="w-full max-w-sm bg-genesis-card border border-white/10 rounded-xl p-6 shadow-2xl relative">
        <button
          onClick={() => setOpen(false)}
          className="absolute top-4 right-4 text-slate-400 hover:text-white p-1"
        >
          <X className="w-4 h-4" />
        </button>

        <div className="flex flex-col items-center text-center">
          <div className="w-12 h-12 rounded-xl bg-genesis-accent/15 border border-genesis-accent/30 flex items-center justify-center text-genesis-accent mb-3 shadow-glow-accent">
            <Lock className="w-6 h-6" />
          </div>
          <h2 className="text-base font-extrabold text-white">Security Authentication</h2>
          <p className="text-xs text-slate-400 mt-1">Enter your Genesis PIN to unlock control permissions</p>

          <form onSubmit={handleSubmit} className="w-full mt-5 space-y-4">
            <div>
              <input
                type="password"
                maxLength={8}
                value={pin}
                onChange={(e) => setPin(e.target.value)}
                placeholder="••••"
                autoFocus
                className="w-full text-center tracking-widest text-lg font-mono py-2.5 px-4 bg-black/40 border border-white/10 rounded-lg text-white placeholder:text-slate-600 focus:outline-none focus:border-genesis-accent focus:ring-1 focus:ring-genesis-accent"
              />
              {error && <p className="text-xs text-red-400 mt-2 font-mono">{error}</p>}
            </div>

            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => setOpen(false)}
                className="flex-1 py-2 rounded-lg bg-white/[0.04] hover:bg-white/[0.08] text-slate-300 text-xs font-semibold border border-white/10 transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={loading}
                className="flex-1 py-2 rounded-lg bg-gradient-to-r from-genesis-accent to-red-600 hover:brightness-110 text-white text-xs font-bold shadow-glow-accent transition-all disabled:opacity-50"
              >
                {loading ? 'Verifying...' : 'Unlock'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};
