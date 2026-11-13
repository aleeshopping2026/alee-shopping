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
  let shopRating = 5;
  let shopProducts = [];
  let shopJobs = [];
  let shopJobsLoadError = false;
  let activeShopTab = 'all';
  let currentUserEmail = '';
  let shopBlocked = false;
  let shopOnHold = false;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const isUuid = value => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value || ''));
  const profileOverlay = document.getElementById('profileOverlay');
  const profileStatus = () => document.getElementById('profileStatus');
  let profileDialogHistoryOpen = false;
  let shareDialogHistoryOpen = false;

  function setTheme(dark) {
    if (window.setSiteTheme) window.setSiteTheme(dark ? 'dark' : 'light');
    else document.documentElement.dataset.theme = dark ? 'dark' : 'light';
  }

  const shopMenuToggle = document.getElementById('shopMenuToggle');
  const shopMenu = document.getElementById('shopMenu');
  shopMenuToggle.addEventListener('click', () => {
    const opened = shopMenu.hasAttribute('hidden');
    shopMenu.toggleAttribute('hidden', !opened);
    shopMenuToggle.setAttribute('aria-expanded', String(opened));
  });
  document.addEventListener('click', event => {
    if (!event.target.closest('.shop-menu-wrap')) { shopMenu.setAttribute('hidden',''); shopMenuToggle.setAttribute('aria-expanded','false'); }
  });
  function localShopFlag(name) { try { return localStorage.getItem(`alee-shop-${name}-${shop?.id}`) === '1'; } catch (_) { return false; } }
  function setLocalShopFlag(name, value) { try { localStorage.setItem(`alee-shop-${name}-${shop.id}`, value ? '1' : '0'); } catch (_) {} }
  function refreshShopVisibility() {
    const productsEl = document.getElementById('products');
    if (shopBlocked || shopOnHold) {
      productsEl.innerHTML = `<div class="empty">${shopBlocked ? 'You blocked this shop on this device.' : 'This shop is on hold on this device.'}</div>`;
      const jobsEl=document.getElementById('shopJobs');if(jobsEl)jobsEl.innerHTML=`<div class="empty">${shopBlocked?'You blocked this shop on this device.':'This shop is on hold on this device.'}</div>`;
      document.getElementById('profileStatus').textContent = shopBlocked ? 'This shop is blocked on this device. Open the menu to unblock it.' : 'This shop is on hold on this device. Open the menu to resume it.';
    } else {
      const status=document.getElementById('profileStatus');
      if(status && /^(This shop is blocked|This shop is on hold)/.test(status.textContent)) status.textContent='';
    }
    const blockButton = shopMenu.querySelector('[data-shop-action="block"]');
    const holdButton = shopMenu.querySelector('[data-shop-action="hold"]');
    if (blockButton) blockButton.textContent = shopBlocked ? 'Unblock' : 'Block';
    if (holdButton) holdButton.textContent = shopOnHold ? 'Resume shop' : 'Hold';
    if (document.getElementById('shopProductsPanel')) renderShopContent();
  }
  async function sendShopReport() {
    const form = document.getElementById('shopReportForm');
    if (!form) return;
    form.addEventListener('submit', async event => {
      event.preventDefault();
      const status = form.querySelector('[role="status"]');
      if (!currentUser) { status.textContent = 'Sign in first to send a report.'; return; }
      const {error} = await supabase.from('shop_profile_reports').insert({shop_key:String(shop.id),reporter_id:currentUser.id,reason:form.elements.reason.value.trim(),details:form.elements.details.value.trim()});
      status.textContent = error ? 'Report could not be sent. Check the latest seller-marketplace-schema.sql in Supabase.' : 'Thank you. Your report has been sent.';
      if (!error) form.querySelector('button[type="submit"]').disabled = true;
    });
  }
  shopMenu.addEventListener('click', event => {
    const button = event.target.closest('[data-shop-action]'); if (!button || !shop) return;
    const action = button.dataset.shopAction;
    shopMenu.setAttribute('hidden',''); shopMenuToggle.setAttribute('aria-expanded','false');
    if (action === 'block') { shopBlocked = !shopBlocked; setLocalShopFlag('blocked',shopBlocked); refreshShopVisibility(); }
    else if (action === 'hold') { shopOnHold = !shopOnHold; setLocalShopFlag('hold',shopOnHold); refreshShopVisibility(); }
    else if (action === 'about') openProfileDialog('About this shop', `<p><strong>${esc(shop.name)}</strong></p><p>${esc(shop.bio||shop.shopCategory||'Business')}</p><p>${esc(shop.address||'')}</p>`);
    else if (action === 'report') { openProfileDialog('Report this shop', '<form id="shopReportForm" class="shop-report-form"><label>Reason<select name="reason" required><option value="">Choose a reason</option><option>Scam or fraud</option><option>Impersonation</option><option>Inappropriate content</option><option>Other</option></select></label><label>Details<textarea name="details" maxlength="1000" placeholder="Tell us what happened"></textarea></label><button type="submit">Send report</button><p role="status" aria-live="polite"></p></form>'); sendShopReport(); }
  });

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
    openProfileDialog('Contact', `<div class="contact-details">${parts.length ? parts.join('') : '<p>Contact details have not been added yet.</p>'}</div><button class="contact-message-button" id="contactMessageShop" type="button"><i class="fa-regular fa-comments"></i> Message this shop</button>`);
    document.getElementById('contactMessageShop').addEventListener('click',()=>{closeProfileDialog(true);history.replaceState({...history.state,aleeShopProfileDialog:false},'',location.href);if(window.aleeChat?.openShop)window.aleeChat.openShop(shop.id,shop.name,{initialMessage:`Hello, I found your shop on aleeshopping and would like to ask you something.`});});
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
      ? `<div class="profile-list">${rows.map(row=>{const avatar=String(row.follower_avatar_url||'');const safeAvatar=/^https:\/\//i.test(avatar)?avatar:'assets/alee-logo.png';return `<div class="profile-list-item"><img src="${esc(safeAvatar)}" alt="" loading="lazy" onerror="this.onerror=null;this.src='assets/alee-logo.png'"><span>${esc(row.follower_name||'Shopper')}</span></div>`;}).join('')}</div>`
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

  function safeJobLink(value) {
    const raw=String(value||'').trim();if(!raw)return '';
    try { const url=new URL(raw,location.href);return ['https:','http:','mailto:','tel:'].includes(url.protocol)?url.href:''; } catch (_) { return ''; }
  }
  function renderShopJob(job) {
    const title=esc(job.title||'Job opportunity'),details=[job.employment_type,job.location,job.salary].filter(Boolean).map(esc);
    const media=String(job.media_url||'').trim();
    const image=media?`<img class="shop-job-image" src="${esc(media)}" alt="" loading="lazy" onerror="this.onerror=null;this.src='assets/alee-logo.png'">`:'<i class="fa-solid fa-briefcase" aria-hidden="true"></i>';
    const link=safeJobLink(job.link_url);
    return `<article class="shop-job-card"><div class="shop-job-thumb">${image}</div><div class="shop-job-copy"><h3>${title}</h3><div class="shop-job-meta">${details.map(item=>`<span>${item}</span>`).join('')}</div>${job.description?`<p>${esc(job.description)}</p>`:''}${link?`<a class="shop-job-open" href="${esc(link)}" ${/^https?:/i.test(link)?'target="_blank" rel="noopener noreferrer"':''}>View job details</a>`:''}</div></article>`;
  }
  function renderShopContent() {
    const productsPanel=document.getElementById('shopProductsPanel'),jobsPanel=document.getElementById('shopJobsPanel');
    const productsEl=document.getElementById('products'),jobsEl=document.getElementById('shopJobs'),heading=document.getElementById('shopContentHeading');
    const tabButtons=Array.from(document.querySelectorAll('[data-shop-tab]'));
    tabButtons.forEach(button=>{const active=button.dataset.shopTab===activeShopTab;button.classList.toggle('active',active);button.setAttribute('aria-pressed',String(active));});
    const showJobs=activeShopTab==='jobs';productsPanel.hidden=showJobs;jobsPanel.hidden=!showJobs;
    if(showJobs){
      if(shopBlocked||shopOnHold){jobsEl.innerHTML=`<div class="empty">${shopBlocked?'You blocked this shop on this device.':'This shop is on hold on this device.'}</div>`;return;}
      jobsEl.innerHTML=shopJobsLoadError?'<div class="empty">Shop jobs could not load. Check platform-posts-schema.sql in Supabase.</div>':shopJobs.length?shopJobs.map(renderShopJob).join(''):'<div class="empty">This shop has no job listings yet.</div>';
      return;
    }
    const labels={all:'All',new:'New arrivals',best:'Best selling'};heading.textContent=labels[activeShopTab]||'All';
    if(shopBlocked||shopOnHold){productsEl.innerHTML=`<div class="empty">${shopBlocked?'You blocked this shop on this device.':'This shop is on hold on this device.'}</div>`;return;}
    let items=shopProducts.slice();
    if(activeShopTab==='new'){
      const cutoff=Date.now()-7*24*60*60*1000;
      items=items.filter(item=>{const created=Date.parse(item.createdAt||item.created_at||'');return Number.isFinite(created)&&created>=cutoff;});
    } else if(activeShopTab==='best'){
      items.sort((a,b)=>(Number(b.soldCount)||0)-(Number(a.soldCount)||0)||((Date.parse(b.createdAt||b.created_at||'')||0)-(Date.parse(a.createdAt||a.created_at||'')||0)));
    }
    productsEl.innerHTML=items.length?items.map(item=>{let price;try{price=new Intl.NumberFormat(undefined,{style:'currency',currency:shop.currency_code||'LKR',maximumFractionDigits:2}).format(Number(item.price||0));}catch(_){price=`${shop.currency_code||'LKR'} ${Number(item.price||0).toLocaleString()}`;}return `<a class="card" href="index.html?product=${encodeURIComponent(item.id)}"><img src="${esc(item.images?.[0]||'assets/alee-logo.png')}" alt="${esc(item.name)}" loading="lazy" decoding="async" onerror="this.onerror=null;this.src='assets/alee-logo.png'">${item.freeShipping?'<span class="free-shipping-badge shop-free-shipping-badge"><i class="fa-solid fa-truck" aria-hidden="true"></i> FREE SHIPPING</span>':''}<div class="shop-meta"><span>${esc(shop.name)}</span></div><h3>${esc(item.name)}</h3><div class="price">${price}</div></a>`;}).join(''):`<div class="empty">${activeShopTab==='new'?'No products were added in the last 7 days.':activeShopTab==='best'?'No best-selling products yet.':'This business has no products yet.'}</div>`;
  }


  async function toggleFavoriteShop() {
    const button=document.getElementById('favoriteShopButton'),key=currentUser?.id||'guest',storageKey='alee-favorites:'+key;let rows=[];try{rows=JSON.parse(localStorage.getItem(storageKey)||'[]');}catch(_){}if(!Array.isArray(rows))rows=[];const existing=rows.some(row=>row.type==='shop'&&String(row.id)===String(shop.id));if(existing){rows=rows.filter(row=>!(row.type==='shop'&&String(row.id)===String(shop.id)));button.innerHTML='<i class="fa-regular fa-heart"></i>';button.classList.remove('is-saved');button.setAttribute('aria-label','Add shop to favorites');button.title='Add to favorites';button.setAttribute('aria-pressed','false');if(currentUser&&supabase)try{await supabase.from('user_favorites').delete().eq('user_id',currentUser.id).eq('item_type','shop').eq('item_id',String(shop.id));}catch(_){}}else{const row={type:'shop',id:String(shop.id),title:shop.name,image:shop.logo||'assets/alee-logo.png',summary:'Shop profile',url:'shop.html?shop='+encodeURIComponent(shop.id),data:{id:String(shop.id),name:shop.name,logo:shop.logo||'assets/alee-logo.png'}};rows.unshift(row);button.innerHTML='<i class="fa-solid fa-heart"></i>';button.classList.add('is-saved');button.setAttribute('aria-label','Remove shop from favorites');button.title='Remove from favorites';button.setAttribute('aria-pressed','true');if(currentUser&&supabase)try{await supabase.from('user_favorites').upsert({user_id:currentUser.id,item_type:'shop',item_id:String(shop.id),item_data:row},{onConflict:'user_id,item_type,item_id'});}catch(_){}}try{localStorage.setItem(storageKey,JSON.stringify(rows.slice(0,300)));}catch(_){} }

  function renderProfile() {
    if (!shop) {
      document.getElementById('shopProfile').innerHTML = '<div class="empty"><h2>Business profile not found</h2><p>Return to aleeshopping and choose a shop.</p></div>';
      document.getElementById('products').innerHTML = ''; return;
    }
    document.documentElement.style.setProperty('--shop-accent', /^#[0-9a-f]{6}$/i.test(shop.accentColor || '') ? shop.accentColor : '#ff6900');
    document.title = `${shop.name} — aleeshopping`;
    document.getElementById('headerShopName').textContent = shop.name;
    document.getElementById('headerShopLogo').src = shop.logo || 'assets/alee-logo.png';
    shopBlocked = localShopFlag('blocked'); shopOnHold = localShopFlag('hold');
    document.getElementById('ratingToolLink').hidden = currentUserEmail.toLowerCase() !== 'aleeshopping2026@gmail.com';
    shopProducts=products.filter(item=>String(item.shopId||shops[0]?.id||'alee-shopping')===String(shop.id));
    document.getElementById('shopProfile').innerHTML = `<div class="profile-top"><div class="profile-avatar-wrap"><img class="profile-avatar" src="${esc(shop.logo||'assets/alee-logo.png')}" alt="${esc(shop.name)} logo" decoding="async" fetchpriority="high" onerror="this.onerror=null;this.src='assets/alee-logo.png'"><div class="shop-rating-stars profile-stars" aria-label="${shopRating} out of 5 stars">${[1,2,3,4,5].map(star=>`<span class="${star<=shopRating?'':'empty-star'}">★</span>`).join('')}</div></div><div class="profile-identity"><h2 class="profile-name"><span>${esc(shop.name)}</span>${shop.isVerified?'<img class="shop-verified-badge" src="assets/verified-badge.svg" alt="Verified shop">':''}<button id="favoriteShopButton" class="favorite-heart-button" type="button" aria-label="Add shop to favorites" title="Add to favorites" aria-pressed="false"><i class="fa-regular fa-heart"></i></button></h2><div class="profile-stats"><button class="profile-stat" id="adsStat" type="button"><strong>${shopProducts.length}</strong><span>ads</span></button><button class="profile-stat" id="followersStat" type="button"><strong>${followerCount}</strong><span>followers</span></button><button class="profile-stat" id="followingStat" type="button"><strong>${followingCount}</strong><span>following</span></button></div></div></div><div class="profile-bio"><span class="bio-category">${esc(shop.shopCategory||'Business')}</span>${esc(shop.bio||'')}</div><div class="profile-buttons"><button class="follow-button ${isFollowing?'is-following':''}" id="followButton" type="button">${isFollowing?'Following':'Follow'}</button><button id="contactButton" type="button">Contact</button><button id="openShare" type="button">Share profile</button></div><nav class="shop-content-tabs" aria-label="Shop listings"><button type="button" data-shop-tab="all" aria-pressed="true">All</button><button type="button" data-shop-tab="new" aria-pressed="false">New arrivals</button><button type="button" data-shop-tab="best" aria-pressed="false">Best selling</button><button type="button" data-shop-tab="jobs" aria-pressed="false">Jobs</button></nav><div class="profile-status" id="profileStatus" role="status" aria-live="polite"></div>`;
    document.getElementById('followersStat').addEventListener('click', showFollowers);
    document.getElementById('followingStat').addEventListener('click', showFollowing);
    document.getElementById('adsStat').addEventListener('click', () => document.getElementById('products').scrollIntoView({behavior:'smooth', block:'start'}));
    document.getElementById('followButton').addEventListener('click', toggleFollow);
    const savedKey=currentUser?.id||'guest';let savedRows=[];try{savedRows=JSON.parse(localStorage.getItem('alee-favorites:'+savedKey)||'[]');}catch(_){}if(savedRows.some(row=>row.type==='shop'&&String(row.id)===String(shop.id))){const favorite=document.getElementById('favoriteShopButton');favorite.innerHTML='<i class="fa-solid fa-heart"></i>';favorite.classList.add('is-saved');favorite.setAttribute('aria-label','Remove shop from favorites');favorite.title='Remove from favorites';favorite.setAttribute('aria-pressed','true');}
    document.getElementById('favoriteShopButton').addEventListener('click', toggleFavoriteShop);
    document.getElementById('contactButton').addEventListener('click', renderContact);
    document.getElementById('openShare').addEventListener('click', openShareDialog);
    document.querySelectorAll('[data-shop-tab]').forEach(button=>button.addEventListener('click',()=>{activeShopTab=button.dataset.shopTab;renderShopContent();}));
    renderShopContent();
    refreshShopVisibility();
  }

  async function loadShop() {
    if (!shop && supabase && shopId && isUuid(shopId)) {
      const {data:row,error} = await supabase.from('seller_shops_profile_public').select('*').eq('id',shopId).maybeSingle();
      if (!error && row) {
        shop = {id:String(row.id), name:row.shop_name, logo:row.logo_url||'assets/alee-logo.png', phone:row.phone||'', phone2:row.phone2||'', address:row.address||'', externalLink:row.external_link||'', shopCategory:row.shop_category||'Other', bio:row.bio||'', facebook:row.facebook_url||'', instagram:row.instagram_url||'', youtube:row.youtube_url||'', tiktok:row.tiktok_url||'', currency_code:row.currency_code||'LKR', isVerified:Boolean(row.is_verified), rank:9999, rating:5};
        const {data:items} = await supabase.from('seller_products_profile_public').select('*').eq('shop_id',shopId);
        (items||[]).forEach(item=>{const price=Number(item.offer_price)||Number(item.price);products.push({id:1000000000+Number(item.id),name:item.name,price,originalPrice:Number(item.offer_price)?Number(item.price):null,discountPercent:Number(item.offer_price)&&Number(item.price)>Number(item.offer_price)?Math.round((Number(item.price)-price)*100/Number(item.price)):0,stock:Number(item.stock??1),soldCount:Number(item.sold_count||0),freeShipping:Boolean(item.free_shipping),createdAt:item.created_at||'',currencyCode:item.currency_code||row.currency_code||'LKR',colors:item.colors||[],category:item.category,shopId:String(item.shop_id),desc:item.description||'',features:item.features||[],sizes:item.sizes||[],images:item.image_urls||[]});});
        shops.push(shop);
      }
    }
    if (supabase) {
      try { const {data}=await supabase.auth.getUser(); currentUser=data?.user||null; currentUserEmail=currentUser?.email||''; } catch (_) {}
    }
    if (shop && supabase) { const {data}=await supabase.from('shop_profile_ratings').select('stars').eq('shop_key',String(shop.id)).maybeSingle(); if(data) shopRating=Math.max(0,Math.min(5,Number(data.stars)||0)); else shopRating=Number(shop.rating||5); }
    renderProfile();
    if (shop && supabase) {
      const key='alee-shop-view:'+shop.id,now=Date.now();
      try { if(now-Number(sessionStorage.getItem(key)||0)>1800000){sessionStorage.setItem(key,String(now));await supabase.rpc('track_seller_shop_view',{p_shop_id:shop.id});} } catch(_) {}
      const jobsPromise=isUuid(shop.id)?supabase.from('platform_posts').select('id,title,category,description,link_url,media_url,location,employment_type,salary,created_at').eq('shop_id',shop.id).eq('post_type','job').order('created_at',{ascending:false}).limit(100):null;
      const [jobsResult]=await Promise.all([jobsPromise,getBusinessStats()]);
      if(jobsResult){shopJobsLoadError=Boolean(jobsResult.error);shopJobs=jobsResult.error?[]:(jobsResult.data||[]);if(activeShopTab==='jobs')renderShopContent();}
    }
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



