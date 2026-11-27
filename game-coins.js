(() => {
  const client = window.aleeSupabase;
  const gameKey = document.body?.dataset.gameKey;
  const balanceEl = document.getElementById('coinBalance');
  const statusEl = document.getElementById('coinStatus');
  const loginLink = document.getElementById('coinLogin');
  if (!balanceEl || !statusEl) return;

  const setStatus = (message, state = '') => {
    statusEl.textContent = message;
    statusEl.dataset.state = state;
  };

  async function refresh() {
    if (!client) {
      balanceEl.textContent = '—';
      setStatus('Account connection is unavailable.');
      return;
    }
    try {
      const { data: { session }, error: sessionError } = await client.auth.getSession();
      if (sessionError) throw sessionError;
      const user = session?.user;
      if (!user) {
        balanceEl.textContent = '—';
        if (loginLink) loginLink.hidden = false;
        setStatus('Sign in to save game coins to your account.');
        return;
      }
      if (loginLink) loginLink.hidden = true;
      const { data, error } = await client.from('alee_game_coin_wallets')
        .select('balance').eq('user_id', user.id).maybeSingle();
      if (error) throw error;
      balanceEl.textContent = String(data?.balance ?? 0);
      setStatus('Complete a game to earn today’s coin.', 'success');
    } catch (error) {
      balanceEl.textContent = '—';
      setStatus('Run game-coins-schema.sql in Supabase to set up saved coins.', 'error');
      console.warn('Could not load the ALEE game coin wallet.', error);
    }
  }

  async function claim() {
    if (!client) {
      setStatus('Account connection is unavailable; this coin was not saved.', 'error');
      return false;
    }
    try {
      const { data: { session }, error: sessionError } = await client.auth.getSession();
      if (sessionError) throw sessionError;
      if (!session?.user) {
        if (loginLink) loginLink.hidden = false;
        setStatus('Sign in to ALEE Shopping to save your game coin.', 'error');
        return false;
      }
      setStatus('Saving your game coin…');
      const { data, error } = await client.rpc('claim_alee_game_coin', { p_game_key: gameKey });
      if (error) throw error;
      const result = Array.isArray(data) ? data[0] : data;
      if (!result || typeof result.balance === 'undefined') throw new Error('The coin response was incomplete.');
      balanceEl.textContent = String(result.balance);
      if (Number(result.awarded) > 0) setStatus('🪙 +1 coin saved to your ALEE account!', 'reward');
      else setStatus('You already collected today’s coin for this game.', 'success');
      return Number(result.awarded) > 0;
    } catch (error) {
      setStatus('Could not save coins. Make sure game-coins-schema.sql has been run.', 'error');
      console.warn('Could not save the ALEE game coin.', error);
      return false;
    }
  }

  window.aleeGameCoins = { refresh, claim };
  refresh();
  client?.auth.onAuthStateChange(() => { window.setTimeout(refresh, 0); });
})();
