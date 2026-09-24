import Image from "next/image";
import { Check, ChevronDown, KeyRound } from "lucide-react";
import { ButtonLink, Container, Eyebrow } from "./ui";

const points = [
  "Your key lives in the macOS Keychain and is only ever sent to OpenRouter.",
  "Switch models any time — a cheap one for everyday scans, a stronger one for tricky calls.",
  "Scanning and the chart work without a key. AI suggestions are the only part that needs one.",
];

export function BringYourKey() {
  return (
    <section id="bring-your-key" className="scroll-mt-20 overflow-x-clip py-24 sm:py-32">
      <Container>
        <div className="grid items-center gap-14 lg:grid-cols-2 lg:gap-20">
          <div>
            <Eyebrow>Bring your own key</Eyebrow>
            <h2 className="text-balance text-3xl font-bold leading-[1.08] tracking-[-0.03em] text-ink sm:text-4xl lg:text-[44px]">
              Your key. Your model. Your bill.
            </h2>
            <p className="mt-5 text-pretty text-lg leading-relaxed text-body">
              Disk Clean AI never proxies or resells AI credits.
              Paste an OpenRouter key, choose any model it supports — Claude,
              GPT, Gemini, Llama — and pay OpenRouter directly. A typical scan
              costs a few cents.
            </p>
            <ul className="mt-8 space-y-4">
              {points.map((point) => (
                <li key={point} className="flex gap-3 text-[15px] leading-relaxed text-body">
                  <span className="mt-1 grid h-5 w-5 shrink-0 place-items-center rounded-full bg-brand-soft text-brand">
                    <Check size={12} strokeWidth={3} aria-hidden="true" />
                  </span>
                  {point}
                </li>
              ))}
            </ul>
            <ButtonLink
              href="https://openrouter.ai/keys"
              target="_blank"
              rel="noreferrer"
              variant="secondary"
              className="mt-9"
            >
              <KeyRound size={16} aria-hidden="true" />
              Get an OpenRouter key
            </ButtonLink>
          </div>

          {/* Settings panel mock */}
          <div className="relative mx-auto w-full max-w-md lg:max-w-none">
            <div
              aria-hidden="true"
              className="absolute -inset-6 -z-10 rounded-[40px] bg-[radial-gradient(70%_70%_at_50%_50%,var(--color-brand-tint)_0%,rgba(255,255,255,0)_100%)]"
            />
            <div className="rounded-3xl border border-white/70 bg-white/75 p-6 shadow-[0_24px_60px_-30px_rgba(37,99,235,0.35)] backdrop-blur-md sm:p-8">
              <p className="text-[13px] font-semibold uppercase tracking-[0.1em] text-muted">
                Settings · AI provider
              </p>

              <label className="mt-6 block text-sm font-medium text-ink">
                OpenRouter API key
              </label>
              <div className="mt-2 flex items-center gap-3 rounded-xl border border-line bg-surface px-4 py-3 font-mono text-[13px] text-ink">
                <span className="flex-1 truncate">sk-or-v1-••••••••••••••••••••••••4f2a</span>
                <span className="inline-flex items-center gap-1 rounded-full bg-emerald-50 px-2 py-0.5 text-[11px] font-semibold text-emerald-700">
                  <Check size={11} strokeWidth={3} aria-hidden="true" />
                  Verified
                </span>
              </div>

              <label className="mt-5 block text-sm font-medium text-ink">Model</label>
              <div className="mt-2 flex items-center justify-between rounded-xl border border-line bg-surface px-4 py-3 text-[14px] text-ink">
                <span>
                  <span className="font-medium">Claude Sonnet</span>
                  <span className="ml-2 font-mono text-[12px] text-muted">anthropic/claude-sonnet</span>
                </span>
                <ChevronDown size={16} className="text-muted" aria-hidden="true" />
              </div>

              <dl className="mt-6 grid grid-cols-2 gap-4 border-t border-line pt-5 text-sm">
                <div>
                  <dt className="text-muted">Last scan</dt>
                  <dd className="mt-0.5 font-medium text-ink">$0.02 · 1.9k tokens</dd>
                </div>
                <div>
                  <dt className="text-muted">Sent to the model</dt>
                  <dd className="mt-0.5 font-medium text-ink">Names, sizes, dates</dd>
                </div>
              </dl>
            </div>

            <Image
              src="/images/api-key.png"
              alt=""
              width={160}
              height={160}
              className="absolute -top-10 right-0 h-28 w-28 rotate-6 sm:-top-12 sm:h-36 sm:w-36 lg:-right-8"
            />
          </div>
        </div>
      </Container>
    </section>
  );
}
