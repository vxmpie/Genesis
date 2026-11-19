import React from 'react';
import { AutoBoostCard } from './AutoBoostCard';
import { KernelTuningCard } from './KernelTuningCard';
import { HardeningCard } from './HardeningCard';
import { DefenderCard } from './DefenderCard';
import { DeepCleanCard } from './DeepCleanCard';
import { TopProcsCard } from './TopProcsCard';

export interface SystemViewProps {
  onToggleAutoBoost: (enabled: boolean) => void;
  onSetThreshold: (threshold: number) => void;
  onSetMode: (mode: 'auto' | 'scheduled') => void;
  onSetInterval: (minutes: number) => void;
  onBoostNow: () => void;
  onResetSessionBoosts: () => void;
  onResetTotalBoosts: () => void;
  onToggleTimerResolution: (enabled: boolean) => void;
  onTogglePcoreAffinity: (enabled: boolean) => void;
  onScanShaderCache: () => void;
  onFlushShaderCache: () => void;
  onRefreshHardening: () => void;
  onScanDeepClean: () => void;
  onExecuteDeepClean: () => void;
  onRefreshDefender: () => void;
  onQuickScanDefender: () => void;
  onTrimProcess: (pid: number) => void;
  onKillProcess: (pid: number) => void;
}

export const SystemView: React.FC<SystemViewProps> = ({
  onToggleAutoBoost,
  onSetThreshold,
  onSetMode,
  onSetInterval,
  onBoostNow,
  onResetSessionBoosts,
  onResetTotalBoosts,
  onToggleTimerResolution,
  onTogglePcoreAffinity,
  onScanShaderCache,
  onFlushShaderCache,
  onRefreshHardening,
  onScanDeepClean,
  onExecuteDeepClean,
  onRefreshDefender,
  onQuickScanDefender,
  onTrimProcess,
  onKillProcess,
}) => {
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 items-start">
        <div className="space-y-4">
          <AutoBoostCard
            onToggle={onToggleAutoBoost}
            onSetThreshold={onSetThreshold}
            onSetMode={onSetMode}
            onSetInterval={onSetInterval}
            onBoostNow={onBoostNow}
            onResetSessionBoosts={onResetSessionBoosts}
            onResetTotalBoosts={onResetTotalBoosts}
          />
          <HardeningCard onRefresh={onRefreshHardening} />
        </div>

        <div className="space-y-4">
          <KernelTuningCard
            onToggleTimerResolution={onToggleTimerResolution}
            onTogglePcoreAffinity={onTogglePcoreAffinity}
            onScanShaderCache={onScanShaderCache}
            onFlushShaderCache={onFlushShaderCache}
          />
          <DefenderCard
            onRefresh={onRefreshDefender}
            onQuickScan={onQuickScanDefender}
          />
        </div>
      </div>

      <DeepCleanCard
        onScan={onScanDeepClean}
        onExecuteClean={onExecuteDeepClean}
      />

      <TopProcsCard
        onTrimProcess={onTrimProcess}
        onKillProcess={onKillProcess}
      />
    </div>
  );
};
