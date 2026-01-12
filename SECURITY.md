# GyattChores Security Guide

## Critical: Rotate Your Supabase Credentials

Your Supabase anon key was exposed in the source code. Follow these steps immediately:

### Step 1: Rotate the Anon Key in Supabase

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project (ukshxdoqgwoxobjdclpx)
3. Navigate to **Settings** > **API**
4. Under "Project API keys", click **Regenerate** next to the anon key
5. Confirm the action - this will invalidate the old key immediately

### Step 2: Update Your App

After rotating the key, update `index.html` line ~603:

```javascript
const supabase = window.supabase.createClient(
    'https://ukshxdoqgwoxobjdclpx.supabase.co',
    'YOUR_NEW_ANON_KEY_HERE'  // Replace with new key
);
```

### Step 3: Enable Row Level Security (RLS)

Run the SQL file to enable RLS on all tables:

1. Go to Supabase Dashboard > SQL Editor
2. Open `enable-rls-policies.sql`
3. Run the entire script
4. Verify by running:
   ```sql
   SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';
   ```

### Step 4: Verify Everything Works

1. Refresh the app in your browser
2. Test logging in
3. Test claiming a chore
4. Test admin approval

---

## Passwords Still Exposed

The app has hardcoded passwords in the source code:
- Login password: `0413` (line 608)
- Admin approval code: `7874` (line 609)

For now, these are visible to anyone who views source. For app store deployment, you should:

1. Implement Supabase Auth (email/password login)
2. Create admin and player roles
3. Move password verification to server-side

---

## Future Security Improvements

For app store deployment:

1. **Implement Supabase Auth**
   - User accounts for parents and kids
   - Proper session management
   - Role-based access control

2. **Move credentials to environment variables**
   - Use a build process (Vite, Next.js, etc.)
   - Keep secrets out of the frontend code

3. **Add COPPA compliance**
   - Privacy policy for children's data
   - Parental consent flow
   - Data retention policies

4. **Enable stricter RLS policies**
   - Once auth is implemented, update policies to check `auth.uid()`
   - Restrict admin actions to verified admin users
