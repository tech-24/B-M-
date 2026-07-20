# Business Manager — Web Dashboard

Standalone web dashboard for Business Manager, backed by Supabase
(cloud database + email/password login). Independent from the mobile
app — no shared code path, no shared data storage mechanism.

## First-time setup

1. Run `supabase_schema.sql` once in your Supabase project's SQL Editor.
2. Push this repo to GitHub.
3. In the repo's **Settings -> Pages**, set "Build and deployment" source
   to **GitHub Actions**.
4. Every push to `main` automatically builds and publishes the dashboard
   to `https://<your-username>.github.io/<this-repo-name>/`.

## Local development

```
flutter create . --platforms=web   # only needed once, if web/ doesn't exist
flutter pub get
flutter run -d chrome
```
