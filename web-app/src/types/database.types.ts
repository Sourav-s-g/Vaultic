/*
 * PROVISIONAL DATABASE TYPES
 *
 * docs/supabase/schema-snapshot.md currently contains no table DDL. These table shapes are inferred from Flutter
 * client payloads in docs/PARITY.md and are not generated or schema-verified.
 * Replace them from the authoritative Supabase schema before relying on column
 * nullability, constraints, indexes, or relationships.
 */
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

type ProvisionalTable<Row, Insert, Update = Partial<Insert>> = {
  Row: Row;
  Insert: Insert;
  Update: Update;
  Relationships: [];
};

type Owned = { user_id: string };
type TimestampRow = { created_at: string };

export type Database = {
  public: {
    Tables: {
      categories: ProvisionalTable<
        Owned & TimestampRow & { id: number; name: string; color: string; icon: string },
        Owned & { name: string; color?: string; icon?: string; created_at?: string }
      >;
      transactions: ProvisionalTable<
        Owned & {
          id: number;
          transaction_id: string;
          description: string;
          amount: number;
          type: string;
          date: string;
          category: string;
          status: string;
          is_split?: boolean;
          split_count?: number;
        },
        Owned & {
          transaction_id: string;
          description: string;
          amount: number;
          type: string;
          date: string;
          category: string;
          status: string;
          is_split?: boolean;
          split_count?: number;
        }
      >;
      budgets: ProvisionalTable<
        Owned & { id: number; category: string; amount: number },
        Owned & { category: string; amount: number }
      >;
      owo_entries: ProvisionalTable<
        Owned & TimestampRow & {
          id: number;
          owo_id: string;
          counterparty: string;
          direction: string;
          amount: number;
          note: string;
          due_date: string | null;
          settled: boolean;
        },
        Owned & {
          owo_id: string;
          counterparty: string;
          direction: string;
          amount: number;
          note: string;
          created_at?: string;
          due_date?: string | null;
          settled?: boolean;
        }
      >;
      user_settings: ProvisionalTable<
        Owned & { initial_balance: number; updated_at: string },
        Owned & { initial_balance: number; updated_at?: string }
      >;
      trips: ProvisionalTable<
        Owned & TimestampRow & {
          trip_id: string;
          name: string;
          categories: string[];
          start_date: string | null;
          end_date: string | null;
          description: string | null;
          budget: number | null;
          category_budgets: Json | null;
        },
        Owned & {
          trip_id: string;
          name: string;
          categories: string[];
          created_at?: string;
          start_date?: string | null;
          end_date?: string | null;
          description?: string | null;
          budget?: number | null;
          category_budgets?: Json | null;
        }
      >;
      trip_transactions: ProvisionalTable<
        Owned & {
          id: number;
          trip_id: string;
          transaction_id: string;
          description: string;
          amount: number;
          type: string;
          date: string;
          category: string;
          status: string;
          is_split?: boolean;
          split_count?: number;
        },
        Owned & {
          trip_id: string;
          transaction_id: string;
          description: string;
          amount: number;
          type: string;
          date: string;
          category: string;
          status: string;
          is_split?: boolean;
          split_count?: number;
        }
      >;
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
