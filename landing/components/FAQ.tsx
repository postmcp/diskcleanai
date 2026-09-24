import { Plus } from "lucide-react";
import { Container, SectionHeading } from "./ui";

export const faqs = [
  {
    q: "Is Disk Clean AI really free?",
    a: "Yes. It's open source under the MIT license, with no trial, subscription, account or license key. Download the latest release or build it from source. The only thing that can cost money is the optional AI Advisor, which runs on your own OpenRouter key.",
  },
  {
    q: "Where is the source code?",
    a: "On GitHub at github.com/postmcp/diskcleanai. The SwiftUI app and this website are both in the repo. Clone it, open macApp/DiskCleanAI.xcodeproj in Xcode 16 or later, and run the DiskCleanAI scheme.",
  },
  {
    q: "How can I contribute?",
    a: "Open an issue for bugs or feature ideas, or send a pull request. New Quick Win rules, safety-policy fixes, translations and Explore patterns are all welcome. The contributing guide in the repo explains how to get set up.",
  },
  {
    q: "Do I pay for the AI separately?",
    a: "Yes, but only what OpenRouter charges. Disk Clean AI does not mark up or resell model usage — a typical scan costs a few cents on your own OpenRouter key.",
  },
  {
    q: "Does it ever delete files on its own?",
    a: "No. Nothing leaves your disk until you review a list and approve it. Approved items go to the Trash, so you can still get them back.",
  },
  {
    q: "What does the AI actually see?",
    a: "File paths, names, sizes, types and dates — enough to reason about what's clutter. It never reads file contents and never uploads files.",
  },
  {
    q: "Which models can I use?",
    a: "Anything OpenRouter offers: Claude, GPT, Gemini, Llama, Mistral and more. Use a cheap model for everyday scans and a stronger one when you want more careful judgement.",
  },
  {
    q: "How do updates work?",
    a: "The app checks for new versions once a day and installs them in place after verifying a checksum. You can also check manually from the Disk Clean AI menu, or grab any build from the GitHub releases page.",
  },
  {
    q: "Which Macs are supported?",
    a: "macOS 14 Sonoma or later, on both Apple silicon and Intel.",
  },
];

export function FAQ() {
  return (
    <section id="faq" className="scroll-mt-20 py-24 sm:py-32">
      <Container>
        <SectionHeading eyebrow="FAQ" title="Questions people ask before installing." />
        <div className="mx-auto mt-12 max-w-3xl divide-y divide-line border-y border-line">
          {faqs.map((item) => (
            <details key={item.q} className="group">
              <summary className="flex cursor-pointer items-center justify-between gap-6 py-5 text-left text-lg font-medium text-ink">
                {item.q}
                <Plus
                  size={18}
                  className="faq-chevron shrink-0 text-muted transition-transform duration-200"
                  aria-hidden="true"
                />
              </summary>
              <p className="pb-6 text-pretty text-[15px] leading-relaxed text-body sm:text-base">
                {item.a}
              </p>
            </details>
          ))}
        </div>
      </Container>
    </section>
  );
}
