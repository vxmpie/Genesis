import React from 'react';
import { TopBar } from './TopBar';
import { MobileBottomNav } from './MobileBottomNav';

interface AppShellProps {
  children: React.ReactNode;
}

export const AppShell: React.FC<AppShellProps> = ({ children }) => {
  return (
    <div className="min-h-screen bg-ops-bg text-ops-text flex flex-col font-sans">
      <TopBar />
      <main className="flex-1 w-full max-w-[1440px] mx-auto px-3 sm:px-5 lg:px-6 py-4 sm:py-5 pb-24 md:pb-8">
        {children}
      </main>
      <MobileBottomNav />
    </div>
  );
};
