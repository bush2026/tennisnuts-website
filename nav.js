(function () {
  // A. Inject styles
  var style = document.createElement('style');
  style.textContent = [
    /* Prevent horizontal overflow site-wide */
    'html,body{overflow-x:hidden;max-width:100%}',
    '.site-nav{position:sticky;top:0;z-index:100;background:rgba(255,255,255,0.93);backdrop-filter:saturate(140%) blur(12px);-webkit-backdrop-filter:saturate(140%) blur(12px);border-bottom:1px solid var(--line,#e6e3d8);}',
    '.site-nav .nav-inner{max-width:1240px;margin:0 auto;padding:0 28px;display:flex;align-items:center;justify-content:space-between;height:72px;gap:20px;}',
    '.site-nav .brand{display:flex;align-items:center;flex-shrink:0;}',
    '.site-nav .nav-links{display:flex;align-items:center;gap:4px;list-style:none;margin:0;padding:0;}',
    '.site-nav .nav-links li{position:relative;}',
    '.site-nav .nav-links a,.site-nav .nav-links button{color:#4a5240;font-family:"DM Sans",sans-serif;font-weight:500;font-size:15px;background:none;border:none;cursor:pointer;padding:8px 12px;border-radius:8px;display:flex;align-items:center;gap:5px;white-space:nowrap;transition:color .15s,background .15s;}',
    '.site-nav .nav-links a:hover,.site-nav .nav-links button:hover{color:#3a5c2c;background:#f5f8ef;}',
    '.site-nav .nav-links a.nav-active{color:#3a5c2c;font-weight:600;}',
    '.site-nav .nav-links .chevron{width:14px;height:14px;transition:transform .2s;flex-shrink:0;}',
    '.site-nav .nav-links li.open .chevron{transform:rotate(180deg);}',
    '.site-nav .dropdown-menu{display:none;position:absolute;top:calc(100% + 8px);left:0;background:#fff;border:1px solid var(--line,#e6e3d8);border-radius:14px;box-shadow:0 12px 32px -8px rgba(0,0,0,0.15);min-width:220px;padding:8px;z-index:200;}',
    '.site-nav li:hover .dropdown-menu,.site-nav li.open .dropdown-menu{display:block;}',
    '.site-nav .dropdown-menu a{display:block;padding:10px 14px;border-radius:8px;color:#1c2218;font-size:14px;font-weight:500;font-family:"DM Sans",sans-serif;transition:background .12s,color .12s;}',
    '.site-nav .dropdown-menu a:hover{background:#f5f8ef;color:#3a5c2c;}',
    '.site-nav .nav-wa{display:inline-flex;align-items:center;gap:8px;padding:10px 18px;border-radius:999px;background:#3a5c2c;color:#fff;font-family:"DM Sans",sans-serif;font-weight:600;font-size:14px;text-decoration:none;flex-shrink:0;transition:background .15s,transform .15s;}',
    '.site-nav .nav-wa:hover{background:#2c4621;transform:translateY(-1px);}',
    /* Burger — hidden on desktop, shown on mobile */
    '.site-nav .nav-burger{display:none;flex-direction:column;gap:5px;background:none;border:none;cursor:pointer;padding:10px 8px;border-radius:8px;transition:background .15s;}',
    '.site-nav .nav-burger:hover{background:#f5f8ef;}',
    '.site-nav .nav-burger span{display:block;width:24px;height:2px;background:#1c2218;border-radius:2px;transition:all .25s;}',
    '.site-nav.menu-open .nav-burger span:nth-child(1){transform:translateY(7px) rotate(45deg);}',
    '.site-nav.menu-open .nav-burger span:nth-child(2){opacity:0;transform:scaleX(0);}',
    '.site-nav.menu-open .nav-burger span:nth-child(3){transform:translateY(-7px) rotate(-45deg);}',
    '@media(max-width:960px){',
    '  .site-nav .nav-links{display:none;position:absolute;top:72px;left:0;right:0;background:#fff;border-bottom:1px solid var(--line,#e6e3d8);flex-direction:column;align-items:stretch;padding:12px 20px 20px;gap:2px;box-shadow:0 8px 24px rgba(0,0,0,0.08);}',
    '  .site-nav.menu-open .nav-links{display:flex;}',
    '  .site-nav .nav-links li{width:100%;}',
    '  .site-nav .nav-links a,.site-nav .nav-links button{width:100%;justify-content:space-between;padding:13px 14px;font-size:16px;}',
    '  .site-nav .dropdown-menu{display:none!important;position:static;border:none;box-shadow:none;border-radius:0;padding:0 0 0 16px;background:transparent;}',
    '  .site-nav li.open .dropdown-menu{display:block!important;}',
    '  .site-nav .dropdown-menu a{padding:11px 14px;font-size:15px;border-radius:8px;}',
    '  .site-nav .nav-burger{display:flex;}',
    '  .site-nav .nav-wa{display:none;}',
    '  .site-nav .nav-links li.mobile-section-label{padding:14px 14px 4px;font-size:11px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;color:#9aa192;pointer-events:none;}',
    '}'
  ].join('');
  document.head.appendChild(style);

  // B. Inject nav HTML
  var chevronSVG = '<svg class="chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 9l6 6 6-6"/></svg>';
  var logoImg = '<img src="images/website-sections/logo/tennisnuts-logo-transparent.png" alt="Tennisnuts" style="height:54px;display:block">';
  var navHTML = '<nav class="site-nav" id="main-nav">'
    + '<div class="nav-inner">'
    + '<a href="index.html" class="brand">' + logoImg + '</a>'
    + '<ul class="nav-links">'
    + '<li><a href="index.html">Home</a></li>'
    + '<li><a href="academy.html">Academy</a></li>'
    + '<li><a href="partners.html">Partners</a></li>'
    + '<li><a href="blog.html">Blog</a></li>'
    + '<li>'
    + '<button aria-haspopup="true">Events ' + chevronSVG + '</button>'
    + '<div class="dropdown-menu">'
    + '<a href="socials.html">Tennisnuts Socials</a>'
    + '<a href="seniors.html">Seniors Tennis</a>'
    + '<a href="open.html">Tennisnuts Open</a>'
    + '<a href="sopal-trophy.html">Sopal Club Championship</a>'
    + '<a href="corporate-tournament.html">Corporate Tournament</a>'
    + '<a href="tennis-clinics.html">Tennis Clinics</a>'
    + '</div>'
    + '</li>'
    + '</ul>'
    + '<a href="https://wa.me/919881125831?text=Hi%2C%20I%20want%20to%20join%20Tennisnuts." class="nav-wa" target="_blank" rel="noopener"><svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M20.5 3.5A10 10 0 003.4 16.3L2 22l5.9-1.4A10 10 0 0020.5 3.5zM12 20.2a8.2 8.2 0 01-4.2-1.2l-.3-.2-3.5.9.9-3.4-.2-.3a8.2 8.2 0 1115.5-3.7A8.2 8.2 0 0112 20.2z"/></svg> Join WhatsApp</a>'
    + '<button class="nav-burger" id="nav-burger-btn" aria-label="Toggle menu"><span></span><span></span><span></span></button>'
    + '</div>'
    + '</nav>';

  var navContainer = document.getElementById('site-nav');
  if (navContainer) {
    navContainer.innerHTML = navHTML;
  }

  // C. JavaScript logic

  // Hamburger toggle
  document.getElementById('nav-burger-btn').addEventListener('click', function () {
    document.getElementById('main-nav').classList.toggle('menu-open');
  });

  // Close mobile menu when a link is clicked
  document.querySelectorAll('.site-nav .nav-links a').forEach(function (a) {
    a.addEventListener('click', function () {
      document.getElementById('main-nav').classList.remove('menu-open');
    });
  });

  // Dropdown toggle on button click
  document.querySelectorAll('.site-nav .nav-links button').forEach(function (btn) {
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var li = this.closest('li');
      var wasOpen = li.classList.contains('open');
      document.querySelectorAll('.site-nav .nav-links li').forEach(function (l) { l.classList.remove('open'); });
      if (!wasOpen) li.classList.add('open');
    });
  });

  // Close dropdowns on outside click
  document.addEventListener('click', function () {
    document.querySelectorAll('.site-nav .nav-links li').forEach(function (l) { l.classList.remove('open'); });
    document.getElementById('main-nav').classList.remove('menu-open');
  });

  // Prevent close when clicking inside nav
  document.getElementById('main-nav').addEventListener('click', function (e) {
    e.stopPropagation();
  });

  // Active link highlighting
  var currentFile = window.location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.site-nav .nav-links a').forEach(function (a) {
    if (a.getAttribute('href') === currentFile) a.classList.add('nav-active');
  });
  document.querySelectorAll('.site-nav .dropdown-menu a').forEach(function (a) {
    if (a.getAttribute('href') === currentFile) {
      a.classList.add('nav-active');
      a.closest('li').querySelector('button').style.color = '#3a5c2c';
    }
  });
})();
