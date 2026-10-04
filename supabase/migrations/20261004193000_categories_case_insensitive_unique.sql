CREATE UNIQUE INDEX IF NOT EXISTS categories_user_id_lower_name_key
  ON public.categories (user_id, lower(name));
