// Public browser configuration only. Never put a Supabase secret key here.
const ALEE_SUPABASE_URL = 'https://derjgoyscmkwnmpblchy.supabase.co';
const ALEE_SUPABASE_ANON_KEY = 'sb_publishable_jciYZSmbB8EVt60die2Grg__nSgGoxK';

if (window.supabase?.createClient && ALEE_SUPABASE_URL && ALEE_SUPABASE_ANON_KEY) {
  window.aleeSupabase = window.supabase.createClient(ALEE_SUPABASE_URL, ALEE_SUPABASE_ANON_KEY);
} else {
  window.aleeSupabase = null;
}
