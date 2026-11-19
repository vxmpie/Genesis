import React from 'react';
import { OverviewKpiStrip } from './OverviewKpiStrip';
import { PrecisionTelemetryChart } from './PrecisionTelemetryChart';
import { OverviewQuickActions } from './OverviewQuickActions';
import { OverviewInstancesSummary } from './OverviewInstancesSummary';
import { OverviewIncidentsCard } from './OverviewIncidentsCard';

interface OverviewViewProps {
  onBoostNow: () => void;
  onCheckHardening: () => void;
  onFlushDns: () => void;
  onTestAlert: () => void;
}

export const OverviewView: React.FC<OverviewViewProps> = ({
  onBoostNow,
  onCheckHardening,
  onFlushDns,
  onTestAlert,
}) => {
  return (
    <div className="space-y-4">
      <OverviewKpiStrip />

      <div className="grid grid-cols-1 xl:grid-cols-12 gap-4 items-stretch">
        <div className="xl:col-span-7">
          <PrecisionTelemetryChart />
        </div>
        <div className="xl:col-span-5">
          <OverviewQuickActions
            onBoostNow={onBoostNow}
            onCheckHardening={onCheckHardening}
            onFlushDns={onFlushDns}
            onTestAlert={onTestAlert}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-12 gap-4 items-stretch">
        <div className="xl:col-span-6">
          <OverviewInstancesSummary />
        </div>
        <div className="xl:col-span-6">
          <OverviewIncidentsCard />
        </div>
      </div>
    </div>
  );
};
