create or replace function public.delete_category(p_category_name text)
 returns void
 language plpgsql
 set search_path to ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_category_id uuid;
  v_stored_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to delete a category.'
      using errcode = '42501';
  end if;

  if p_category_name is null or btrim(p_category_name) = '' then
    raise exception 'A category name is required.'
      using errcode = '22023';
  end if;

  select c.id, c.name
    into v_category_id, v_stored_name
    from public.categories as c
   where c.user_id = v_user_id
     and lower(btrim(c.name)) = lower(btrim(p_category_name))
   limit 1;

  if v_category_id is null then
    return;
  end if;

  delete from public.budgets as b
   where b.user_id = v_user_id
     and lower(btrim(b.category)) = lower(btrim(v_stored_name));

  delete from public.categories as c
   where c.user_id = v_user_id
     and c.id = v_category_id;
end;
$function$;