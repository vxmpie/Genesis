import React from 'react';
import {
  AlertOctagon,
  AlertTriangle,
  CheckCircle2,
  Info,
  X,
  Zap,
} from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import type { ToastMessage } from '../types/dashboard';

export const ToastContainer: React.FC = () => {
  const toasts = useDashboardStore((s) => s.toasts);
  const removeToast = useDashboardStore((s) => s.removeToast);

  if (toasts.length === 0) return null;

  const getStyle = (type: ToastMessage['type']) => {
    switch (type) {
      case 'boost':
        return {
          border: 'border-l-ops-accent',
          icon: <Zap className="w-4 h-4 text-ops-accent shrink-0" />,
        };
      case 'success':
        return {
          border: 'border-l-ops-ok',
          icon: <CheckCircle2 className="w-4 h-4 text-ops-ok shrink-0" />,
        };
      case 'warning':
        return {
          border: 'border-l-ops-warn',
          icon: <AlertTriangle className="w-4 h-4 text-ops-warn shrink-0" />,
        };
      case 'error':
      case 'crash':
        return {
          border: 'border-l-ops-danger',
          icon: <AlertOctagon className="w-4 h-4 text-ops-danger shrink-0" />,
        };
      default:
        return {
          border: 'border-l-ops-telemetry',
          icon: <Info className="w-4 h-4 text-ops-telemetry shrink-0" />,
        };
    }
  };

  return (
    <div
      aria-live="polite"
      className="fixed top-[calc(env(safe-area-inset-top)+4.25rem)] md:top-[calc(env(safe-area-inset-top)+6.75rem)] inset-x-3 sm:left-auto sm:right-4 sm:w-96 z-50 flex flex-col gap-2 pointer-events-none"
    >
      {toasts.map((toast) => {
        const style = getStyle(toast.type);
        return (
          <div
            key={toast.id}
            className={`pointer-events-auto flex items-start gap-2.5 px-3 py-2.5 rounded-md bg-ops-surface border border-ops-borderStrong border-l-2 ${style.border} shadow-lg text-xs text-ops-text`}
          >
            <div className="pt-0.5">{style.icon}</div>
            <div className="flex-1 leading-snug break-words">{toast.message}</div>
            <button
              type="button"
              onClick={() => removeToast(toast.id)}
              aria-label="Dismiss notification"
              className="text-ops-muted hover:text-ops-text p-0.5 rounded transition-colors shrink-0"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>
        );
      })}
    </div>
  );
};
