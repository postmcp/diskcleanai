import Image from "next/image";

/**
 * The real app inside a MacBook frame: the Explore screen right after a full
 * scan of a startup disk. The capture is a 2× Retina window grab (2560×1624),
 * so it stays crisp on every display.
 */
export function AppMockup() {
  return (
    <figure className="relative mx-auto max-w-5xl">
      {/* Lid */}
      <div className="relative rounded-[22px] bg-[#101014] p-2 shadow-[0_30px_80px_-20px_rgba(37,99,235,0.35),0_18px_40px_-24px_rgba(0,0,0,0.5)] ring-1 ring-black/20 sm:rounded-[30px] sm:p-3">
        <div
          aria-hidden="true"
          className="absolute left-1/2 top-0 z-10 hidden h-5 w-32 -translate-x-1/2 rounded-b-[12px] bg-[#101014] sm:block"
        />
        {/* Screen — the ground matches the app's sidebar so the window's rounded corners disappear. */}
        <div className="overflow-hidden rounded-[14px] bg-[#f6f7fb] sm:rounded-[20px]">
          <Image
            src="/screenshots/explore-sunburst.webp"
            alt="Disk Clean AI after scanning a 128 GB startup disk: a sunburst chart of every folder coloured by file type, quick wins listed in the sidebar, and an inspector showing the largest items inside."
            width={2560}
            height={1624}
            sizes="(max-width: 1024px) 100vw, 1024px"
            quality={90}
            loading="eager"
            fetchPriority="high"
            className="block h-auto w-full"
          />
        </div>
      </div>

      {/* Base */}
      <div
        aria-hidden="true"
        className="mx-auto h-2.5 w-[94%] rounded-b-[14px] bg-gradient-to-b from-[#2a2a31] to-[#141418] sm:h-3.5"
      />
      <div
        aria-hidden="true"
        className="mx-auto h-1 w-[18%] -translate-y-px rounded-b-md bg-[#0c0c0f]"
      />
      <figcaption className="sr-only">
        A real screenshot of the Disk Clean AI Explore screen.
      </figcaption>
    </figure>
  );
}
