"use client";

import { useEffect, useState } from "react";
import { getRawStorage, setRawStorage, removeStorage } from "@/lib/storage";

const KEY = "mp_flash_end";
const DURATION_MS = (2 * 3600 + 41 * 60 + 17) * 1000;

function pad(n) {
  return String(n).padStart(2, "0");
}

/** Countdown persisted in localStorage so it survives reloads within its window. */
export function useCountdown() {
  const [time, setTime] = useState({ h: "02", m: "41", s: "17" });

  useEffect(() => {
    let end = Number(getRawStorage(KEY, "0"));
    if (!end || end < Date.now()) {
      end = Date.now() + DURATION_MS;
      setRawStorage(KEY, String(end));
    }

    function tick() {
      const diff = Math.max(0, end - Date.now());
      const hh = Math.floor(diff / 3600000);
      const mm = Math.floor((diff % 3600000) / 60000);
      const ss = Math.floor((diff % 60000) / 1000);
      setTime({ h: pad(hh), m: pad(mm), s: pad(ss) });
      if (diff <= 0) {
        removeStorage(KEY);
        clearInterval(interval);
      }
    }

    tick();
    const interval = setInterval(tick, 1000);
    return () => clearInterval(interval);
  }, []);

  return time;
}
