CREATE OR REPLACE FUNCTION public.delete_category(p_category_name text)
RETURNS void
LANGUAGE plpgsql
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_category_id uuid;
  v_stored_name text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required to delete a category.'
      USING ERRCODE = '42501';
  END IF;

  IF p_category_name IS NULL OR btrim(p_category_name) = '' THEN
    RAISE EXCEPTION 'A category name is required.'
      USING ERRCODE = '22023';
  END IF;

  SELECT c.id, c.name
    INTO v_category_id, v_stored_name
    FROM public.categories AS c
   WHERE c.user_id = v_user_id
     AND lower(btrim(c.name)) = lower(btrim(p_category_name))
   LIMIT 1;

  IF v_category_id IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM public.budgets AS b
   WHERE b.user_id = v_user_id
     AND b.category = v_stored_name;

  DELETE FROM public.categories AS c
   WHERE c.user_id = v_user_id
     AND c.id = v_category_id;
END;
$function$;

-- Rollback:
-- DROP FUNCTION IF EXISTS public.delete_category(text);
