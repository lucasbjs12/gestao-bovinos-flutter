"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { BrandMark } from "@/components/ui/BrandMark";

export default function RootPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    router.replace(user ? "/inicio" : "/login");
  }, [loading, user, router]);

  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-cream gap-3">
      <BrandMark size={36} />
      <span className="w-4 h-4 rounded-full border-2 border-border border-t-g700 spin" />
    </div>
  );
}
