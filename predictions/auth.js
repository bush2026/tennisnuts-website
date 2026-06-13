// Auth module — session lives in sessionStorage, validated server-side on load

const SESSION_KEY = 'tn_pred_session';

function getSession() {
  try { return JSON.parse(sessionStorage.getItem(SESSION_KEY)); }
  catch { return null; }
}

function _setSession(data) {
  sessionStorage.setItem(SESSION_KEY, JSON.stringify(data));
}

function clearSession() {
  sessionStorage.removeItem(SESSION_KEY);
}

async function login(email, pin) {
  const pin_hash = await hashPin(email, pin);
  const { data, error } = await db.rpc('authenticate_member', {
    p_email:    email.toLowerCase().trim(),
    p_pin_hash: pin_hash
  });
  if (error) return { success: false, message: error.message };
  if (data?.success) _setSession(data);
  return data;
}

async function logout() {
  const s = getSession();
  if (s?.session_token) {
    await db.rpc('logout_member', { p_session_token: s.session_token });
  }
  clearSession();
  window.location.href = 'index.html';
}

// Validate session on page load — returns session object or null
async function restoreSession() {
  const s = getSession();
  if (!s?.session_token) return null;
  const { data, error } = await db.rpc('validate_session', { p_session_token: s.session_token });
  if (error || !data?.valid) { clearSession(); return null; }
  // Refresh local session with latest server state
  const fresh = { ...s, display_name: data.display_name, is_admin: data.is_admin };
  _setSession(fresh);
  return fresh;
}

// Require auth — call at top of protected pages
async function requireAuth(adminRequired = false) {
  const s = await restoreSession();
  if (!s) {
    window.location.href = 'index.html';
    return null;
  }
  if (adminRequired && !s.is_admin) {
    window.location.href = 'index.html';
    return null;
  }
  return s;
}
