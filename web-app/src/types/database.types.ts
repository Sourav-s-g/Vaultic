type Table<Row, Insert, Update = Partial<Insert>> = {
  Row: Row;
  Insert: Insert;
  Update: Update;
  Relationships: [];
};

type CategoryRow = {
  id: string;
  user_id: string | null;
  name: string;
  color: string | null;
  icon: string | null;
  created_at: string | null;
  updated_at: string | null;
};

type TransactionRow = {
  id: string;
  user_id: string | null;
  transaction_id: string;
  description: string;
  amount: number;
  type: "Credit" | "Debit";
  date: string;
  category: string | null;
  status: string | null;
  is_split: boolean | null;
  split_count: number | null;
  created_at: string | null;
  updated_at: string | null;
};

type BudgetRow = {
  id: string;
  user_id: string | null;
  category: string;
  amount: number;
  created_at: string | null;
  updated_at: string | null;
};

type OwoEntryRow = {
  id: string;
  user_id: string | null;
  owo_id: string;
  counterparty: string;
  direction: "owe" | "owned";
  amount: number;
  note: string | null;
  created_at: string | null;
  updated_at: string | null;
  due_date: string | null;
  settled: boolean | null;
};

type UserSettingsRow = {
  user_id: string;
  initial_balance: number | null;
  updated_at: string;
};

type TripRow = {
  trip_id: string;
  user_id: string;
  name: string;
  categories: string[];
  start_date: string | null;
  end_date: string | null;
  description: string | null;
  budget: number | null;
  category_budgets: Json | null;
  created_at: string;
  updated_at: string;
};

type TripTransactionRow = {
  transaction_id: string;
  trip_id: string;
  user_id: string;
  amount: number;
  date: string;
  is_split: boolean;
  split_count: number;
  created_at: string;
  updated_at: string;
  description: string;
  type: "Credit" | "Debit";
  category: string;
  status: string;
};

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  public: {
    Tables: {
      categories: Table<
        CategoryRow,
        Pick<CategoryRow, "name"> & Partial<Omit<CategoryRow, "id" | "name">>
      >;
      transactions: Table<
        TransactionRow,
        Pick<TransactionRow, "transaction_id" | "description" | "amount" | "type" | "date"> &
          Partial<Omit<TransactionRow, "id" | "transaction_id" | "description" | "amount" | "type" | "date">>
      >;
      budgets: Table<
        BudgetRow,
        Pick<BudgetRow, "category" | "amount"> & Partial<Omit<BudgetRow, "id" | "category" | "amount">>
      >;
      owo_entries: Table<
        OwoEntryRow,
        Pick<OwoEntryRow, "owo_id" | "counterparty" | "direction" | "amount"> &
          Partial<Omit<OwoEntryRow, "id" | "owo_id" | "counterparty" | "direction" | "amount">>
      >;
      user_settings: Table<
        UserSettingsRow,
        Pick<UserSettingsRow, "user_id"> & Partial<Omit<UserSettingsRow, "user_id">>
      >;
      trips: Table<
        TripRow,
        Pick<TripRow, "trip_id" | "user_id" | "name"> &
          Partial<Omit<TripRow, "trip_id" | "user_id" | "name">>
      >;
      trip_transactions: Table<
        TripTransactionRow,
        Pick<TripTransactionRow, "transaction_id" | "trip_id" | "user_id"> &
          Partial<Omit<TripTransactionRow, "transaction_id" | "trip_id" | "user_id">>
      >;
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
