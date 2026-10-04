CREATE UNIQUE INDEX IF NOT EXISTS categories_user_name_ci_key
  ON public.categories (user_id, lower(btrim(name)));

-- Rollback:
-- DROP INDEX IF EXISTS public.categories_user_name_ci_key;
