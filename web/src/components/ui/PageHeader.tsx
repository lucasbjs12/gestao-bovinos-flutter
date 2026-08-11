import { ReactNode } from "react";

export function PageHeader({
  title,
  subtitle,
  action,
  eyebrow,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
  eyebrow?: string;
}) {
  return (
    <div className="flex items-start justify-between gap-4 flex-wrap mb-7">
      <div>
        {eyebrow && (
          <div className="text-[11px] font-bold uppercase tracking-wider text-g700 mb-1">
            {eyebrow}
          </div>
        )}
        <h1 className="font-display text-[1.65rem] font-semibold text-text tracking-tight">
          {title}
        </h1>
        {subtitle && <p className="text-sm text-muted mt-1">{subtitle}</p>}
      </div>
      {action && <div className="flex items-center gap-2.5 flex-wrap">{action}</div>}
    </div>
  );
}
