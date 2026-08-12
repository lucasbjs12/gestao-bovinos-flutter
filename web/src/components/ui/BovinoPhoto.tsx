import { Beef } from "lucide-react";

type BovinoPhotoSize = "sm" | "lg";

const sizeClasses: Record<BovinoPhotoSize, string> = {
  sm: "h-10 w-10 rounded-lg",
  lg: "h-44 w-full rounded-xl",
};

const iconSizes: Record<BovinoPhotoSize, number> = {
  sm: 18,
  lg: 34,
};

export function isPublicPhotoUrl(foto?: string | null): foto is string {
  return typeof foto === "string" && /^https?:\/\//i.test(foto);
}

export function BovinoPhoto({
  foto,
  alt,
  size = "sm",
}: {
  foto?: string | null;
  alt: string;
  size?: BovinoPhotoSize;
}) {
  const baseClass = `${sizeClasses[size]} shrink-0 overflow-hidden border border-border-soft bg-cream`;

  if (isPublicPhotoUrl(foto)) {
    return (
      <div className={baseClass}>
        <img src={foto} alt={alt} className="h-full w-full object-cover" />
      </div>
    );
  }

  return (
    <div className={`${baseClass} flex items-center justify-center text-muted-2`}>
      <Beef size={iconSizes[size]} />
    </div>
  );
}
