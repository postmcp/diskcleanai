import type { ComponentProps, ReactNode } from "react";
import Image from "next/image";

export function Container({
  className = "",
  children,
}: {
  className?: string;
  children: ReactNode;
}) {
  return (
    <div className={`mx-auto w-full max-w-6xl px-6 ${className}`}>{children}</div>
  );
}

const base =
  "inline-flex items-center justify-center gap-2 rounded-xl px-5 py-3 text-[15px] font-medium transition-colors duration-150 whitespace-nowrap";

const variants = {
  primary: "bg-brand text-white hover:bg-brand-deep",
  secondary: "border border-line bg-white text-ink hover:bg-surface",
  ghost: "text-ink hover:bg-surface",
  inverted: "bg-white text-ink hover:bg-brand-soft",
} as const;

type ButtonLinkProps = ComponentProps<"a"> & {
  variant?: keyof typeof variants;
  size?: "md" | "lg";
};

export function ButtonLink({
  variant = "primary",
  size = "md",
  className = "",
  children,
  ...rest
}: ButtonLinkProps) {
  const sizing = size === "lg" ? "px-7 py-4 text-base rounded-2xl" : "";
  return (
    <a className={`${base} ${variants[variant]} ${sizing} ${className}`} {...rest}>
      {children}
    </a>
  );
}

export function Eyebrow({ children }: { children: ReactNode }) {
  return (
    <p className="mb-4 text-sm font-semibold uppercase tracking-[0.12em] text-brand">
      {children}
    </p>
  );
}

export function SectionHeading({
  eyebrow,
  title,
  lead,
  align = "center",
}: {
  eyebrow?: string;
  title: string;
  lead?: string;
  align?: "center" | "left";
}) {
  const alignment = align === "center" ? "mx-auto text-center" : "text-left";
  return (
    <div className={`max-w-2xl ${alignment}`}>
      {eyebrow ? <Eyebrow>{eyebrow}</Eyebrow> : null}
      <h2 className="text-balance text-3xl font-bold leading-[1.08] tracking-[-0.03em] text-ink sm:text-4xl lg:text-[44px]">
        {title}
      </h2>
      {lead ? (
        <p className="mt-4 text-pretty text-lg leading-relaxed text-body">{lead}</p>
      ) : null}
    </div>
  );
}

export function Logo({ size = 40, wordmark = true }: { size?: number; wordmark?: boolean }) {
  return (
    <span className="inline-flex items-center gap-2">
      <Image
        src="/images/mascot.png"
        alt=""
        width={size}
        height={size}
        className="shrink-0"
        style={{ width: size, height: size }}
      />
      {wordmark ? (
        <span className="text-[17px] font-semibold tracking-[-0.01em] text-ink">
          Disk Clean AI
        </span>
      ) : null}
    </span>
  );
}

/** GitHub mark — lucide no longer ships brand icons. */
export function GitHubIcon({ size = 16, className = "" }: { size?: number; className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="currentColor"
      className={className}
      aria-hidden="true"
    >
      <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.1.79-.25.79-.56v-2.17c-3.2.7-3.87-1.37-3.87-1.37-.52-1.33-1.28-1.68-1.28-1.68-1.04-.71.08-.7.08-.7 1.15.08 1.76 1.19 1.76 1.19 1.03 1.76 2.69 1.25 3.35.96.1-.75.4-1.25.73-1.54-2.55-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.28 1.19-3.09-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.81 1.19 1.83 1.19 3.09 0 4.42-2.69 5.39-5.26 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.56A11.51 11.51 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5Z" />
    </svg>
  );
}
