CREATE OR REPLACE FUNCTION public.delete_user_account()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- delete the user's app data first — adjust table/column names to your schema
  delete from public.transactions where user_id = auth.uid();
  delete from public.budgets where user_id = auth.uid();
  delete from public.categories where user_id = auth.uid();
  delete from public.owo_entries where user_id = auth.uid();

  -- delete the auth user itself (cascades to auth.identities, sessions, refresh tokens, etc.)
  delete from auth.users where id = auth.uid();
end;
$function$

# Supabase Schema Snapshot

Captured: 2026-10-04 from the production Supabase project (SQL editor).
Source of truth for web-app/. If the database changes, re-run the queries and update this file.

## 1. Functions

(keep the existing delete_user_account() definition here, unchanged)

Note: used only by the Flutter app. Out of scope for the web app.

## 2. Constraints

Query: select conrelid::regclass, conname, pg_get_constraintdef(oid)
from pg_constraint where connamespace = 'public'::regnamespace;

[
  {
    "conrelid": "categories",
    "conname": "categories_pkey",
    "pg_get_constraintdef": "PRIMARY KEY (id)"
  },
  {
    "conrelid": "categories",
    "conname": "categories_user_id_fkey",
    "pg_get_constraintdef": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE"
  },
  {
    "conrelid": "budgets",
    "conname": "budgets_pkey",
    "pg_get_constraintdef": "PRIMARY KEY (id)"
  },
  {
    "conrelid": "budgets",
    "conname": "budgets_user_id_category_key",
    "pg_get_constraintdef": "UNIQUE (user_id, category)"
  },
  {
    "conrelid": "budgets",
    "conname": "budgets_user_id_fkey",
    "pg_get_constraintdef": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE"
  },
  {
    "conrelid": "owo_entries",
    "conname": "owo_entries_direction_check",
    "pg_get_constraintdef": "CHECK ((direction = ANY (ARRAY['owe'::text, 'owned'::text])))"
  },
  {
    "conrelid": "owo_entries",
    "conname": "owo_entries_pkey",
    "pg_get_constraintdef": "PRIMARY KEY (id)"
  },
  {
    "conrelid": "owo_entries",
    "conname": "owo_entries_user_id_owo_id_key",
    "pg_get_constraintdef": "UNIQUE (user_id, owo_id)"
  },
  {
    "conrelid": "owo_entries",
    "conname": "owo_entries_user_id_fkey",
    "pg_get_constraintdef": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE"
  },
  {
    "conrelid": "transactions",
    "conname": "transactions_type_check",
    "pg_get_constraintdef": "CHECK ((type = ANY (ARRAY['Credit'::text, 'Debit'::text])))"
  },
  {
    "conrelid": "transactions",
    "conname": "transactions_pkey",
    "pg_get_constraintdef": "PRIMARY KEY (id)"
  },
  {
    "conrelid": "transactions",
    "conname": "transactions_user_id_transaction_id_key",
    "pg_get_constraintdef": "UNIQUE (user_id, transaction_id)"
  },
  {
    "conrelid": "transactions",
    "conname": "transactions_user_id_fkey",
    "pg_get_constraintdef": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE"
  },
  {
    "conrelid": "user_settings",
    "conname": "user_settings_pkey",
    "pg_get_constraintdef": "PRIMARY KEY (user_id)"
  },
  {
    "conrelid": "user_settings",
    "conname": "user_settings_user_id_fkey",
    "pg_get_constraintdef": "FOREIGN KEY (user_id) REFERENCES auth.users(id)"
  },
  {
    "conrelid": "trips",
    "conname": "trips_pkey",
    "pg_get_constraintdef": "PRIMARY KEY (trip_id)"
  },
  {
    "conrelid": "trips",
    "conname": "trips_user_id_fkey",
    "pg_get_constraintdef": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE"
  },
  {
    "conrelid": "trip_transactions",
    "conname": "trip_transactions_pkey",
    "pg_get_constraintdef": "PRIMARY KEY (transaction_id)"
  },
  {
    "conrelid": "trip_transactions",
    "conname": "trip_transactions_trip_id_fkey",
    "pg_get_constraintdef": "FOREIGN KEY (trip_id) REFERENCES trips(trip_id) ON DELETE CASCADE"
  },
  {
    "conrelid": "trip_transactions",
    "conname": "trip_transactions_user_id_fkey",
    "pg_get_constraintdef": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE"
  }
] 

## 3. RLS status, policies and columns

Query: the json_build_object query that returns rls, policies and columns.

{
	"rls": [
		{
			"table": "budgets",
			"rls": true
		},
		{
			"table": "owo_entries",
			"rls": true
		},
		{
			"table": "transactions",
			"rls": true
		},
		{
			"table": "categories",
			"rls": true
		},
		{
			"table": "user_settings",
			"rls": true
		},
		{
			"table": "trip_transactions",
			"rls": true
		},
		{
			"table": "trips",
			"rls": true
		}
	],
	"policies": [
		{
			"table": "budgets",
			"policy": "Users can manage their own budgets",
			"cmd": "ALL",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		},
		{
			"table": "owo_entries",
			"policy": "Users can manage their own owo entries",
			"cmd": "ALL",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		},
		{
			"table": "transactions",
			"policy": "Users can manage their own transactions",
			"cmd": "ALL",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		},
		{
			"table": "categories",
			"policy": "Users can manage their own categories",
			"cmd": "ALL",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		},
		{
			"table": "user_settings",
			"policy": "Users can update own settings",
			"cmd": "ALL",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		},
		{
			"table": "user_settings",
			"policy": "Users can view own settings",
			"cmd": "SELECT",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		},
		{
			"table": "trip_transactions",
			"policy": "Users can delete their own trip transactions",
			"cmd": "DELETE",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		},
		{
			"table": "trip_transactions",
			"policy": "Users can insert their own trip transactions",
			"cmd": "INSERT",
			"roles": [
				"public"
			],
			"using": null,
			"check": "(auth.uid() = user_id)"
		},
		{
			"table": "trip_transactions",
			"policy": "Users can update their own trip transactions",
			"cmd": "UPDATE",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": "(auth.uid() = user_id)"
		},
		{
			"table": "trip_transactions",
			"policy": "Users can view their own trip transactions",
			"cmd": "SELECT",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		},
		{
			"table": "trips",
			"policy": "Users can delete their own trips",
			"cmd": "DELETE",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		},
		{
			"table": "trips",
			"policy": "Users can insert their own trips",
			"cmd": "INSERT",
			"roles": [
				"public"
			],
			"using": null,
			"check": "(auth.uid() = user_id)"
		},
		{
			"table": "trips",
			"policy": "Users can update their own trips",
			"cmd": "UPDATE",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": "(auth.uid() = user_id)"
		},
		{
			"table": "trips",
			"policy": "Users can view their own trips",
			"cmd": "SELECT",
			"roles": [
				"public"
			],
			"using": "(auth.uid() = user_id)",
			"check": null
		}
	],
	"columns": [
		{
			"table": "owo_entries",
			"column": "created_at",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": "now()"
		},
		{
			"table": "trip_transactions",
			"column": "user_id",
			"type": "uuid",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "owo_entries",
			"column": "updated_at",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": "now()"
		},
		{
			"table": "trip_transactions",
			"column": "amount",
			"type": "numeric",
			"nullable": "NO",
			"default": "0"
		},
		{
			"table": "transactions",
			"column": "id",
			"type": "uuid",
			"nullable": "NO",
			"default": "gen_random_uuid()"
		},
		{
			"table": "trip_transactions",
			"column": "date",
			"type": "timestamp with time zone",
			"nullable": "NO",
			"default": "now()"
		},
		{
			"table": "transactions",
			"column": "user_id",
			"type": "uuid",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "owo_entries",
			"column": "id",
			"type": "uuid",
			"nullable": "NO",
			"default": "gen_random_uuid()"
		},
		{
			"table": "trip_transactions",
			"column": "is_split",
			"type": "boolean",
			"nullable": "NO",
			"default": "false"
		},
		{
			"table": "trip_transactions",
			"column": "split_count",
			"type": "integer",
			"nullable": "NO",
			"default": "1"
		},
		{
			"table": "trip_transactions",
			"column": "created_at",
			"type": "timestamp with time zone",
			"nullable": "NO",
			"default": "now()"
		},
		{
			"table": "trip_transactions",
			"column": "updated_at",
			"type": "timestamp with time zone",
			"nullable": "NO",
			"default": "now()"
		},
		{
			"table": "owo_entries",
			"column": "user_id",
			"type": "uuid",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "trips",
			"column": "user_id",
			"type": "uuid",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "budgets",
			"column": "id",
			"type": "uuid",
			"nullable": "NO",
			"default": "gen_random_uuid()"
		},
		{
			"table": "trips",
			"column": "budget",
			"type": "numeric",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "transactions",
			"column": "amount",
			"type": "numeric",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "trips",
			"column": "category_budgets",
			"type": "jsonb",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "trips",
			"column": "created_at",
			"type": "timestamp with time zone",
			"nullable": "NO",
			"default": "now()"
		},
		{
			"table": "trips",
			"column": "updated_at",
			"type": "timestamp with time zone",
			"nullable": "NO",
			"default": "now()"
		},
		{
			"table": "budgets",
			"column": "user_id",
			"type": "uuid",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "trips",
			"column": "start_date",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "trips",
			"column": "end_date",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "transactions",
			"column": "date",
			"type": "timestamp with time zone",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "budgets",
			"column": "amount",
			"type": "numeric",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "budgets",
			"column": "created_at",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": "now()"
		},
		{
			"table": "transactions",
			"column": "is_split",
			"type": "boolean",
			"nullable": "YES",
			"default": "false"
		},
		{
			"table": "transactions",
			"column": "split_count",
			"type": "integer",
			"nullable": "YES",
			"default": "1"
		},
		{
			"table": "transactions",
			"column": "created_at",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": "now()"
		},
		{
			"table": "transactions",
			"column": "updated_at",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": "now()"
		},
		{
			"table": "categories",
			"column": "id",
			"type": "uuid",
			"nullable": "NO",
			"default": "gen_random_uuid()"
		},
		{
			"table": "categories",
			"column": "user_id",
			"type": "uuid",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "owo_entries",
			"column": "amount",
			"type": "numeric",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "categories",
			"column": "created_at",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": "now()"
		},
		{
			"table": "categories",
			"column": "updated_at",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": "now()"
		},
		{
			"table": "budgets",
			"column": "updated_at",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": "now()"
		},
		{
			"table": "owo_entries",
			"column": "due_date",
			"type": "timestamp with time zone",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "user_settings",
			"column": "user_id",
			"type": "uuid",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "user_settings",
			"column": "initial_balance",
			"type": "numeric",
			"nullable": "YES",
			"default": "0.0"
		},
		{
			"table": "user_settings",
			"column": "updated_at",
			"type": "timestamp with time zone",
			"nullable": "NO",
			"default": "timezone('utc'::text, now())"
		},
		{
			"table": "owo_entries",
			"column": "settled",
			"type": "boolean",
			"nullable": "YES",
			"default": "false"
		},
		{
			"table": "trips",
			"column": "name",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "budgets",
			"column": "category",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "owo_entries",
			"column": "owo_id",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "owo_entries",
			"column": "counterparty",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "owo_entries",
			"column": "direction",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "owo_entries",
			"column": "note",
			"type": "text",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "transactions",
			"column": "transaction_id",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "transactions",
			"column": "description",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "transactions",
			"column": "type",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "transactions",
			"column": "category",
			"type": "text",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "transactions",
			"column": "status",
			"type": "text",
			"nullable": "YES",
			"default": "'Completed'::text"
		},
		{
			"table": "categories",
			"column": "name",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "categories",
			"column": "color",
			"type": "text",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "categories",
			"column": "icon",
			"type": "text",
			"nullable": "YES",
			"default": null
		},
		{
			"table": "trip_transactions",
			"column": "transaction_id",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "trip_transactions",
			"column": "trip_id",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "trip_transactions",
			"column": "description",
			"type": "text",
			"nullable": "NO",
			"default": "''::text"
		},
		{
			"table": "trip_transactions",
			"column": "type",
			"type": "text",
			"nullable": "NO",
			"default": "'Debit'::text"
		},
		{
			"table": "trip_transactions",
			"column": "category",
			"type": "text",
			"nullable": "NO",
			"default": "''::text"
		},
		{
			"table": "trip_transactions",
			"column": "status",
			"type": "text",
			"nullable": "NO",
			"default": "'Completed'::text"
		},
		{
			"table": "trips",
			"column": "trip_id",
			"type": "text",
			"nullable": "NO",
			"default": null
		},
		{
			"table": "trips",
			"column": "categories",
			"type": "ARRAY",
			"nullable": "NO",
			"default": "'{}'::text[]"
		},
		{
			"table": "trips",
			"column": "description",
			"type": "text",
			"nullable": "YES",
			"default": null
		}
	]
}

## 4. Verified findings

- RLS is enabled on all 7 tables: budgets, owo_entries, transactions,
  categories, user_settings, trip_transactions, trips.
- All policies are scoped to auth.uid() = user_id.
- No duplicate category names exist (checked 2026-10-04).
- transactions has UNIQUE (user_id, transaction_id).
- categories has NO unique constraint on (user_id, name).
- trips and trip_transactions have text primary keys not scoped per user.
- Triggers: not checked.