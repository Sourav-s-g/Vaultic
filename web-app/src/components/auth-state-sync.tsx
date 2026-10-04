"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { createClient } from "@/lib/supabase/browser";
import { hasPublicSupabaseConfig } from "@/lib/supabase/env";

export function AuthStateSync() {
  const router = useRouter();
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!hasPublicSupabaseConfig()) return;

    const supabase = createClient();
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event) => {
      if (event === "INITIAL_SESSION") return;

      if (event === "SIGNED_OUT") queryClient.clear();
      else void queryClient.invalidateQueries();

      if (event === "PASSWORD_RECOVERY") {
        window.dispatchEvent(new Event("vaultic:password-recovery"));
      }

      router.refresh();
    });

    return () => subscription.unsubscribe();
  }, [queryClient, router]);

  return null;
}
