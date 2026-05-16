// Tennisnuts — Homepage
const { useState, useRef, useEffect } = React;

// ---------- ICONS ----------
const Ic = {
  Arrow: (p) => <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M5 12h14M13 6l6 6-6 6"/></svg>,
  Play: (p) => <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor" {...p}><path d="M8 5v14l11-7z"/></svg>,
  Star: (p) => <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" {...p}><path d="M12 17.3l-6.18 3.7 1.64-7.03L2 9.24l7.19-.61L12 2l2.81 6.63L22 9.24l-5.46 4.73L18.18 21z"/></svg>,
  Pin: (p) => <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M12 21s-7-7.5-7-12a7 7 0 0114 0c0 4.5-7 12-7 12z"/><circle cx="12" cy="9" r="2.5"/></svg>,
  Clock: (p) => <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" {...p}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>,
  Users: (p) => <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}><circle cx="9" cy="8" r="3.5"/><path d="M2 21c0-3.5 3-6 7-6s7 2.5 7 6"/><circle cx="17" cy="9" r="2.5"/><path d="M22 21c0-2.5-1.8-4.5-5-4.5"/></svg>,
  // activity icons
  Confetti: (p) => <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" {...p}><path d="M4 20l8-14"/><path d="M14 4l2 2M18 8l2 2M20 14l2 0M16 18l2 1M12 20l1 2"/><circle cx="20" cy="6" r="1" fill="currentColor"/><circle cx="6" cy="14" r="1" fill="currentColor"/><circle cx="13" cy="16" r="1" fill="currentColor"/></svg>,
  Trophy: (p) => <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M8 4h8v5a4 4 0 01-8 0V4z"/><path d="M16 6h3a2 2 0 01-3 3.5M8 6H5a2 2 0 003 3.5"/><path d="M10 14h4l-1 4h-2l-1-4zM8 20h8"/></svg>,
  Briefcase: (p) => <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 012-2h2a2 2 0 012 2v2M3 13h18"/></svg>,
  Racket: (p) => <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}><ellipse cx="10" cy="10" rx="6" ry="7"/><path d="M14 14l6 6M6 7l8 6M7 11l6-6"/></svg>,
  Target: (p) => <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" {...p}><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/></svg>,
  Mic: (p) => <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}><rect x="9" y="3" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0014 0M12 18v3M9 21h6"/></svg>,
  Pen: (p) => <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M4 20l4-1 11-11-3-3L5 16l-1 4z"/><path d="M14 6l3 3"/></svg>,
  Heart: (p) => <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M12 21s-7-4.5-9.5-9A5 5 0 0112 6a5 5 0 019.5 6c-2.5 4.5-9.5 9-9.5 9z"/></svg>,
  // socials
  Insta: (p) => <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" {...p}><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.5" r="1" fill="currentColor" stroke="none"/></svg>,
  Yt: (p) => <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" {...p}><path d="M21.6 7.2a3 3 0 00-2.1-2.1C17.5 4.6 12 4.6 12 4.6s-5.5 0-7.5.5A3 3 0 002.4 7.2C2 9 2 12 2 12s0 3 .4 4.8a3 3 0 002.1 2.1c2 .5 7.5.5 7.5.5s5.5 0 7.5-.5a3 3 0 002.1-2.1c.4-1.8.4-4.8.4-4.8s0-3-.4-4.8zM10 15.4V8.6l5.5 3.4L10 15.4z"/></svg>,
  X: (p) => <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor" {...p}><path d="M17.5 3h3.2l-7 8 8.3 10h-6.5l-5.1-6.4L4.5 21H1.3l7.5-8.6L0.8 3h6.6l4.6 5.9L17.5 3zm-1.1 16h1.8L7.7 4.9H5.8l10.6 14.1z"/></svg>,
  Wa: (p) => <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" {...p}><path d="M20.5 3.5A10 10 0 003.4 16.3L2 22l5.9-1.4A10 10 0 0020.5 3.5zM12 20.2a8.2 8.2 0 01-4.2-1.2l-.3-.2-3.5.9.9-3.4-.2-.3a8.2 8.2 0 1115.5-3.7A8.2 8.2 0 0112 20.2zm4.6-6.1c-.3-.1-1.5-.7-1.7-.8-.2-.1-.4-.1-.6.1l-.8 1c-.2.2-.3.2-.6.1a6.7 6.7 0 01-2-1.2 7.5 7.5 0 01-1.4-1.8c-.2-.3 0-.4.1-.6l.4-.4c.1-.1.2-.3.3-.5 0-.2 0-.4 0-.5l-.7-1.6c-.2-.4-.4-.4-.6-.4h-.5a1 1 0 00-.7.3 3 3 0 00-1 2.3 5.2 5.2 0 001.1 2.8 11.8 11.8 0 004.5 4c.6.3 1.1.4 1.5.5.6.2 1.2.2 1.7.1.5-.1 1.5-.6 1.7-1.2.2-.6.2-1.1.2-1.2-.1-.1-.3-.2-.6-.3z"/></svg>,
  Fb: (p) => <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor" {...p}><path d="M13.5 21v-8.2h2.8l.4-3.2h-3.2v-2c0-.9.3-1.6 1.6-1.6h1.7V3.2A23 23 0 0014.4 3c-2.4 0-4 1.5-4 4.1v2.5H7.6v3.2h2.8V21h3.1z"/></svg>,
};

// ---------- DATA ----------
const ACTIVITIES = [
  { i: <Ic.Confetti/>, t: "Tennisnuts Socials", d: "Weekend mixer sessions where rallies turn into friendships." },
  { i: <Ic.Trophy/>,   t: "Narendra Sopal Trophy", d: "Our flagship invitational — heart, hustle, and trophy chasing." },
  { i: <Ic.Briefcase/>,t: "Corporate Tournament", d: "Bring your team, leave the spreadsheets. Game on." },
  { i: <Ic.Racket/>,   t: "Tennis Clinics", d: "Open-format clinics for beginners to club-level players." },
  { i: <Ic.Target/>,   t: "Focused Coaching", d: "Targeted drills with pros to sharpen one weak spot at a time." },
  { i: <Ic.Mic/>,      t: "Tennis Bytes Podcast", d: "Conversations with players, coaches, and people who love the game." },
  { i: <Ic.Pen/>,      t: "Nuts Blog", d: "Stories from the court — match notes, tips, and player journeys." },
  { i: <Ic.Heart/>,    t: "Social Work", d: "Putting rackets in more hands. Community drives + scholarships." },
];

const EVENTS = [
  { tag: "Tournament", d: "24", m: "May", title: "Narendra Sopal Trophy '26", place: "PYC Hindu Gymkhana, Pune", time: "Sat 7:00 AM • Doubles", spots: "12", banner: "ev-b-2" },
  { tag: "Social",     d: "31", m: "May", title: "Sunday Sundowner Mixer", place: "Deccan Gymkhana", time: "Sun 5:30 PM • All levels", spots: "8",  banner: "ev-b-1" },
  { tag: "Clinic",     d: "07", m: "Jun", title: "Serve & Volley Clinic", place: "Balewadi Sports Complex", time: "Sat 6:00 AM • Intermediate", spots: "4", banner: "ev-b-4" },
  { tag: "Corporate",  d: "14", m: "Jun", title: "Pune Corporate Cup '26", place: "Poona Club Courts", time: "Sat–Sun • Team event", spots: "16", banner: "ev-b-3" },
  { tag: "Podcast",    d: "20", m: "Jun", title: "Tennis Bytes Live #14", place: "The Pavilion, Aundh", time: "Fri 7:30 PM • Free entry", spots: "Open", banner: "ev-b-5" },
];

const TESTS = [
  { q: "Tennisnuts didn't just get me back on court — it gave me a Sunday morning crew I genuinely look forward to. Best decision of the year.", n: "Aditi Rane", r: "4.0 player, Koregaon Park", a: "AR" },
  { q: "Walked in nervous, no club, no doubles partner. Walked out with eight new friends and a tournament entry. That's the magic.", n: "Karan Mehta", r: "Returning player, Baner", a: "KM" },
];

const LOGOS = ["Manegrow", "Capovítèz", "Solinco", "SportsJam", "PMDTA"];

// ---------- LOGO ----------
function Logo({ light }) {
  return (
    <div className="brand">
      <div className="brand-mark"></div>
      <div>
        <div style={{ color: light ? "#fff" : "var(--ink)" }}>Tennisnuts</div>
        <small>The Social Side of Tennis</small>
      </div>
    </div>
  );
}

// ---------- NAV ----------
function Nav() {
  return (
    <header className="nav">
      <div className="container nav-inner">
        <a href="#" aria-label="Tennisnuts home"><Logo/></a>
        <nav className="nav-links" aria-label="Primary">
          <a href="#who">About</a>
          <a href="#activities">Activities</a>
          <a href="#events">Events</a>
          <a href="#partners">Partners</a>
          <a href="#">Blog</a>
        </nav>
        <a href="#join" className="nav-cta">Join the Club <Ic.Arrow/></a>
      </div>
    </header>
  );
}

// ---------- HERO ----------
function Hero() {
  return (
    <section className="hero">
      <div className="hero-bg"></div>
      <div className="hero-photo"></div>
      <div className="hero-noise"></div>
      <div className="container">
        <div className="hero-content">
          <div>
            <div className="hero-eyebrow"><span className="dot"></span> Pune's friendliest tennis community · 800+ members</div>
            <h1>
              The <span className="accent">Social</span> Side<br/>
              of Tennis.
            </h1>
            <p className="hero-sub">
              Open courts, easy doubles, big tournaments, and the kind of post-match
              chai sessions that turn opponents into your weekend regulars.
            </p>
            <div className="hero-ctas">
              <a href="#join" className="btn btn-ball">Join Us <Ic.Arrow/></a>
              <a href="#events" className="btn btn-ghost"><Ic.Play/> Explore Events</a>
            </div>
            <div className="hero-stats">
              <div className="stat"><div className="num">800+</div><div className="label">Active Members</div></div>
              <div className="stat"><div className="num">40+</div><div className="label">Events / Year</div></div>
              <div className="stat"><div className="num">12</div><div className="label">Partner Courts</div></div>
            </div>
          </div>

          <div className="hero-collage" aria-hidden="true">
            <div className="hero-card hero-card-1"><div className="ph">/* action shot — forehand at sunset */</div></div>
            <div className="hero-card hero-card-2"><div className="ph">/* group huddle, post match */</div></div>
            <div className="hero-card hero-card-3"><div className="ph">/* trophy presentation */</div></div>
            <div className="hero-ball"></div>
          </div>
        </div>
      </div>

      <div className="hero-ribbon" aria-hidden="true">
        <div className="marquee">
          {Array.from({length: 2}).map((_, j) => (
            <span key={j}>
              Rally · <span className="dot"></span> · Social · <span className="dot"></span> · Compete · <span className="dot"></span> · Coach · <span className="dot"></span> · Give Back · <span className="dot"></span> · Rally · <span className="dot"></span> · Social · <span className="dot"></span> · Compete · <span className="dot"></span> · Coach · <span className="dot"></span> · Give Back · <span className="dot"></span> ·&nbsp;
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}

// ---------- WHO ----------
function Who() {
  return (
    <section className="section who" id="who">
      <div className="container">
        <div className="who-grid">
          <div className="who-copy">
            <div className="section-eyebrow">Who we are</div>
            <h2>A tennis club that doesn't feel like one.</h2>
            <p>
              Tennisnuts started with a few friends in Pune who wanted somewhere to
              play that wasn't stiff, wasn't expensive, and didn't require knowing
              the right people. Five years later we're still that — just with more
              of us.
            </p>
            <p>
              We run weekend socials, organise the city's most-loved invitationals,
              put new players on court with coaches who care, and keep the chai
              flowing well past stumps. <b>Fair play, real friendships, and a
              healthy obsession with tennis.</b>
            </p>
            <div className="who-tags">
              <span className="who-tag"><span className="b"></span> Open to all levels</span>
              <span className="who-tag"><span className="b"></span> Singles · Doubles · Mixed</span>
              <span className="who-tag"><span className="b"></span> Pune-wide</span>
              <span className="who-tag"><span className="b"></span> Est. 2021</span>
            </div>
          </div>
          <div style={{position:"relative"}}>
            <div className="who-photo">
              <div className="ph-label">photo · group huddle on court</div>
            </div>
            <div className="who-badge">
              <span style={{position:"absolute", top:18, left:0, right:0}}>· FAIR PLAY · ·</span>
              <span style={{position:"absolute", bottom:18, left:0, right:0}}>· REAL FRIENDS ·</span>
              <div className="core">🎾</div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ---------- ACTIVITIES ----------
function Activities() {
  return (
    <section className="section activities" id="activities">
      <div className="container">
        <div className="section-head">
          <div>
            <div className="section-eyebrow">What we do</div>
            <h2>Eight ways to be a Tennisnut.</h2>
          </div>
          <div className="right">
            From low-key Sunday socials to the city's most chased trophy.
            Show up for one, stay for all of them.
          </div>
        </div>

        <div className="act-grid">
          {ACTIVITIES.map((a, i) => (
            <div key={a.t} className="act-card">
              <div className="head">
                <div className="icon">{a.i}</div>
                <div className="num">0{i+1}</div>
              </div>
              <div className="body">
                <h3>{a.t}</h3>
                <p>{a.d}</p>
                <span className="more">Learn more <Ic.Arrow/></span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ---------- EVENTS ----------
function Events() {
  const scrollRef = useRef(null);
  const scroll = (dir) => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollBy({ left: dir * 400, behavior: "smooth" });
  };
  return (
    <section className="section events" id="events">
      <div className="container">
        <div className="section-head">
          <div>
            <div className="section-eyebrow">Upcoming events</div>
            <h2>Pick a Saturday, show up, play.</h2>
          </div>
          <div className="right" style={{display:"flex", alignItems:"end", justifyContent:"space-between", gap:24}}>
            <div>Free for members. Visitors welcome at most sessions.</div>
            <div className="events-nav">
              <button onClick={() => scroll(-1)} aria-label="Previous"><Ic.Arrow style={{transform:"rotate(180deg)"}}/></button>
              <button onClick={() => scroll(1)}  aria-label="Next"><Ic.Arrow/></button>
            </div>
          </div>
        </div>
      </div>

      <div className="container">
        <div className="events-scroll" ref={scrollRef}>
          {EVENTS.map((e, i) => (
            <div key={i} className="event-card">
              <div className={`event-banner ${e.banner}`}>
                <div className="ph-tag">{e.tag}</div>
                <div className="date"><div className="d">{e.d}</div><div className="m">{e.m}</div></div>
              </div>
              <div className="event-body">
                <h3>{e.title}</h3>
                <div className="event-meta">
                  <div><Ic.Pin className="ic"/> {e.place}</div>
                  <div><Ic.Clock className="ic"/> {e.time}</div>
                </div>
                <div className="event-foot">
                  <div className="spots"><Ic.Users style={{verticalAlign:"middle", marginRight:6, color:"var(--green)"}}/> <b>{e.spots}</b> spots left</div>
                  <a href="#" className="btn btn-primary btn-small">Register</a>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ---------- TESTIMONIALS ----------
function Testimonials() {
  return (
    <section className="section testimonials">
      <div className="container">
        <div className="section-head">
          <div>
            <div className="section-eyebrow">From the courts</div>
            <h2>Players say it best.</h2>
          </div>
        </div>
        <div className="test-grid">
          {TESTS.map((t, i) => (
            <div key={i} className="test-card">
              <div className="test-quote-mark">"</div>
              <div className="stars">
                {Array.from({length:5}).map((_, k) => <Ic.Star key={k}/>)}
              </div>
              <blockquote>{t.q}</blockquote>
              <div className="test-author">
                <div className="test-avatar">{t.a}</div>
                <div className="who">
                  <div className="name">{t.n}</div>
                  <div className="role">{t.r}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ---------- PARTNERS ----------
function Partners() {
  return (
    <section className="partners" id="partners">
      <div className="container">
        <div className="partners-row">
          <h3>Played with the best.<span>Our partners</span></h3>
          <div className="logos">
            {LOGOS.map((l, i) => (
              <div key={l} className={`logo-chip b${i+1}`}>
                <span className="lm"></span>{l}
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

// ---------- FOOTER ----------
function Footer() {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-grid">
          <div className="footer-brand">
            <Logo light/>
            <p>The Social Side of Tennis. Founded in Pune in 2021. Open courts, easy doubles, lifelong rallies.</p>
            <div className="footer-newsletter">
              <input placeholder="Your email — get the weekly fixtures"/>
              <button>Subscribe</button>
            </div>
          </div>
          <div className="footer-col">
            <h4>Explore</h4>
            <ul>
              <li><a href="#">Home</a></li>
              <li><a href="#who">About</a></li>
              <li><a href="#activities">Activities</a></li>
              <li><a href="#events">Events</a></li>
              <li><a href="#">Blog</a></li>
              <li><a href="#">Contact</a></li>
            </ul>
          </div>
          <div className="footer-col">
            <h4>Programs</h4>
            <ul>
              <li><a href="#">Sopal Trophy</a></li>
              <li><a href="#">Corporate Cup</a></li>
              <li><a href="#">Clinics</a></li>
              <li><a href="#">Coaching</a></li>
              <li><a href="#">Podcast</a></li>
            </ul>
          </div>
          <div className="footer-col">
            <h4>Visit</h4>
            <ul>
              <li>Pune, Maharashtra</li>
              <li>hello@tennisnuts.co.in</li>
              <li>+91 90000 00000</li>
            </ul>
            <h4 style={{marginTop:28}}>Follow</h4>
            <div className="socials">
              <a href="#" aria-label="Instagram"><Ic.Insta/></a>
              <a href="#" aria-label="YouTube"><Ic.Yt/></a>
              <a href="#" aria-label="WhatsApp"><Ic.Wa/></a>
              <a href="#" aria-label="Facebook"><Ic.Fb/></a>
              <a href="#" aria-label="X"><Ic.X/></a>
            </div>
          </div>
        </div>
        <div className="footer-bottom">
          <div>© 2026 Tennisnuts Community · Pune, India · All rights reserved.</div>
          <div>Built by players, for players. 🎾</div>
        </div>
      </div>
    </footer>
  );
}

// ---------- APP ----------
function App() {
  return (
    <>
      <Nav/>
      <main>
        <Hero/>
        <Who/>
        <Activities/>
        <Events/>
        <Testimonials/>
        <Partners/>
      </main>
      <Footer/>
    </>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
