import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { getPublicSupabaseConfig } from "./env";

let browserClient: SupabaseClient<Database> | undefined;

export function createClient(): SupabaseClient<Database> {
  if (browserClient) return browserClient;

  const { url, anonKey } = getPublicSupabaseConfig();
  browserClient = createBrowserClient<Database>(url, anonKey);
  return browserClient;
}
