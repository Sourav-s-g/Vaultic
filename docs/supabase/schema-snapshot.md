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
