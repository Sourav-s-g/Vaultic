CREATE OR REPLACE FUNCTION public.set_transactions_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS transactions_set_updated_at ON public.transactions;

CREATE TRIGGER transactions_set_updated_at
BEFORE UPDATE ON public.transactions
FOR EACH ROW
EXECUTE FUNCTION public.set_transactions_updated_at();

-- Rollback:
-- DROP TRIGGER IF EXISTS transactions_set_updated_at ON public.transactions;
-- DROP FUNCTION IF EXISTS public.set_transactions_updated_at();
