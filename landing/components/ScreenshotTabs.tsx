"use client";

import Image from "next/image";
import { useId, useState, type KeyboardEvent } from "react";

export type ScreenshotTab = {
  id: string;
  label: string;
  /** One line under the tab strip — same wording the app uses for the mode. */
  blurb: string;
  src: string;
  alt: string;
};

/**
 * A strip of tabs that swaps between real app screenshots. Styled after the
 * app's own mode bar: the selected tab is filled with ink, the rest sit flat.
 * Every capture is 2560×1624, so switching never shifts the layout.
 */
export function ScreenshotTabs({
  tabs,
  label,
  sizes = "(max-width: 1152px) 100vw, 1152px",
}: {
  tabs: ScreenshotTab[];
  label: string;
  sizes?: string;
}) {
  const [active, setActive] = useState(tabs[0].id);
  const baseId = useId();
  const current = tabs.find((tab) => tab.id === active) ?? tabs[0];

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    const index = tabs.findIndex((tab) => tab.id === active);
    let next = index;
    if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
    else if (event.key === "ArrowLeft") next = (index - 1 + tabs.length) % tabs.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = tabs.length - 1;
    else return;
    event.preventDefault();
    setActive(tabs[next].id);
    document.getElementById(`${baseId}-tab-${tabs[next].id}`)?.focus();
  }

  return (
    <div>
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div
          role="tablist"
          aria-label={label}
          onKeyDown={onKeyDown}
          className="inline-flex max-w-full flex-wrap gap-0.5 rounded-xl border border-line bg-white/85 p-1 shadow-[0_1px_2px_rgba(0,0,0,0.04)] backdrop-blur-sm"
        >
          {tabs.map((tab) => {
            const selected = tab.id === active;
            return (
              <button
                key={tab.id}
                id={`${baseId}-tab-${tab.id}`}
                type="button"
                role="tab"
                aria-selected={selected}
                aria-controls={`${baseId}-panel-${tab.id}`}
                tabIndex={selected ? 0 : -1}
                onClick={() => setActive(tab.id)}
                className={`rounded-lg px-3 py-1.5 text-[13px] font-medium transition-colors duration-150 ${
                  selected
                    ? "bg-ink text-white"
                    : "text-body hover:bg-surface hover:text-ink"
                }`}
              >
                {tab.label}
              </button>
            );
          })}
        </div>
        <p className="text-sm text-muted sm:text-right" aria-live="polite">
          {current.blurb}
        </p>
      </div>

      <div className="mt-5 overflow-hidden rounded-2xl border border-white/70 bg-[#f6f7fb] shadow-[0_1px_0_rgba(255,255,255,0.8)_inset,0_30px_70px_-30px_rgba(16,24,40,0.35)] ring-1 ring-black/5 sm:rounded-3xl">
        {tabs.map((tab) => (
          <div
            key={tab.id}
            id={`${baseId}-panel-${tab.id}`}
            role="tabpanel"
            aria-labelledby={`${baseId}-tab-${tab.id}`}
            hidden={tab.id !== active}
          >
            <Image
              src={tab.src}
              alt={tab.alt}
              width={2560}
              height={1624}
              sizes={sizes}
              quality={90}
              className="block h-auto w-full"
            />
          </div>
        ))}
      </div>
    </div>
  );
}
