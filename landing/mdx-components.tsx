import type { MDXComponents } from "mdx/types";
import type { ComponentProps, ReactNode } from "react";
import Link from "next/link";
import { AlertTriangle, Info, Lightbulb } from "lucide-react";

/* Prose styling for blog posts. Kept here (instead of a typography plugin) so the
   article uses the same palette and type scale as the rest of the site. */

function Anchor({ href = "", children, ...rest }: ComponentProps<"a">) {
  const className = "font-medium text-brand underline decoration-brand/30 underline-offset-[3px] transition-colors hover:decoration-brand";
  if (href.startsWith("/") || href.startsWith("#")) {
    return (
      <Link href={href} className={className} {...rest}>
        {children}
      </Link>
    );
  }
  return (
    <a href={href} className={className} target="_blank" rel="noreferrer" {...rest}>
      {children}
    </a>
  );
}

const callouts = {
  tip: { icon: Lightbulb, label: "Tip", classes: "border-chart-mint/40 bg-chart-mint/10" },
  note: { icon: Info, label: "Note", classes: "border-brand/30 bg-brand-soft" },
  warning: { icon: AlertTriangle, label: "Careful", classes: "border-chart-amber/50 bg-chart-amber/10" },
} as const;

/** `<Callout type="warning">…</Callout>` inside MDX. */
export function Callout({ type = "note", title, children }: { type?: keyof typeof callouts; title?: string; children: ReactNode }) {
  const { icon: Icon, label, classes } = callouts[type];
  return (
    <aside className={`not-prose my-7 rounded-2xl border px-5 py-4 ${classes}`}>
      <p className="flex items-center gap-2 text-sm font-semibold text-ink">
        <Icon size={16} aria-hidden="true" />
        {title ?? label}
      </p>
      <div className="mt-2 text-[15px] leading-relaxed text-body [&_code]:rounded [&_code]:bg-white/70 [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:font-mono [&_code]:text-[13px] [&_p+p]:mt-2">
        {children}
      </div>
    </aside>
  );
}

const components: MDXComponents = {
  a: Anchor,
  h2: (props) => (
    <h2
      className="mt-12 scroll-mt-24 text-balance text-2xl font-bold leading-tight tracking-[-0.02em] text-ink sm:text-[28px]"
      {...props}
    />
  ),
  h3: (props) => (
    <h3 className="mt-8 scroll-mt-24 text-balance text-xl font-semibold tracking-[-0.01em] text-ink" {...props} />
  ),
  h4: (props) => <h4 className="mt-6 text-base font-semibold text-ink" {...props} />,
  p: (props) => <p className="mt-5 text-pretty text-[17px] leading-[1.7] text-body" {...props} />,
  ul: (props) => <ul className="mt-5 list-disc space-y-2 pl-6 text-[17px] leading-[1.7] text-body marker:text-muted" {...props} />,
  ol: (props) => <ol className="mt-5 list-decimal space-y-2 pl-6 text-[17px] leading-[1.7] text-body marker:font-semibold marker:text-ink" {...props} />,
  li: (props) => <li className="pl-1 [&>p]:mt-0" {...props} />,
  strong: (props) => <strong className="font-semibold text-ink" {...props} />,
  blockquote: (props) => (
    <blockquote className="mt-6 border-l-2 border-brand pl-5 text-[17px] italic leading-relaxed text-body" {...props} />
  ),
  hr: () => <hr className="my-12 border-line" />,
  code: (props) => (
    <code
      className="rounded-md bg-surface px-1.5 py-0.5 font-mono text-[0.86em] text-ink ring-1 ring-line [pre_&]:rounded-none [pre_&]:bg-transparent [pre_&]:p-0 [pre_&]:text-inherit [pre_&]:ring-0"
      {...props}
    />
  ),
  pre: (props) => (
    <pre
      className="mt-6 overflow-x-auto rounded-2xl bg-ink px-5 py-4 font-mono text-[13.5px] leading-relaxed text-white/90"
      {...props}
    />
  ),
  table: (props) => (
    <div className="mt-6 overflow-x-auto rounded-2xl border border-line bg-white/70">
      <table className="w-full min-w-[540px] border-collapse text-left text-[15px] leading-relaxed" {...props} />
    </div>
  ),
  thead: (props) => <thead className="bg-surface text-ink" {...props} />,
  th: (props) => <th className="border-b border-line px-4 py-3 text-sm font-semibold" {...props} />,
  td: (props) => <td className="border-b border-line px-4 py-3 align-top text-body last:border-b-0 [tr:last-child_&]:border-b-0" {...props} />,
  img: (props) => (
    // eslint-disable-next-line @next/next/no-img-element
    <img className="mt-6 w-full rounded-2xl border border-line" loading="lazy" {...props} alt={props.alt ?? ""} />
  ),
  Callout,
};

export function useMDXComponents(): MDXComponents {
  return components;
}
