/// Supabase project connection details.
///
/// The "anon" key below is a PUBLIC key — it is meant to be embedded in
/// client apps (web/mobile) and is safe to commit. Actual data security
/// comes from Row Level Security policies in the database (see
/// supabase_schema.sql), not from hiding this key.
class SupabaseConfig {
  static const url = 'https://aegesrztrtfayunxfvnq.supabase.co';
  static const anonKey = 'sb_publishable_pbcgC2cLPvh1hUVjeCJlwA_S_bTgCvY';
}
