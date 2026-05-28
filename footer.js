(function () {
  // Inject styles
  var style = document.createElement('style');
  style.textContent = [
    '.site-footer{background:#2c4621;color:rgba(255,255,255,0.85);padding:72px 0 24px;position:relative;overflow:hidden;font-family:"DM Sans",sans-serif;}',
    '.site-footer::before{content:"";position:absolute;top:0;left:0;right:0;height:7px;background:repeating-linear-gradient(90deg,#cddc39 0 40px,#4d7239 40px 80px);}',
    '.site-footer .footer-grid{max-width:1240px;margin:0 auto;padding:0 28px;display:grid;grid-template-columns:1.5fr 1fr 1fr 1fr;gap:40px;margin-bottom:56px;}',
    '.site-footer .footer-brand-logo{height:60px;margin-bottom:18px;}',
    '.site-footer .footer-tagline{font-size:14px;color:rgba(255,255,255,0.65);line-height:1.6;max-width:28ch;margin-bottom:20px;}',
    '.site-footer .footer-newsletter{display:flex;background:rgba(255,255,255,0.07);border:1px solid rgba(255,255,255,0.12);border-radius:12px;overflow:hidden;}',
    '.site-footer .footer-newsletter input{flex:1;background:transparent;border:0;color:#fff;font-family:inherit;font-size:13px;padding:10px 14px;outline:none;min-width:0;}',
    '.site-footer .footer-newsletter input::placeholder{color:rgba(255,255,255,0.4);}',
    '.site-footer .footer-newsletter button{background:#cddc39;color:#2c4621;font-weight:600;font-size:13px;padding:10px 16px;border:0;cursor:pointer;flex-shrink:0;white-space:nowrap;}',
    '.site-footer .footer-col h4{font-size:11px;font-weight:600;letter-spacing:0.14em;text-transform:uppercase;color:#cddc39;margin-bottom:18px;margin-top:0;}',
    '.site-footer .footer-col ul{list-style:none;padding:0;margin:0;display:flex;flex-direction:column;gap:10px;}',
    '.site-footer .footer-col li,.site-footer .footer-col a{font-size:14px;color:rgba(255,255,255,0.75);}',
    '.site-footer .footer-col a:hover{color:#cddc39;}',
    '.site-footer .footer-socials{display:flex;gap:8px;margin-top:18px;}',
    '.site-footer .footer-socials a{width:36px;height:36px;border-radius:50%;background:rgba(255,255,255,0.08);display:flex;align-items:center;justify-content:center;color:rgba(255,255,255,0.85);transition:background .15s,color .15s;}',
    '.site-footer .footer-socials a:hover{background:#cddc39;color:#2c4621;}',
    '.site-footer .footer-bottom{max-width:1240px;margin:0 auto;padding:20px 28px 0;border-top:1px solid rgba(255,255,255,0.1);display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px;font-size:12px;color:rgba(255,255,255,0.45);}',
    '@media(max-width:960px){.site-footer .footer-grid{grid-template-columns:1fr 1fr;}}',
    '@media(max-width:560px){.site-footer .footer-grid{grid-template-columns:1fr;}}'
  ].join('');
  document.head.appendChild(style);

  // Inject footer HTML
  var footerHTML = '<footer class="site-footer">'
    + '<div class="footer-grid">'

    // Col 1 — Brand
    + '<div>'
    + '<img src="images/website-sections/logo/tennisnuts-logo-transparent.png" alt="Tennisnuts" class="footer-brand-logo"/>'
    + '<p class="footer-tagline">The Social Side of Tennis. Founded in Pune in 2021. Open courts, easy doubles, lifelong rallies.</p>'
    + '<div class="footer-newsletter">'
    + '<input type="email" placeholder="Email — get weekly fixtures"/>'
    + '<button>Subscribe</button>'
    + '</div>'
    + '</div>'

    // Col 2 — Explore
    + '<div class="footer-col">'
    + '<h4>Explore</h4>'
    + '<ul>'
    + '<li><a href="index.html">Home</a></li>'
    + '<li><a href="academy.html">Academy</a></li>'
    + '<li><a href="partners.html">Partners</a></li>'
    + '<li><a href="blog.html">Blog</a></li>'
    + '</ul>'
    + '</div>'

    // Col 3 — Events
    + '<div class="footer-col">'
    + '<h4>Events</h4>'
    + '<ul>'
    + '<li><a href="socials.html">Tennisnuts Socials</a></li>'
    + '<li><a href="seniors.html">Seniors Tennis</a></li>'
    + '<li><a href="sopal-trophy.html">Sopal Club Championship</a></li>'
    + '<li><a href="corporate-tournament.html">Corporate Tournament</a></li>'
    + '<li><a href="tennis-clinics.html">Tennis Clinics</a></li>'
    + '</ul>'
    + '</div>'

    // Col 4 — Contact
    + '<div class="footer-col">'
    + '<h4>Contact</h4>'
    + '<ul>'
    + '<li>Pune, Maharashtra</li>'
    + '<li><a href="mailto:hello@tennisnuts.co.in">hello@tennisnuts.co.in</a></li>'
    + '</ul>'
    + '<div class="footer-socials">'
    + '<a href="#" aria-label="Instagram"><svg width="15" height="15" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none"/></svg></a>'
    + '<a href="#" aria-label="YouTube"><svg width="15" height="15" fill="currentColor" viewBox="0 0 24 24"><path d="M21.6 7.2a3 3 0 00-2.1-2.1C17.5 4.6 12 4.6 12 4.6s-5.5 0-7.5.5A3 3 0 002.4 7.2C2 9 2 12 2 12s0 3 .4 4.8a3 3 0 002.1 2.1c2 .5 7.5.5 7.5.5s5.5 0 7.5-.5a3 3 0 002.1-2.1c.4-1.8.4-4.8.4-4.8s0-3-.4-4.8zM10 15.4V8.6l5.5 3.4L10 15.4z"/></svg></a>'
    + '<a href="#" aria-label="WhatsApp"><svg width="15" height="15" fill="currentColor" viewBox="0 0 24 24"><path d="M20.5 3.5A10 10 0 003.4 16.3L2 22l5.9-1.4A10 10 0 0020.5 3.5z"/></svg></a>'
    + '<a href="#" aria-label="Facebook"><svg width="15" height="15" fill="currentColor" viewBox="0 0 24 24"><path d="M13.5 21v-8.2h2.8l.4-3.2h-3.2v-2c0-.9.3-1.6 1.6-1.6h1.7V3.2A23 23 0 0014.4 3c-2.4 0-4 1.5-4 4.1v2.5H7.6v3.2h2.8V21h3.1z"/></svg></a>'
    + '</div>'
    + '</div>'

    + '</div>'
    + '<div class="footer-bottom">'
    + '<span>© 2026 Tennisnuts Community · Pune, India · All rights reserved.</span>'
    + '<span>Built by players, for players.</span>'
    + '</div>'
    + '</footer>';

  var footerContainer = document.getElementById('site-footer');
  if (footerContainer) {
    footerContainer.innerHTML = footerHTML;
  }
})();
