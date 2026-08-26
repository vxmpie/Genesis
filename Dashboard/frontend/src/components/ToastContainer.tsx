import React from 'react';
import { Zap, AlertTriangle, AlertOctagon, Info, X } from 'lucide-react';
import { useDashboardStore } from '../store/useDashboard';
import type { ToastMessage } from '../types/dashboard';

export const ToastContainer: React.FC = () => {
  const toasts = useDashboardStore((s) => s.toasts);
  const removeToast = useDashboardStore((s) => s.removeToast);

  const getToastIcon = (type: ToastMessage['type']) => {
    switch (type) {
      case 'boost':
        return <Zap className="w-4 h-4 text-genesis-accent shrink-0" />;
      case 'warning':
        return <AlertTriangle className="w-4 h-4 text-genesis-amber shrink-0" />;
      case 'error':
      case 'crash':
        return <AlertOctagon className="w-4 h-4 text-red-500 shrink-0" />;
      default:
        return <Info className="w-4 h-4 text-genesis-cyan shrink-0" />;
    }
  };

  return (
    <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm w-full pointer-events-none px-2 sm:px-0">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className="pointer-events-auto flex items-start gap-2.5 p-3 rounded-lg bg-[#141522] border border-white/10 shadow-2xl backdrop-blur-xl text-xs text-slate-100 animate-slideInRight"
        >
          {getToastIcon(toast.type)}
          <div className="flex-1 leading-snug">{toast.message}</div>
          <button
            onClick={() => removeToast(toast.id)}
            className="text-slate-400 hover:text-white p-0.5"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      ))}
    </div>
  );
};
