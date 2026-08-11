import { ReactNode } from "react";

export function FormField({
  label,
  children,
  hint,
}: {
  label: string;
  children: ReactNode;
  hint?: string;
}) {
  return (
    <label className="flex flex-col gap-1.5">
      <span className="text-xs font-semibold text-text">{label}</span>
      {children}
      {hint && <span className="text-[11px] text-muted-2">{hint}</span>}
    </label>
  );
}
