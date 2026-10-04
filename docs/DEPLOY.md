# First Deployment

The Next.js app is in `web-app/`. Configure the Vercel project root directory as `web-app/`. Do not set a production domain in source code or environment defaults.

1. In Vercel Project Settings → Environment Variables, add the values for the variables listed in [`web-app/.env.example`](../web-app/.env.example):
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`

   These are the Supabase project URL and public anon key. Do not add a service-role key to browser or public configuration. No other environment variables are currently required by the Phase 1 shell.
2. Deploy the Vercel project and copy the production URL assigned by Vercel.
3. In Supabase Dashboard → Authentication → URL Configuration:
   - Set **Site URL** to the production URL.
   - Add `<production-url>/reset-password` and `<production-url>/**` to **Redirect URLs**.
   - Add `https://*.vercel.app/**` as well if password reset should work on preview deployments.
4. Test the complete forgot-password flow on the deployed site: request a reset, verify the enumeration-safe response, open the email link, confirm it lands on the reset-password page, set a matching password of at least eight characters, then sign in with the new password. Verify expired or reused links offer a clear retry path.

After deployment, request `/api/health`. It returns only `{"status":"ok"}` and does not expose environment values or secrets.

## Build Checks

Run these from `web-app/`:

```sh
npm ci
npm run lint
npm run typecheck
npm run build
```

The GitHub Actions workflow uses `web-app/` as its explicit working directory. Root `web/` remains Flutter's web platform target.
