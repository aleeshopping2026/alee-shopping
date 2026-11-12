(() => {
  const root = document.documentElement;
  const storageKey = 'alee-theme';
  const readTheme = () => {
    try { return localStorage.getItem(storageKey) === 'dark' ? 'dark' : 'light'; }
    catch (_) { return 'light'; }
  };
  let menu = null;
  let activeTrigger = null;

  function ensureMenu() {
    if (menu) return menu;
    menu = document.createElement('div');
    menu.className = 'site-theme-menu';
    menu.id = 'siteThemeMenu';
    menu.setAttribute('role', 'group');
    menu.setAttribute('aria-label', 'Appearance');
    menu.hidden = true;
    menu.innerHTML = '<div class="site-theme-menu-title">Appearance</div><button type="button" data-theme-choice="light"><i class="fa-regular fa-sun" aria-hidden="true"></i><span>Light</span><i class="fa-solid fa-check site-theme-check" aria-hidden="true"></i></button><button type="button" data-theme-choice="dark"><i class="fa-regular fa-moon" aria-hidden="true"></i><span>Dark</span><i class="fa-solid fa-check site-theme-check" aria-hidden="true"></i></button>';
    menu.addEventListener('click', event => {
      const choice = event.target.closest('[data-theme-choice]');
      if (!choice) return;
      window.setSiteTheme(choice.dataset.themeChoice);
      closeMenu();
      activeTrigger?.focus({ preventScroll: true });
    });
    document.body.appendChild(menu);
    return menu;
  }

  function syncMenu() {
    if (!menu) return;
    const current = root.dataset.theme === 'dark' ? 'dark' : 'light';
    menu.querySelectorAll('[data-theme-choice]').forEach(button => {
      const selected = button.dataset.themeChoice === current;
      button.classList.toggle('selected', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
  }

  function closeMenu() {
    if (!menu) return;
    menu.hidden = true;
    if (activeTrigger) activeTrigger.setAttribute('aria-expanded', 'false');
  }

  function openThemeSettings(trigger) {
    const panel = ensureMenu();
    if (!panel.hidden && activeTrigger === trigger) {
      closeMenu();
      return;
    }
    if (activeTrigger) activeTrigger.setAttribute('aria-expanded', 'false');
    activeTrigger = trigger || null;
    if (activeTrigger) activeTrigger.setAttribute('aria-expanded', 'true');
    syncMenu();
    panel.hidden = false;
    const anchor = activeTrigger?.getBoundingClientRect();
    const width = panel.offsetWidth || 220;
    const height = panel.offsetHeight || 150;
    const left = anchor ? Math.max(12, Math.min(anchor.right - width, innerWidth - width - 12)) : innerWidth - width - 16;
    const top = anchor ? Math.max(12, Math.min(anchor.bottom + 8, innerHeight - height - 12)) : 16;
    panel.style.left = `${left}px`;
    panel.style.top = `${top}px`;
    panel.querySelector('[data-theme-choice="light"]')?.focus({ preventScroll: true });
  }

  function setSiteTheme(theme) {
    const selected = theme === 'dark' ? 'dark' : 'light';
    root.dataset.theme = selected;
    try { localStorage.setItem(storageKey, selected); } catch (_) {}
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', selected === 'dark' ? '#111111' : '#ff6900');
    if (window.aleeChat?.setTheme) window.aleeChat.setTheme(selected);
    document.dispatchEvent(new CustomEvent('alee-theme-change', { detail: { theme: selected } }));
    syncMenu();
  }

  window.openThemeSettings = openThemeSettings;
  window.setSiteTheme = setSiteTheme;
  window.toggleTheme = () => openThemeSettings(document.getElementById('themeToggleBtn'));
  root.dataset.theme = readTheme();
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta && root.dataset.theme === 'dark') meta.setAttribute('content', '#111111');

  document.addEventListener('click', event => {
    if (menu && !menu.hidden && !event.target.closest('.site-theme-menu') && !event.target.closest('[data-open-theme-settings]')) closeMenu();
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && menu && !menu.hidden) {
      event.stopImmediatePropagation();
      closeMenu();
      activeTrigger?.focus({ preventScroll: true });
    }
  });
  window.addEventListener('resize', closeMenu);
  window.addEventListener('storage', event => {
    if (event.key !== storageKey) return;
    const selected = event.newValue === 'dark' ? 'dark' : 'light';
    root.dataset.theme = selected;
    const color = document.querySelector('meta[name="theme-color"]');
    if (color) color.setAttribute('content', selected === 'dark' ? '#111111' : '#ff6900');
    if (window.aleeChat?.setTheme) window.aleeChat.setTheme(selected);
    document.dispatchEvent(new CustomEvent('alee-theme-change', { detail: { theme: selected } }));
    syncMenu();
  });
})();
