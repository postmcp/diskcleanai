"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { ArrowUpRight, Check } from "lucide-react";
import { toolCategories, tools, type ToolCategory } from "@/lib/tools";

export function ToolsGrid() {
  const [category, setCategory] = useState<ToolCategory>("All");
  const visible = category === "All" ? tools : tools.filter((t) => t.category === category);

  return (
    <>
      <div role="tablist" aria-label="Filter by category" className="mt-10 flex flex-wrap gap-2">
        {toolCategories.map((item) => {
          const active = item === category;
          const count = item === "All" ? tools.length : tools.filter((t) => t.category === item).length;
          return (
            <button
              key={item}
              type="button"
              role="tab"
              aria-selected={active}
              onClick={() => setCategory(item)}
              className={`inline-flex items-center gap-1.5 rounded-full border px-4 py-2 text-sm font-medium transition-colors ${
                active
                  ? "border-ink bg-ink text-white"
                  : "border-line bg-white/70 text-body hover:border-ink/30 hover:text-ink"
              }`}
            >
              {item}
              <span className={`text-xs ${active ? "text-white/70" : "text-muted"}`}>{count}</span>
            </button>
          );
        })}
      </div>

      <ul className="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {visible.map((tool) => {
          const host = tool.url.replace(/^https?:\/\/(www\.)?/, "");
          const card =
            "group relative flex h-full flex-col rounded-3xl border border-white/70 bg-white/65 p-6 backdrop-blur-md transition-[border-color,box-shadow,transform] duration-200 hover:-translate-y-0.5 hover:border-ink/15 hover:shadow-[0_16px_40px_-24px_rgba(0,0,0,0.25)]";
          const body = (
            <>
              <div className="flex items-start justify-between">
                <span
                  className="grid h-12 w-12 place-items-center overflow-hidden rounded-[14px] ring-1 ring-black/5"
                  style={{ background: tool.logoBg ?? "#ffffff" }}
                >
                  <Image
                    src={tool.logo}
                    alt={`${tool.name} logo`}
                    width={48}
                    height={48}
                    className="h-full w-full object-cover"
                  />
                </span>
                <span className="rounded-full bg-surface px-2.5 py-1 text-xs font-medium text-body">
                  {tool.current ? "You're here" : tool.category}
                </span>
              </div>
              <h2 className="mt-5 flex items-center gap-1.5 text-lg font-semibold tracking-[-0.01em] text-ink">
                {tool.name}
                {tool.current ? null : (
                  <ArrowUpRight
                    size={16}
                    className="text-muted transition-colors group-hover:text-ink"
                    aria-hidden="true"
                  />
                )}
              </h2>
              <p className="mt-1 text-[15px] font-medium text-ink/80">{tool.tagline}</p>
              <p className="mt-2 text-pretty text-[14px] leading-relaxed text-body">{tool.description}</p>
              <ul className="mt-4 space-y-1.5">
                {tool.useCases.map((useCase) => (
                  <li key={useCase} className="flex gap-2 text-[13.5px] leading-snug text-body">
                    <Check size={14} strokeWidth={2.4} className="mt-0.5 shrink-0 text-brand" aria-hidden="true" />
                    {useCase}
                  </li>
                ))}
              </ul>
              <span className="mt-auto pt-5 text-[13px] font-medium text-muted">{host}</span>
            </>
          );
          return (
            <li key={tool.url}>
              {tool.current ? (
                <Link href="/" className={card}>
                  {body}
                </Link>
              ) : (
                <a href={tool.url} target="_blank" rel="noreferrer" className={card}>
                  {body}
                </a>
              )}
            </li>
          );
        })}
      </ul>
    </>
  );
}
