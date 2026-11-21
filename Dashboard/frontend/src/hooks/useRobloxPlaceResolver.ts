import { useEffect, useState } from 'react';
import { resolveRobloxPlace } from '../lib/api';

// --- Place ID Parsing & Debounced Lookup ---
export function parsePositivePlaceId(raw: string): number | null {
  const trimmed = raw.trim();
  if (!/^\d+$/.test(trimmed)) return null;
  const parsed = Number(trimmed);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

export function useRobloxPlaceResolver(validPid: number | null) {
  const [resolvedEntry, setResolvedEntry] = useState<{ pid: number; name: string | null } | null>(
    null
  );
  const [resolvingPid, setResolvingPid] = useState<number | null>(null);

  useEffect(() => {
    if (validPid === null) return;

    const controller = new AbortController();
    const timer = setTimeout(async () => {
      setResolvingPid(validPid);
      const result = await resolveRobloxPlace(validPid, controller.signal);
      if (!controller.signal.aborted) {
        setResolvedEntry({ pid: validPid, name: result ? result.game_name : null });
        setResolvingPid((prev) => (prev === validPid ? null : prev));
      }
    }, 180);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [validPid]);

  const resolvedName =
    validPid !== null && resolvedEntry?.pid === validPid ? resolvedEntry.name : null;
  const isResolving = validPid !== null && resolvingPid === validPid;

  return { resolvedName, isResolving };
}
