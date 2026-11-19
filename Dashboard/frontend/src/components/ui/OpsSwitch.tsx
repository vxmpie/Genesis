import React from 'react';
import { Loader2 } from 'lucide-react';

interface OpsSwitchProps {
  checked: boolean;
  onChange: (nextChecked: boolean) => void;
  disabled?: boolean;
  pending?: boolean;
  ariaLabel: string;
  tone?: 'accent' | 'ok';
  title?: string;
}

export const OpsSwitch: React.FC<OpsSwitchProps> = ({
  checked,
  onChange,
  disabled = false,
  pending = false,
  ariaLabel,
  tone = 'accent',
  title,
}) => {
  const activeBg = tone === 'ok' ? 'bg-ops-ok' : 'bg-ops-accent';
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={ariaLabel}
      disabled={disabled || pending}
      title={title}
      onClick={() => onChange(!checked)}
      className={`relative w-9 h-5 rounded-full p-0.5 transition-colors shrink-0 focus:outline-none focus:ring-1 focus:ring-ops-accent/50 disabled:opacity-45 disabled:cursor-not-allowed ${
        checked ? activeBg : 'bg-ops-borderStrong'
      }`}
    >
      <span
        className={`flex items-center justify-center w-4 h-4 rounded-full bg-white transition-transform ${
          checked ? 'translate-x-4' : 'translate-x-0'
        }`}
      >
        {pending && <Loader2 className="w-2.5 h-2.5 animate-spin text-ops-bg" />}
      </span>
    </button>
  );
};
