# Supabase Setup Guide for GyattChores

Follow these steps to set up your Supabase database for GyattChores.

## Step 1: Create a Supabase Account

1. Go to [https://supabase.com](https://supabase.com)
2. Click **Start your project**
3. Sign up with GitHub, Google, or email

## Step 2: Create a New Project

1. Click **New Project**
2. Fill in the details:
   - **Name**: `gyattchores` (or whatever you prefer)
   - **Database Password**: Create a strong password (save this!)
   - **Region**: Choose closest to you (probably `West US (North California)`)
   - **Pricing Plan**: Free tier is perfect for this project
3. Click **Create new project**
4. Wait 2-3 minutes for the database to provision

## Step 3: Run the Database Schema

1. In your Supabase project dashboard, click **SQL Editor** in the left sidebar
2. Click **New query**
3. Open the `schema.sql` file from this project
4. Copy ALL the contents and paste into the SQL Editor
5. Click **Run** (or press Cmd/Ctrl + Enter)
6. You should see "Success. No rows returned" - this is good!

## Step 4: Verify Tables Were Created

1. Click **Table Editor** in the left sidebar
2. You should see three tables:
   - `players` (with Iris and Mateo already added)
   - `chores` (with 16 default chores)
   - `chore_completions` (empty for now)

## Step 5: Get Your API Credentials

1. Click **Settings** (gear icon) in the left sidebar
2. Click **API** under Project Settings
3. Find these two values:
   - **Project URL** (looks like `https://xxxxx.supabase.co`)
   - **anon public** key (under Project API keys - it's a long string)

4. **IMPORTANT**: Copy both of these values

## Step 6: Create Environment File

Come back to me and provide:
- Your Project URL
- Your anon public key

I'll help you set up the environment configuration in the app.

---

## Security Note

- The **anon public** key is safe to use in your frontend code
- Never commit your **service_role** key to Git
- The database password is only needed for direct database access (not for the app)

---

## Troubleshooting

**Tables didn't create?**
- Make sure you copied the ENTIRE schema.sql file
- Check for any red error messages in the SQL Editor
- You can run the query again (it will skip already created tables)

**Can't find API settings?**
- Look for the gear icon (⚙️) in the bottom left
- Then click "API" in the settings menu

---

Once you've completed these steps, come back and I'll integrate Supabase into your app!
