import React from 'react';
import { PrecisionTelemetryChart } from '../overview/PrecisionTelemetryChart';
import { CpuCoresCard } from './CpuCoresCard';
import { DiskGrowthCard } from './DiskGrowthCard';
import { NetworkObservatoryCard } from './NetworkObservatoryCard';
import { EventConsoleCard } from './EventConsoleCard';

export interface TelemetryViewProps {
  onRefreshObservatory: () => void;
  onFlushDns: () => void;
  onRefreshGrowth: () => void;
}

export const TelemetryView: React.FC<TelemetryViewProps> = ({
  onRefreshObservatory,
  onFlushDns,
  onRefreshGrowth,
}) => {
  return (
    <div className="space-y-4">
      <PrecisionTelemetryChart tall />

      <CpuCoresCard />

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-start">
        <div className="lg:col-span-6">
          <NetworkObservatoryCard
            onRefreshObservatory={onRefreshObservatory}
            onFlushDns={onFlushDns}
          />
        </div>
        <div className="lg:col-span-6">
          <DiskGrowthCard onRefreshGrowth={onRefreshGrowth} />
        </div>
      </div>

      <EventConsoleCard />
    </div>
  );
};
