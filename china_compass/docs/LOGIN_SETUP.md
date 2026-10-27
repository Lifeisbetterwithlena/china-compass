# Email login: what you need to set up

The app signs people in without a password: they type their email, get a 6-digit code by email, and enter it.
Sending that email needs a server. The app uses **Supabase** for this. It's free to start and has this
"email code" login built in. Until it is set up, the app runs in **demo mode**: no email is sent and the
code is shown on screen.

## 1. Create a Supabase project (you do this, about 10 minutes)

1. Sign up at <https://supabase.com> and create a new project.
   Pick a region close to your users, e.g. **Singapore** or **Tokyo** for users in China.
2. In **Authentication → Sign In / Providers**, make sure **Email** is enabled.

## 2. Make the email contain a code, not a link

By default Supabase sends a "magic link". To send a code instead:

1. Go to **Authentication → Emails → Templates → Magic Link**.
2. Replace the body with something like:

   ```html
   <h2>Your China Compass code</h2>
   <p>Enter this code in the app: <strong>{{ .Token }}</strong></p>
   <p>It expires in 1 hour. If you didn't request it, you can ignore this email.</p>
   ```

3. In **Authentication → Providers → Email**, check that the code length is **6** digits.

## 3. Set up your own email sender (needed before real users)

Supabase's built-in email sender is only for testing: it sends just a few emails per hour, and only to
members of your Supabase team. For real users, connect an email service under
**Authentication → Emails → SMTP Settings**, for example **Resend**, **Brevo** or **Amazon SES**.
You'll need your own domain (e.g. `chinacompass.app`) so emails don't land in spam.
Test with Chinese mailboxes (QQ Mail, 163.com) too, because they filter strictly.

## 4. Connect the app ✅ done

The project URL and publishable key are in `supabase.json`. Run or build the app with:

```bash
flutter run --dart-define-from-file=supabase.json
```

The publishable key is meant to live inside apps, so this is safe. Never put the **secret** key in the app.
The project currently runs in **East US**. Moving it to Singapore or Tokyo would make login faster in China.

## 5. Create the table for saved progress

All progress (ticked steps, saved steps and guides, language) is saved to the account in a table
called `user_items`. Each user can only read and change their own rows (Row Level Security).

1. In Supabase, open **SQL Editor → New query**.
2. Paste the whole content of `supabase/migrations/20261027_user_items.sql` and click **Run**.
3. It should say "Success. No rows returned".

This also adds the `delete_my_account` function behind **Profile → Delete account**.

## What's not done yet

- **Own email sender and domain** (step 3), needed before real users can sign in.
- **Region:** the project runs in East US; Singapore or Tokyo would make sign-in and syncing faster in China.
- **Privacy policy** covering stored emails and progress (required by the app stores and GDPR).
- Test from inside China, without a VPN, before launch.
