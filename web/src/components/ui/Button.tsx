import { ButtonHTMLAttributes, ReactNode } from "react";
import Link from "next/link";
import { Loader2 } from "lucide-react";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "danger-solid" | "gold";
type Size = "md" | "sm";

const base =
  "inline-flex items-center justify-center gap-2 font-semibold transition-colors disabled:opacity-55 disabled:pointer-events-none whitespace-nowrap select-none";

const variants: Record<Variant, string> = {
  primary: "bg-g800 text-white hover:bg-g900 shadow-sm",
  secondary: "bg-surface border-[1.5px] border-border text-text hover:bg-cream",
  ghost: "text-muted hover:text-text hover:bg-cream2",
  danger: "text-danger hover:bg-danger-bg",
  "danger-solid": "bg-danger text-white hover:bg-[#a5301f] shadow-sm",
  gold: "bg-gold text-forest hover:bg-gold-lt shadow-sm",
};

const sizes: Record<Size, string> = {
  md: "text-sm px-4 py-2.5 rounded-[10px]",
  sm: "text-xs px-3 py-1.5 rounded-lg",
};

interface CommonProps {
  variant?: Variant;
  size?: Size;
  icon?: ReactNode;
  loading?: boolean;
  children: ReactNode;
  className?: string;
}

type ButtonProps = CommonProps &
  ButtonHTMLAttributes<HTMLButtonElement> & { href?: undefined };

type LinkProps = CommonProps & {
  href: string;
};

export function Button({
  variant = "primary",
  size = "md",
  icon,
  loading,
  children,
  className = "",
  href,
  ...rest
}: ButtonProps | LinkProps) {
  const cls = `${base} ${variants[variant]} ${sizes[size]} ${className}`;

  if (href) {
    return (
      <Link href={href} className={cls}>
        {icon}
        {children}
      </Link>
    );
  }

  return (
    <button
      className={cls}
      disabled={loading || (rest as ButtonHTMLAttributes<HTMLButtonElement>).disabled}
      {...(rest as ButtonHTMLAttributes<HTMLButtonElement>)}
    >
      {loading ? <Loader2 size={15} className="spin" /> : icon}
      {children}
    </button>
  );
}
