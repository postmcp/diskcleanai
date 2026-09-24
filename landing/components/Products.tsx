import Image from "next/image";
import Link from "next/link";
import { ArrowRight, ArrowUpRight } from "lucide-react";
import { products } from "@/lib/site";
import { tools } from "@/lib/tools";
import { Container, SectionHeading } from "./ui";

export function Products() {
  return (
    <section id="more-from-us" className="scroll-mt-20 py-24 sm:py-32">
      <Container>
        <SectionHeading
          eyebrow="More from us"
          title={`Disk Clean AI is one of ${tools.length} tools we build.`}
          lead="A few of the others are here. Each one does a single job well."
        />

        <ul className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {products.map((product) => (
            <li key={product.url}>
              <a
                href={product.url}
                target="_blank"
                rel="noreferrer"
                className="group flex h-full flex-col rounded-3xl border border-white/70 bg-white/65 p-6 backdrop-blur-md transition-[border-color,box-shadow,transform] duration-200 hover:-translate-y-0.5 hover:border-ink/15 hover:shadow-[0_16px_40px_-24px_rgba(0,0,0,0.25)]"
              >
                <div className="flex items-start justify-between">
                  <span
                    className="grid h-12 w-12 place-items-center overflow-hidden rounded-[14px] ring-1 ring-black/5"
                    style={{ background: product.logoBg }}
                  >
                    <Image
                      src={product.logo}
                      alt={`${product.name} logo`}
                      width={48}
                      height={48}
                      className="h-full w-full object-cover"
                    />
                  </span>
                  <ArrowUpRight
                    size={18}
                    className="text-muted transition-colors group-hover:text-ink"
                    aria-hidden="true"
                  />
                </div>
                <h3 className="mt-5 text-lg font-semibold tracking-[-0.01em] text-ink">
                  {product.name}
                </h3>
                <p className="mt-1 text-[15px] font-medium text-ink/80">{product.tagline}</p>
                <p className="mt-2 text-pretty text-[14px] leading-relaxed text-body">
                  {product.description}
                </p>
                <span className="mt-auto pt-5 text-[13px] font-medium text-muted">
                  {product.url.replace("https://", "")}
                </span>
              </a>
            </li>
          ))}
        </ul>

        <div className="mt-10 text-center">
          <Link
            href="/tools"
            className="inline-flex items-center gap-2 text-[15px] font-medium text-ink transition-colors hover:text-brand"
          >
            See all {tools.length} tools
            <ArrowRight size={16} strokeWidth={2.2} aria-hidden="true" />
          </Link>
        </div>
      </Container>
    </section>
  );
}
