// Supabase config — anon key is public-safe (never put service role key here)
const SUPABASE_URL  = 'https://kdfibfpvtynbhrulfioi.supabase.co';
const SUPABASE_ANON = 'sb_publishable_mxzgPUUeA6ewEIlYqTy1hQ_bSW4hbk3';

const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON, {
  auth: { persistSession: false }
});

// PIN hashing: SHA-256(email:pin) — email acts as per-user salt
async function hashPin(email, pin) {
  const raw = email.toLowerCase().trim() + ':' + String(pin).trim();
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(raw));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('');
}

// Set score options by format
function setScoreOptions(format) {
  return format === 'bo3' ? ['2-0', '2-1'] : ['3-0', '3-1', '3-2'];
}

// Countdown text from a lock_time ISO string
function countdownText(lockTime) {
  const diff = new Date(lockTime) - Date.now();
  if (diff <= 0) return 'Locked';
  const h = Math.floor(diff / 3600000);
  const m = Math.floor((diff % 3600000) / 60000);
  if (h > 48) return `${Math.floor(h/24)}d ${h%24}h`;
  if (h > 0)  return `${h}h ${m}m`;
  return `${m}m`;
}

// Format a date for display
function fmtDate(iso) {
  return new Date(iso).toLocaleString('en-IN', {
    day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
  });
}

// Tie-aware rank (spec §8: =13 format)
function rankList(items, scoreKey) {
  let rank = 1;
  return items.map((item, i, arr) => {
    if (i > 0 && item[scoreKey] < arr[i-1][scoreKey]) rank = i + 1;
    const tied = arr.filter(x => x[scoreKey] === item[scoreKey]).length > 1;
    return { ...item, rank: tied ? `=${rank}` : String(rank) };
  });
}
