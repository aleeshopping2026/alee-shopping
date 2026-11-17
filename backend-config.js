// Public browser configuration only. Never put a Supabase secret key here.
const ALEE_SUPABASE_URL = 'https://derjgoyscmkwnmpblchy.supabase.co';
const ALEE_SUPABASE_ANON_KEY = 'sb_publishable_jciYZSmbB8EVt60die2Grg__nSgGoxK';

const ALEE_AUTH_OPTIONS = {
  autoRefreshToken: true,
  persistSession: true,
  detectSessionInUrl: true
};
try { ALEE_AUTH_OPTIONS.storage = window.localStorage; } catch (_) {}

if (window.supabase?.createClient && ALEE_SUPABASE_URL && ALEE_SUPABASE_ANON_KEY) {
  window.aleeSupabase = window.supabase.createClient(ALEE_SUPABASE_URL, ALEE_SUPABASE_ANON_KEY, { auth: ALEE_AUTH_OPTIONS });
} else {
  window.aleeSupabase = null;
}
