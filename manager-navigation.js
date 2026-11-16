(() => {
  const page = location.pathname.split('/').pop()?.toLowerCase() || '';
  const returnTo = new URLSearchParams(location.search).get('aleeReturnTo');
  const accountUrl = 'index.html?aleeOpenAccount=1';
  const managerCenterUrl = 'manager-center.html?aleeReturnTo=account';
  const returnUrl = returnTo === 'manager-center' ? managerCenterUrl : accountUrl;

  if (page === 'manager-center.html') {
    const backLink = document.querySelector('.top a');
    if (backLink) backLink.href = accountUrl;
    document.querySelectorAll('#content .card a.button').forEach(link => {
      const target = new URL(link.href, location.href);
      target.searchParams.set('aleeReturnTo', 'manager-center');
      link.href = target.href;
    });
  }

  if (page === 'banner-pricing-manager.html' && returnTo !== 'manager-center') {
    const backLink = document.querySelector('.top a');
    if (backLink) backLink.href = accountUrl;
  } else if (page !== 'manager-center.html') {
    const backLink = document.querySelector('.top a');
    if (backLink) backLink.href = returnUrl;
  }

  document.querySelectorAll('a[href="index.html"]').forEach(link => {
    link.href = returnUrl;
  });

  document.addEventListener('click', event => {
    const link = event.target.closest('a');
    if (!link || link.hasAttribute('download')) return;
    const target = new URL(link.href, location.href);
    if (target.pathname === new URL('index.html', location.href).pathname) {
      event.preventDefault();
      location.href = returnUrl;
    }
  }, true);
})();
