(() => {
  const mode = document.body.dataset.staticManager;
  const placement = mode === 'home' ? 'homepage' : 'product_popup';
  const bucket = 'site-promotion-media';
  const hostEmails = ['aleeshopping2026@gmail.com', 'aleeshopping@gmail.com'];
  const entries = [];
  const root = document.getElementById('entryList');
  const status = document.getElementById('status');
  let client = null;

  const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[char]));
  const slug = value => String(value).normalize('NFKD').replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase() || 'promotion';
  const itemLabel = mode === 'home' ? 'homepage banner' : 'product popup ad';
  const currentColumns = 'id,placement,media_type,media_url,media_path,title,alt,link,sort_order';

  function toEntry(row) {
    const entry = {
      id: row.id,
      mediaPath: row.media_path || '',
      title: row.title || row.alt || '',
      alt: row.alt || row.title || '',
      link: row.link || ''
    };
    entry[row.media_type === 'video' ? 'video' : 'image'] = row.media_url;
    return entry;
  }

  function gate(message) {
    document.getElementById('accessMessage').textContent = message;
    document.getElementById('accessGate').hidden = false;
    document.getElementById('workspace').hidden = true;
  }

  async function start() {
    try {
      client = window.aleeSupabase;
      if (!client) throw new Error('Supabase is not configured. Reload this page and try again.');
      const { data: { session }, error: sessionError } = await client.auth.getSession();
      if (sessionError) throw sessionError;
      const email = String(session?.user?.email || '').trim().toLowerCase();
      document.getElementById('signedIn').textContent = email || 'Not signed in';
      if (!hostEmails.includes(email)) {
        gate('Sign in with an authorized aleeshopping host Gmail account.');
        return;
      }

      const { data, error } = await client.from('site_promotions')
        .select(currentColumns).eq('placement', placement)
        .order('sort_order', { ascending: true }).order('created_at', { ascending: true }).limit(2000);
      if (error) throw error;
      entries.splice(0, entries.length, ...(data || []).map(toEntry));
      document.getElementById('workspace').hidden = false;
      render();
    } catch (error) {
      const detail = String(error?.message || error || 'Unknown error');
      gate(detail.includes('site_promotions') || error?.code === '42P01'
        ? 'Banner saving is not set up yet. Run site-promotions-schema.sql once in the Supabase SQL Editor, then reload this manager.'
        : `Could not load saved promotions: ${detail}`);
    }
  }

  function render() {
    document.getElementById('count').textContent = `${entries.length} saved · changes publish immediately`;
    root.innerHTML = entries.length ? entries.map((entry, index) => {
      const media = entry.video || entry.image || '';
      const title = entry.title || entry.alt || `${mode === 'home' ? 'Banner' : 'Promotion'} ${index + 1}`;
      const preview = entry.video
        ? `<video src="${esc(media)}" muted playsinline preload="metadata"></video>`
        : `<img src="${esc(media)}" alt="" onerror="this.src='assets/alee-logo.png'">`;
      return `<article class="entry" data-index="${index}">
        <div class="preview">${preview}</div>
        <div class="fields">
          <label>Title / description<input data-title value="${esc(title)}" maxlength="120"></label>
          <label>Destination link<input data-link type="url" value="${esc(entry.link)}" placeholder="https://…"></label>
          <label>Replace media<input data-replace type="file" accept="image/*,video/mp4,video/webm,video/quicktime"></label>
        </div>
        <div class="controls"><span class="rank">Order ${index + 1}</span>
          <button class="mini" data-up ${index === 0 ? 'disabled' : ''} aria-label="Move up">↑</button>
          <button class="mini" data-down ${index === entries.length - 1 ? 'disabled' : ''} aria-label="Move down">↓</button>
          <button class="mini save" data-save>Save</button>
          <button class="mini danger" data-delete>Delete</button>
        </div>
      </article>`;
    }).join('') : '<div class="empty">No saved promotions yet. Add one below.</div>';

    root.querySelectorAll('.entry').forEach(card => {
      const index = Number(card.dataset.index);
      card.querySelector('[data-up]').onclick = () => move(index, -1);
      card.querySelector('[data-down]').onclick = () => move(index, 1);
      card.querySelector('[data-save]').onclick = () => saveEntry(index, card);
      card.querySelector('[data-delete]').onclick = () => removeEntry(index);
      card.querySelector('[data-replace]').onchange = event => replaceMedia(index, event.target.files?.[0]);
    });
  }

  function validateLink(link) {
    return !link || /^https?:\/\//i.test(link);
  }

  async function uploadMedia(file) {
    const isVideo = file.type.startsWith('video/');
    const allowedImageTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif'];
    const allowedVideoTypes = ['video/mp4', 'video/webm', 'video/quicktime'];
    if (isVideo ? !allowedVideoTypes.includes(file.type) : !allowedImageTypes.includes(file.type)) {
      throw new Error('Choose a JPG, PNG, WEBP, GIF, or AVIF image, or an MP4, WEBM, or MOV video.');
    }
    if (file.size > (isVideo ? 50 : 10) * 1024 * 1024) throw new Error(`${isVideo ? 'Video' : 'Image'} exceeds the size limit.`);
    const extension = (file.name.match(/\.([a-z0-9]+)$/i) || [])[1]?.toLowerCase() || (isVideo ? 'mp4' : 'jpg');
    const fileId = window.crypto?.randomUUID?.() || `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
    const path = `${mode === 'home' ? 'homepage' : 'product-popup'}/${fileId}-${slug(file.name.replace(/\.[^.]+$/, ''))}.${extension}`;
    const { error } = await client.storage.from(bucket).upload(path, file, { contentType: file.type, upsert: false });
    if (error) throw error;
    const { data } = client.storage.from(bucket).getPublicUrl(path);
    return { path, url: data.publicUrl, type: isVideo ? 'video' : 'image' };
  }

  async function updateOrder() {
    const results = await Promise.all(entries.map((entry, index) => client.from('site_promotions')
      .update({ sort_order: index }).eq('id', entry.id)));
    const failure = results.find(result => result.error);
    if (failure) throw failure.error;
  }

  async function move(index, delta) {
    const target = index + delta;
    if (target < 0 || target >= entries.length) return;
    [entries[index], entries[target]] = [entries[target], entries[index]];
    render();
    status.textContent = 'Saving the new order…';
    try {
      await updateOrder();
      status.textContent = 'Order saved and published.';
    } catch (error) {
      status.textContent = `Could not save the order: ${error.message || error}`;
      await start();
    }
  }

  async function saveEntry(index, card) {
    const title = card.querySelector('[data-title]').value.trim();
    const link = card.querySelector('[data-link]').value.trim();
    if (!validateLink(link)) { status.textContent = 'Use an http:// or https:// destination link.'; return; }
    status.textContent = 'Saving changes…';
    try {
      const { data, error } = await client.from('site_promotions').update({ title, alt: title, link })
        .eq('id', entries[index].id).select(currentColumns).single();
      if (error) throw error;
      entries[index] = toEntry(data);
      render();
      status.textContent = 'Changes saved and published.';
    } catch (error) {
      status.textContent = `Could not save changes: ${error.message || error}`;
    }
  }

  async function removeEntry(index) {
    const entry = entries[index];
    if (!confirm(`Delete this ${itemLabel} from the live site?`)) return;
    status.textContent = 'Deleting promotion…';
    try {
      const { error } = await client.from('site_promotions').delete().eq('id', entry.id);
      if (error) throw error;
      entries.splice(index, 1);
      render();
      if (entry.mediaPath) {
        const { error: storageError } = await client.storage.from(bucket).remove([entry.mediaPath]);
        if (storageError) console.warn('Promotion removed, but its old media could not be deleted.', storageError);
      }
      await updateOrder();
      status.textContent = 'Promotion deleted from the live site.';
    } catch (error) {
      status.textContent = `Could not delete promotion: ${error.message || error}`;
      await start();
    }
  }

  async function replaceMedia(index, file) {
    if (!file) return;
    status.textContent = 'Uploading replacement media…';
    let uploaded = null;
    try {
      uploaded = await uploadMedia(file);
      const { data, error } = await client.from('site_promotions').update({
        media_type: uploaded.type, media_url: uploaded.url, media_path: uploaded.path
      }).eq('id', entries[index].id).select(currentColumns).single();
      if (error) throw error;
      const oldPath = entries[index].mediaPath;
      entries[index] = toEntry(data);
      render();
      if (oldPath) {
        const { error: removeError } = await client.storage.from(bucket).remove([oldPath]);
        if (removeError) console.warn('Replacement saved, but old media could not be removed.', removeError);
      }
      status.textContent = 'Replacement media saved and published.';
    } catch (error) {
      if (uploaded?.path) await client.storage.from(bucket).remove([uploaded.path]).catch(() => {});
      status.textContent = `Could not replace media: ${error.message || error}`;
    }
  }

  document.getElementById('addForm').onsubmit = async event => {
    event.preventDefault();
    const form = event.currentTarget;
    const file = form.elements.media.files[0];
    const title = form.elements.title.value.trim() || file?.name || 'Promotion';
    const link = form.elements.link.value.trim();
    if (!file) return;
    if (entries.length >= 2000) { status.textContent = 'The maximum is 2,000 promotions.'; return; }
    if (!validateLink(link)) { status.textContent = 'Use an http:// or https:// destination link.'; return; }
    status.textContent = `Uploading and saving ${itemLabel}…`;
    const submit = form.querySelector('[type="submit"]');
    if (submit) submit.disabled = true;
    let uploaded = null;
    try {
      uploaded = await uploadMedia(file);
      const { data, error } = await client.from('site_promotions').insert({
        placement, media_type: uploaded.type, media_url: uploaded.url, media_path: uploaded.path,
        title, alt: title, link, sort_order: entries.length
      }).select(currentColumns).single();
      if (error) throw error;
      entries.push(toEntry(data));
      form.reset();
      render();
      status.textContent = `${itemLabel} saved and published. Refresh the home page or open a product to see it.`;
    } catch (error) {
      if (uploaded?.path) await client.storage.from(bucket).remove([uploaded.path]).catch(() => {});
      status.textContent = `Could not add ${itemLabel}: ${error.message || error}`;
    } finally {
      if (submit) submit.disabled = false;
    }
  };

  start();
})();
