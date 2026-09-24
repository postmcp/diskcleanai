import Link from "next/link";
import { Footer } from "@/components/Footer";
import { Nav } from "@/components/Nav";
import { ButtonLink, Container } from "@/components/ui";
import { sortedPosts } from "@/lib/blog";

export default function NotFound() {
  return (
    <>
      <Nav />
      <main className="flex-1 py-24 sm:py-32">
        <Container>
          <div className="mx-auto max-w-xl text-center">
            <p className="text-sm font-semibold uppercase tracking-[0.12em] text-brand">404</p>
            <h1 className="mt-4 text-balance text-4xl font-bold leading-[1.05] tracking-[-0.035em] text-ink sm:text-5xl">
              That page has been cleaned up.
            </h1>
            <p className="mt-5 text-pretty text-lg leading-relaxed text-body">
              The link is wrong or the page moved. Here&rsquo;s where to go instead.
            </p>
            <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
              <ButtonLink href="/">Back to the homepage</ButtonLink>
              <ButtonLink href="/blog" variant="secondary">Read the guides</ButtonLink>
            </div>
            <ul className="mt-12 space-y-2 text-left text-[15px]">
              {sortedPosts.slice(0, 4).map((p) => (
                <li key={p.slug}>
                  <Link href={`/blog/${p.slug}`} className="font-medium text-brand underline decoration-brand/30 underline-offset-[3px] hover:decoration-brand">
                    {p.title}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </Container>
      </main>
      <Footer />
    </>
  );
}
