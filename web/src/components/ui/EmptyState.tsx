import { ReactNode } from "react";

export function EmptyState({
  icon,
  title,
  description,
  action,
}: {
  icon: ReactNode;
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center text-center px-6 py-14 gap-3">
      <div className="w-12 h-12 rounded-2xl bg-cream2 flex items-center justify-center text-muted-2">
        {icon}
      </div>
      <div>
        <p className="text-sm font-semibold text-text">{title}</p>
        {description && (
          <p className="text-xs text-muted mt-1 max-w-xs">{description}</p>
        )}
      </div>
      {action}
    </div>
  );
}

export function Spinner({ label = "Carregando…" }: { label?: string }) {
  return (
    <div className="flex items-center justify-center gap-2.5 text-muted text-sm py-14">
      <span className="w-4 h-4 rounded-full border-2 border-border border-t-g700 spin" />
      {label}
    </div>
  );
}
