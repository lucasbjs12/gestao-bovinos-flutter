import { ReactNode } from "react";

type Tone = "green" | "gold" | "red" | "gray" | "blue";

const tones: Record<Tone, string> = {
  green: "bg-g50 text-g800",
  gold: "bg-gold-50 text-[#7a5a12]",
  red: "bg-danger-bg text-danger",
  gray: "bg-cream2 text-muted",
  blue: "bg-info-bg text-info",
};

export function Badge({
  children,
  tone = "gray",
  className = "",
}: {
  children: ReactNode;
  tone?: Tone;
  className?: string;
}) {
  return (
    <span
      className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold ${tones[tone]} ${className}`}
    >
      {children}
    </span>
  );
}
