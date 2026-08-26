import React, { useState } from 'react';
import { Lock, X } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';

interface AuthModalProps {
  onSuccess?: () => void;
}

export const AuthModal: React.FC<AuthModalProps> = ({ onSuccess }) => {
  const isOpen = useDashboardStore((s) => s.authModalOpen);
  const setOpen = useDashboardStore((s) => s.setAuthModalOpen);
  const setToken = useDashboardStore((s) => s.setToken);
  const setAuthenticated = useDashboardStore((s) => s.setAuthenticated);

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
            <input
              type="password"
              value={pin}
              onChange={(e) => setPin(e.target.value)}
              placeholder="••••"
              autoFocus
              maxLength={12}
              className="w-full px-4 py-2.5 bg-black/50 border border-white/15 rounded-lg text-center text-lg font-mono tracking-widest text-white outline-none focus:border-genesis-accent transition-all"
            />

            {error && <div className="text-xs text-red-400 font-medium">{error}</div>}

            <button
              type="submit"
              disabled={loading || !pin}
              className="w-full py-2.5 rounded-lg font-bold text-xs uppercase tracking-wider bg-gradient-to-r from-red-600 to-genesis-accent hover:opacity-90 text-white shadow-glow-accent transition-all disabled:opacity-50"
            >
              {loading ? 'Verifying...' : 'Unlock Dashboard'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};
