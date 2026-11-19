import React, { useEffect, useState } from 'react';
import { KeyRound, Lock, ShieldCheck, X } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import { authenticateSocket } from '../hooks/useWebSocket';
import { loginWithPin } from '../lib/api';

export const AuthModal: React.FC = () => {
  const isOpen = useDashboardStore((s) => s.authModalOpen);
  if (!isOpen) return null;
  return <AuthModalDialog />;
};

const AuthModalDialog: React.FC = () => {
  const closeAuthModal = useDashboardStore((s) => s.closeAuthModal);
  const setAuthModalOpen = useDashboardStore((s) => s.setAuthModalOpen);
  const consumePendingAuthAction = useDashboardStore((s) => s.consumePendingAuthAction);
  const setToken = useDashboardStore((s) => s.setToken);
  const addToast = useDashboardStore((s) => s.addToast);

  const [pin, setPin] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [lockoutSeconds, setLockoutSeconds] = useState(0);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        closeAuthModal();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [closeAuthModal]);

  useEffect(() => {
    if (lockoutSeconds <= 0) return;
    const timer = setInterval(() => {
      setLockoutSeconds((prev) => Math.max(0, prev - 1));
    }, 1000);
    return () => clearInterval(timer);
  }, [lockoutSeconds]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = pin.trim();
    if (!trimmed || loading || lockoutSeconds > 0) return;

    setLoading(true);
    setError('');

    const result = await loginWithPin(trimmed);
    setLoading(false);

    if (result.ok) {
      setToken(result.token);
      authenticateSocket(result.token);
      addToast('success', 'Security session unlocked');
      setPin('');
      setLockoutSeconds(0);
      const pending = consumePendingAuthAction();
      setAuthModalOpen(false);
      if (pending) {
        pending();
      }
      return;
    }

    if (result.status === 429 && result.retryAfterSeconds) {
      setLockoutSeconds(result.retryAfterSeconds);
    }
    setError(result.error);
  };

  const isLockedOut = lockoutSeconds > 0;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-sm"
      role="dialog"
      aria-modal="true"
      aria-labelledby="auth-modal-title"
      onClick={(e) => {
        if (e.target === e.currentTarget) closeAuthModal();
      }}
    >
      <div className="w-full max-w-sm bg-ops-surface border border-ops-borderStrong rounded-lg p-5 shadow-xl relative">
        <button
          type="button"
          onClick={closeAuthModal}
          aria-label="Close authentication modal"
          className="absolute top-3.5 right-3.5 p-1.5 rounded-md text-ops-muted hover:text-ops-text hover:bg-ops-elevated transition-colors"
        >
          <X className="w-4 h-4" />
        </button>

        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-md bg-ops-elevated border border-ops-borderStrong flex items-center justify-center text-ops-warn shrink-0">
            <Lock className="w-5 h-5" />
          </div>
          <div>
            <h2 id="auth-modal-title" className="text-sm font-semibold text-ops-text">
              Unlock Control Session
            </h2>
            <p className="text-xs text-ops-secondary mt-0.5">
              Enter your operator PIN to authorize mutations.
            </p>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="genesis-pin-input" className="sr-only">
              Operator PIN
            </label>
            <input
              id="genesis-pin-input"
              type="password"
              inputMode="numeric"
              maxLength={12}
              value={pin}
              onChange={(e) => setPin(e.target.value)}
              placeholder="Enter PIN"
              autoFocus
              disabled={isLockedOut}
              className="ops-input w-full text-center tracking-[0.3em] text-base font-mono py-2.5 px-4 disabled:opacity-50"
            />
            {isLockedOut ? (
              <p className="num text-xs text-ops-danger mt-2 font-mono">
                Too many failed attempts. Retry in {lockoutSeconds}s.
              </p>
            ) : error ? (
              <p className="text-xs text-ops-danger mt-2 font-mono">{error}</p>
            ) : null}
          </div>

          <div className="flex gap-2">
            <button
              type="button"
              onClick={closeAuthModal}
              className="ops-btn flex-1 h-9 px-3 bg-ops-elevated hover:bg-ops-border text-ops-secondary hover:text-ops-text border border-ops-border text-xs"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading || isLockedOut || !pin.trim()}
              className="ops-btn flex-1 h-9 px-3 bg-ops-accent hover:bg-blue-500 text-white text-xs font-semibold"
            >
              {loading ? (
                <>
                  <KeyRound className="w-3.5 h-3.5 animate-spin" />
                  <span>Verifying...</span>
                </>
              ) : (
                <>
                  <ShieldCheck className="w-3.5 h-3.5" />
                  <span>Unlock</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
