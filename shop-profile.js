(() => {
  const shops = Array.isArray(window.aleeShops) ? window.aleeShops : [];
  const products = Array.isArray(window.aleeProducts) ? window.aleeProducts : [];
  const params = new URLSearchParams(location.search);
  const shopId = params.get('shop');
  const supabase = window.aleeSupabase || null;
  let shop = shops.find(item => String(item.id) === shopId) || null;
  let currentUser = null;
  let followerCount = 0;
  let followingCount = 0;
  let isFollowing = false;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const isUuid = value => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value || ''));
  const profileOverlay = document.getElementById('profileOverlay');
  const profileStatus = () => document.getElementById('profileStatus');
  let profileDialogHistoryOpen = false;
  let shareDialogHistoryOpen = false;

  function setTheme(dark) {
    document.documentElement.dataset.theme = dark ? 'dark' : 'light';
    const button = document.getElementById('themeToggle');
    button.innerHTML = `<i class="fa-solid ${dark ? 'fa-sun' : 'fa-moon'}"></i>`;
    button.setAttribute('aria-label', dark ? 'Switch to light mode' : 'Switch to dark mode');
    try { localStorage.setItem('alee-shop-theme', dark ? 'dark' : 'light'); } catch (_) {}
  }
  try { setTheme(localStorage.getItem('alee-shop-theme') === 'dark'); } catch (_) { setTheme(false); }
  document.getElementById('themeToggle').addEventListener('click', () => setTheme(document.documentElement.dataset.theme !== 'dark'));

  function openProfileDialog(title, content) {
    if (!profileOverlay.classList.contains('show')) { history.pushState({...history.state,aleeShopProfileDialog:true},'',location.href); profileDialogHistoryOpen = true; }
    document.getElementById('profileDialogTitle').textContent = title;
    document.getElementById('profileDialogContent').innerHTML = content;
    profileOverlay.classList.add('show');
    profileOverlay.setAttribute('aria-hidden', 'false');
    document.getElementById('profileClose').focus();
  }
  function closeProfileDialog(fromHistory = false) {
    profileOverlay.classList.remove('show');
    profileOverlay.setAttribute('aria-hidden', 'true');
    if (profileDialogHistoryOpen) { profileDialogHistoryOpen = false; if (!fromHistory) history.back(); }
  }
  document.getElementById('profileClose').addEventListener('click', closeProfileDialog);
  profileOverlay.addEventListener('click', event => { if (event.target === profileOverlay) closeProfileDialog(); });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') { closeProfileDialog(); closeShareDialog(); }
  });

  function shareUrl() {
    const url = new URL('shop.html', location.href);
    url.searchParams.set('shop', String(shop.id));
    return url.href;
  }
  async function copyShopLink() {
    const status = document.getElementById('shareStatus');
    try {
      if (navigator.clipboard && window.isSecureContext) await navigator.clipboard.writeText(shareUrl());
      else {
        const input = document.createElement('textarea'); input.value = shareUrl();
        input.style.position = 'fixed'; input.style.opacity = '0'; document.body.appendChild(input);
        input.select(); const copied = document.execCommand('copy'); input.remove();
        if (!copied) throw new Error('Copy unavailable');
      }
      status.textContent = 'Profile link copied.'; return true;
    } catch (_) { status.textContent = 'Copy the profile link shown above.'; return false; }
  }
  function openShareDialog() {
    const overlay = document.getElementById('shareOverlay'), qr = document.getElementById('shareQr');
    if (!overlay.classList.contains('show')) { history.pushState({...history.state,aleeShopShareDialog:true},'',location.href); shareDialogHistoryOpen = true; }
    overlay.classList.add('show'); overlay.setAttribute('aria-hidden', 'false');
    document.getElementById('shareTitle').textContent = `Share ${shop.name}`;
    document.getElementById('shareUrl').textContent = shareUrl();
    document.getElementById('shareStatus').textContent = '';
    qr.replaceChildren();
    if (window.QRCode) new QRCode(qr, {text:shareUrl(), width:204, height:204, colorDark:'#111827', colorLight:'#fff', correctLevel:QRCode.CorrectLevel.M});
    else qr.textContent = 'QR code could not load. Use Copy link below.';
    document.getElementById('copyShopLink').focus();
  }
  function closeShareDialog(fromHistory = false) {
    const overlay = document.getElementById('shareOverlay');
    if (!overlay) return;
    overlay.classList.remove('show'); overlay.setAttribute('aria-hidden', 'true');
    if (shareDialogHistoryOpen) { shareDialogHistoryOpen = false; if (!fromHistory) history.back(); }
  }
  window.addEventListener('popstate', event => {
    if (shareDialogHistoryOpen && !event.state?.aleeShopShareDialog) { closeShareDialog(true); return; }
    if (profileDialogHistoryOpen && !event.state?.aleeShopProfileDialog) closeProfileDialog(true);
  });

  function refreshProfileStats() {
    const followers = document.querySelector('#followersStat strong');
    const following = document.querySelector('#followingStat strong');
    const followButton = document.getElementById('followButton');
    if (followers) followers.textContent = String(followerCount);
    if (following) following.textContent = String(followingCount);
    if (followButton) { followButton.textContent = isFollowing ? 'Following' : 'Follow'; followButton.classList.toggle('is-following', isFollowing); }
  }

  function renderContact() {
    const parts = [];
    const phone = String(shop.phone || '').trim(), phone2 = String(shop.phone2 || '').trim();
    if (phone) {
      parts.push(`<a href="tel:${encodeURIComponent(phone)}"><i class="fa-solid fa-phone"></i><span>${esc(phone)}</span></a>`);
      const wa = phone.replace(/\D/g, '');
      if (wa) parts.push(`<a href="https://wa.me/${encodeURIComponent(wa)}" target="_blank" rel="noopener noreferrer"><i class="fa-brands fa-whatsapp"></i><span>WhatsApp</span></a>`);
    }
    if (phone2) parts.push(`<a href="tel:${encodeURIComponent(phone2)}"><i class="fa-solid fa-phone"></i><span>${esc(phone2)}</span></a>`);
    if (shop.address) parts.push(`<a href="https://maps.google.com/?q=${encodeURIComponent(shop.address)}" target="_blank" rel="noopener noreferrer"><i class="fa-solid fa-location-dot"></i><span>${esc(shop.address)}</span></a>`);
    if (/^https?:\/\//i.test(String(shop.externalLink || ''))) parts.push(`<a href="${esc(shop.externalLink)}" target="_blank" rel="noopener noreferrer"><i class="fa-solid fa-link"></i><span>Website / shop link</span></a>`);
    for (const [key, label, icon] of [['facebook','Facebook','fa-facebook'],['instagram','Instagram','fa-instagram'],['youtube','YouTube','fa-youtube'],['tiktok','TikTok','fa-tiktok']]) {
      if (/^https?:\/\//i.test(String(shop[key] || ''))) parts.push(`<a href="${esc(shop[key])}" target="_blank" rel="noopener noreferrer"><i class="fa-brands ${icon}"></i><span>${label}</span></a>`);
    }
    openProfileDialog('Contact', `<div class="contact-details">${parts.length ? parts.join('') : '<p>Contact details have not been added yet.</p>'}</div>`);
  }

  async function getBusinessStats() {
    if (!supabase || !isUuid(shop.id)) return;
    const {data, error} = await supabase.rpc('get_shop_social_data', {p_shop_id:shop.id});
    if (error) { console.warn('Follow features need the updated seller profile schema.', error.message); return; }
    const row = Array.isArray(data) ? data[0] : data;
    if (row) {
      followerCount = Number(row.follower_count || 0);
      followingCount = Number(row.following_count || 0);
      isFollowing = Boolean(row.is_following);
      refreshProfileStats();
    }
  }
  function labelForUser(user) {
    const metadata = user?.user_metadata || {};
    return String(metadata.full_name || metadata.name || metadata.display_name || metadata.user_name || 'Shopper').slice(0,80);
  }
  async function toggleFollow() {
    const status = profileStatus();
    if (!isUuid(shop.id)) { status.textContent = 'Following is available for seller profiles connected to Supabase.'; return; }
    if (!currentUser) { status.textContent = 'Sign in on the home page, then return here to follow this shop.'; return; }
    const button = document.getElementById('followButton'); button.disabled = true;
    const {error} = isFollowing
      ? await supabase.rpc('unfollow_shop', {p_shop_id:shop.id})
      : await supabase.rpc('follow_shop', {p_shop_id:shop.id, p_follower_name:labelForUser(currentUser)});
    button.disabled = false;
    if (error) { status.textContent = 'Could not update Follow. Run the updated seller profile SQL, then try again.'; return; }
    isFollowing = !isFollowing;
    followerCount += isFollowing ? 1 : -1;
    refreshProfileStats();
  }
  async function showFollowers() {
    if (!isUuid(shop.id) || !supabase) { openProfileDialog('Followers', '<p>Follower details are not available for this shop yet.</p>'); return; }
    openProfileDialog('Followers', '<p>Loading followers…</p>');
    const {data,error} = await supabase.rpc('get_shop_followers', {p_shop_id:shop.id});
    if (error) { document.getElementById('profileDialogContent').innerHTML='<p>Run the updated seller profile SQL to view followers.</p>'; return; }
    const rows = data || [];
    document.getElementById('profileDialogContent').innerHTML = rows.length
      ? `<div class="profile-list">${rows.map(row=>`<div class="profile-list-item"><img src="assets/alee-logo.png" alt=""><span>${esc(row.follower_name||'Shopper')}</span></div>`).join('')}</div>`
      : '<p>No followers yet.</p>';
  }
  async function showFollowing() {
    if (!isUuid(shop.id) || !supabase) { openProfileDialog('Following', '<p>Following details are not available for this shop yet.</p>'); return; }
    openProfileDialog('Following', '<p>Loading shops…</p>');
    const {data,error} = await supabase.rpc('get_shop_following', {p_shop_id:shop.id});
    if (error) { document.getElementById('profileDialogContent').innerHTML='<p>Run the updated seller profile SQL to view following.</p>'; return; }
    const rows = data || [];
    document.getElementById('profileDialogContent').innerHTML = rows.length
      ? `<div class="profile-list">${rows.map(row=>`<a class="profile-list-item" href="shop.html?shop=${encodeURIComponent(row.id)}"><img src="${esc(row.logo_url||'assets/alee-logo.png')}" alt=""><span>${esc(row.shop_name)}</span></a>`).join('')}</div>`
      : '<p>This business is not following any shops yet.</p>';
  }

  function renderProfile() {
    if (!shop) {
      document.getElementById('shopProfile').innerHTML = '<div class="empty"><h2>Business profile not found</h2><p>Return to ALEE SHOPPING and choose a shop.</p></div>';
      document.getElementById('products').innerHTML = ''; return;
    }
    document.documentElement.style.setProperty('--shop-accent', /^#[0-9a-f]{6}$/i.test(shop.accentColor || '') ? shop.accentColor : '#ff6900');
    document.title = `${shop.name} — ALEE SHOPPING`;
    document.getElementById('headerShopName').textContent = shop.name;
    document.getElementById('headerShopLogo').src = shop.logo || 'assets/alee-logo.png';
    const items = products.filter(item => String(item.shopId || shops[0]?.id || 'alee-shopping') === String(shop.id));
    document.getElementById('shopProfile').innerHTML = `<div class="profile-top"><img class="profile-avatar" src="${esc(shop.logo||'assets/alee-logo.png')}" alt="${esc(shop.name)} logo" decoding="async" fetchpriority="high" onerror="this.onerror=null;this.src='assets/alee-logo.png'"><div class="profile-identity"><h2 class="profile-name">${esc(shop.name)}</h2><div class="profile-stats"><button class="profile-stat" id="adsStat" type="button"><strong>${items.length}</strong><span>ads</span></button><button class="profile-stat" id="followersStat" type="button"><strong>${followerCount}</strong><span>followers</span></button><button class="profile-stat" id="followingStat" type="button"><strong>${followingCount}</strong><span>following</span></button></div></div></div><div class="profile-bio"><span class="bio-category">${esc(shop.shopCategory||'Business')}</span>${esc(shop.bio||'')}</div><div class="profile-buttons"><button class="follow-button ${isFollowing?'is-following':''}" id="followButton" type="button">${isFollowing?'Following':'Follow'}</button><button id="contactButton" type="button">Contact</button><button id="openShare" type="button">Share profile</button></div><div class="profile-status" id="profileStatus" role="status" aria-live="polite"></div>`;
    document.getElementById('followersStat').addEventListener('click', showFollowers);
    document.getElementById('followingStat').addEventListener('click', showFollowing);
    document.getElementById('adsStat').addEventListener('click', () => document.getElementById('products').scrollIntoView({behavior:'smooth', block:'start'}));
    document.getElementById('followButton').addEventListener('click', toggleFollow);
    document.getElementById('contactButton').addEventListener('click', renderContact);
    document.getElementById('openShare').addEventListener('click', openShareDialog);
    document.getElementById('products').innerHTML = items.length ? items.map(item => `<a class="card" href="index.html?product=${encodeURIComponent(item.id)}"><img src="${esc(item.images?.[0]||'assets/alee-logo.png')}" alt="${esc(item.name)}" loading="lazy" decoding="async" onerror="this.onerror=null;this.src='assets/alee-logo.png'"><div class="shop-meta"><span>${esc(shop.name)}</span></div><h3>${esc(item.name)}</h3><div class="price">LKR ${Number(item.price||0).toLocaleString()}</div></a>`).join('') : '<div class="empty">This business has no ads yet.</div>';
  }

  async function loadShop() {
    if (!shop && supabase && shopId && isUuid(shopId)) {
      const {data:row,error} = await supabase.from('seller_shops_profile_public').select('*').eq('id',shopId).maybeSingle();
      if (!error && row) {
        shop = {id:String(row.id), name:row.shop_name, logo:row.logo_url||'assets/alee-logo.png', phone:row.phone||'', phone2:row.phone2||'', address:row.address||'', externalLink:row.external_link||'', shopCategory:row.shop_category||'Other', bio:row.bio||'', facebook:row.facebook_url||'', instagram:row.instagram_url||'', youtube:row.youtube_url||'', tiktok:row.tiktok_url||'', rank:9999, rating:5};
        const {data:items} = await supabase.from('seller_products_profile_public').select('*').eq('shop_id',shopId);
        (items||[]).forEach(item=>products.push({id:1000000000+Number(item.id),name:item.name,price:Number(item.price),category:item.category,shopId:String(item.shop_id),desc:item.description||'',features:item.features||[],sizes:item.sizes||[],images:item.image_urls||[]}));
        shops.push(shop);
      }
    }
    if (supabase) {
      try { const {data}=await supabase.auth.getUser(); currentUser=data?.user||null; } catch (_) {}
    }
    renderProfile();
    if (shop && supabase) await getBusinessStats();
  }

  document.getElementById('shareClose').addEventListener('click', closeShareDialog);
  document.getElementById('shareOverlay').addEventListener('click', event => { if (event.target.id === 'shareOverlay') closeShareDialog(); });
  document.getElementById('copyShopLink').addEventListener('click', copyShopLink);
  document.getElementById('shareOptions').addEventListener('click', async event => {
    const button = event.target.closest('[data-share]'); if (!button) return;
    const target = button.dataset.share, url = shareUrl(), title = `Check out ${shop.name}`;
    if (target === 'more') {
      try { if (!navigator.share) throw new Error('Unavailable'); await navigator.share({title:shop.name,text:title,url}); document.getElementById('shareStatus').textContent='Profile shared.'; }
      catch (error) { if (error.name !== 'AbortError') document.getElementById('shareStatus').textContent='Use Copy link to share this profile.'; }
    } else if (target === 'whatsapp') window.open(`https://wa.me/?text=${encodeURIComponent(`${title}: ${url}`)}`,'_blank','noopener,noreferrer');
    else if (target === 'facebook') window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`,'_blank','noopener,noreferrer');
    else { const pages={instagram:'https://www.instagram.com/',tiktok:'https://www.tiktok.com/',youtube:'https://www.youtube.com/'}; const opened=window.open(pages[target],'_blank','noopener,noreferrer'); await copyShopLink(); if(opened)document.getElementById('shareStatus').textContent=`Profile link copied. Paste it into ${button.textContent.trim()}.`; }
  });
  const loader=document.getElementById('siteLoader');
  const hideLoader=()=>loader?.classList.add('hidden');
  window.setTimeout(hideLoader,8000);
  loadShop().catch(error=>{console.error(error);renderProfile();}).finally(hideLoader);
})();
