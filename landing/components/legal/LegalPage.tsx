import type { ReactNode } from "react";
import { Footer } from "../Footer";
import { Nav } from "../Nav";
import { Container, Eyebrow } from "../ui";

/** Shared shell for the privacy and terms pages: same prose scale as the blog. */
export function LegalPage({ eyebrow, title, updated, children }: { eyebrow: string; title: string; updated: string; children: ReactNode }) {
  return (
    <>
      <Nav />
      <main className="flex-1 pb-24 pt-16 sm:pt-24">
        <Container>
          <article className="mx-auto max-w-3xl [&_h2]:mt-10 [&_h2]:text-2xl [&_h2]:font-bold [&_h2]:tracking-[-0.02em] [&_h2]:text-ink [&_li]:pl-1 [&_p]:mt-4 [&_p]:text-[17px] [&_p]:leading-[1.7] [&_p]:text-body [&_ul]:mt-4 [&_ul]:list-disc [&_ul]:space-y-2 [&_ul]:pl-6 [&_ul]:text-[17px] [&_ul]:leading-[1.7] [&_ul]:text-body [&_a]:font-medium [&_a]:text-brand [&_a]:underline [&_a]:underline-offset-[3px] [&_strong]:font-semibold [&_strong]:text-ink">
            <Eyebrow>{eyebrow}</Eyebrow>
            <h1 className="text-balance text-4xl font-bold leading-[1.05] tracking-[-0.035em] text-ink sm:text-5xl">{title}</h1>
            <p className="!mt-3 text-sm !text-muted">Last updated {updated}</p>
            {children}
          </article>
        </Container>
      </main>
      <Footer />
    </>
  );
}
