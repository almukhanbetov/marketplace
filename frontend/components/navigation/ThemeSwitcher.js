"use client";

import { useTheme } from "@/context/ThemeContext";

export default function ThemeSwitcher() {
  const { theme, toggle } = useTheme();
  const isVivid = theme === "vivid";

  return (
    <button
      className="theme-toggle"
      onClick={toggle}
      aria-label={isVivid ? "Switch to dark theme" : "Switch to vivid theme"}
    >
      {isVivid ? "🌙" : "☀️"}
    </button>
  );
}
