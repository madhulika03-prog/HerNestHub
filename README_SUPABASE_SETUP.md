HerNest Hub — Supabase integration (local prep)

This document lists the files added locally and step-by-step instructions to create the Supabase project, run the SQL schema, deploy Edge Functions, and configure environment variables.

Files added locally (no keys, no deployment):
- `supabase/schema.sql` — PostgreSQL schema and RLS examples
- `supabase/functions/createBooking/index.ts` — Edge Function to create bookings
- `supabase/functions/requestVisit/index.ts` — Edge Function to submit visit requests
- `supabase/functions/createInquiry/index.ts` — Edge Function to submit contact inquiries
- `frontend/supabase-client.js` — Frontend helper wrappers for calling Edge Functions
- `.env.example` — Example environment variables

What you need to create in Supabase (manual steps):
1. Create a Supabase project at https://app.supabase.com
2. Obtain these values from Project Settings → API:
   - `SUPABASE_URL` (Project URL)
   - `SUPABASE_ANON_KEY` (anon/public key)
   - `SUPABASE_SERVICE_ROLE_KEY` (Service Role key — keep secret and server-side only)
3. Open the SQL editor in Supabase and run the SQL from `supabase/schema.sql`.

Deploy Edge Functions (recommended):
1. Install the Supabase CLI: https://supabase.com/docs/guides/cli
2. Login: `supabase login`
3. Link to your project: `supabase link --project-ref <your-project-ref>`
4. From the project root, deploy functions:

```bash
supabase functions deploy createBooking --project-ref <your-project-ref>
supabase functions deploy requestVisit --project-ref <your-project-ref>
supabase functions deploy createInquiry --project-ref <your-project-ref>
```

5. Optionally set secrets for your functions (service role key) — recommended so functions can use the Service Role key without embedding it in code:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="<your-service-role-key>"
```

Notes on environment variables and where they are used:
- `SUPABASE_URL` — used by both frontend (anon key) and Edge Functions.
- `SUPABASE_ANON_KEY` — used by the frontend for public operations and auth; safe to use client-side.
- `SUPABASE_SERVICE_ROLE_KEY` — used only by Edge Functions (server-side). Do NOT expose this in the frontend.
- `SUPABASE_FUNCTIONS_BASE_URL` — base URL where your Edge Functions live (e.g. https://<project>.functions.supabase.co)

Row-Level Security guidance:
- The SQL includes example RLS policies that allow public inserts for `bookings`, `pg_visit_requests`, and `inquiries` but block reads/updates by anonymous users.
- For production, prefer requiring authentication for sensitive actions and implement admin-only update policies. Use Edge Functions with the service role key for privileged operations (status updates, manual approvals).

How to wire the frontend (`index.html`) without changing UI layout:
- Include `frontend/supabase-client.js` in `index.html` near the bottom, after existing scripts.
- Configure runtime values (either replace placeholders or inject at deploy time):
  - `window.SUPABASE_FUNCTIONS_BASE_URL = 'https://<your>.functions.supabase.co'`
  - Optionally, initialize a Supabase client for auth using `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- Hook existing form submit handlers to call `window.HerNestHub.submitBooking(payload)`, `submitVisitRequest(payload)`, or `submitInquiry(payload)`.

Testing the booking flow locally (suggested):
1. Locally run the Supabase stack (requires supabase CLI):

```bash
supabase start
```

2. Deploy functions locally or call the hosted function endpoint. For local function testing, you can run functions with the CLI and call `http://localhost:54321/functions/v1/<functionName>`.

3. In your browser devtools console, test the client helper:

```js
window.SUPABASE_FUNCTIONS_BASE_URL = 'http://localhost:54321/functions/v1'
HerNestHub.submitBooking({
  customer: { name: 'Test', email: 'test@example.com', phone: '123' },
  package_id: null,
  room_id: null,
  bed_id: null,
  move_in_date: '2026-09-01'
}).then(console.log).catch(console.error)
```

What I will do next if you confirm:
- Update `index.html` wiring code (without UI changes) to call the helpers when booking/visit/contact forms submit, preserving existing behavior.
- Add minimal examples in `index.html` (non-destructive) showing how to connect form submit events to `HerNestHub` helpers.

If you want me to proceed with wiring the forms now, confirm and I will inject unobtrusive JS that hooks form submissions to the Edge Function helpers (no keys added).