// TOC page controls: floating menu, editor, new collection, rebuild

const TOP_ZONE_PX = 110;
let autoHideTimeout = null;
let mouseOverControls = false;
let _editorFile = null;

const controls = document.getElementById("toc-controls");

function autoHideMenu() { controls.classList.add("fullyHidden"); }
function resetAutoHideTimer() {
  clearTimeout(autoHideTimeout);
  if (!mouseOverControls) autoHideTimeout = setTimeout(autoHideMenu, 500);
}
function showControls() {
  controls.classList.remove("fullyHidden");
  resetAutoHideTimer();
}

controls.addEventListener("mouseenter", () => { mouseOverControls = true; clearTimeout(autoHideTimeout); });
controls.addEventListener("mouseleave", () => { mouseOverControls = false; resetAutoHideTimer(); });

window.addEventListener("mousemove", (e) => {
  if (e.clientY <= TOP_ZONE_PX) showControls();
}, { passive: true });

// Highlight the link for the current page
document.querySelectorAll("#toc-nav-links a").forEach(a => {
  if (a.getAttribute("href") === window.location.pathname.split("/").pop()) {
    a.classList.add("current");
  }
});

// Hide Edit button when there is no backing collection file (main index)
if (!window.TOC_META || !window.TOC_META.collectionFile) {
  const btn = document.getElementById("toc-editBtn");
  if (btn) btn.style.display = "none";
}

/* ============================================================
   GITHUB-BACKED EDITING (used when not on localhost)
   Locally: server.py endpoints. On Pages: GitHub Contents API,
   which triggers .github/workflows/deploy.yml on push.
   ============================================================ */
const GH = { owner: "pederbacher", repo: "songs", branch: "main", dir: "songs" };

function ghMode() {
  const h = location.hostname;
  return !(h === "localhost" || h === "127.0.0.1" || h === "0.0.0.0" || h === "");
}
function ghToken(forceNew) {
  let t = localStorage.getItem("gh_token");
  if (!t || forceNew) {
    t = window.prompt(
      "Paste a GitHub token with 'Contents: Read and write' on " +
        GH.owner + "/" + GH.repo +
        ".\nIt is stored only in this browser (localStorage).",
      t || ""
    );
    if (t) { t = t.trim(); localStorage.setItem("gh_token", t); }
  }
  return t;
}
function ghClearToken() { localStorage.removeItem("gh_token"); }
function _b64encodeUtf8(s) { return btoa(unescape(encodeURIComponent(s))); }
function _b64decodeUtf8(b) { return decodeURIComponent(escape(atob(b.replace(/\n/g, "")))); }
function _ghContentsUrl(file) {
  return `https://api.github.com/repos/${GH.owner}/${GH.repo}/contents/` +
         `${GH.dir}/${encodeURIComponent(file)}`;
}
async function ghGetFile(file) {
  const headers = { Accept: "application/vnd.github+json" };
  const tok = localStorage.getItem("gh_token");
  if (tok) headers.Authorization = "Bearer " + tok;
  const res = await fetch(_ghContentsUrl(file) + "?ref=" + GH.branch, { headers });
  if (res.status === 404) return { content: "", sha: null };
  if (!res.ok) throw new Error("GitHub GET " + res.status);
  const data = await res.json();
  return { content: _b64decodeUtf8(data.content), sha: data.sha };
}
async function ghPutFile(file, content, message) {
  const tok = ghToken();
  if (!tok) throw new Error("No GitHub token provided");
  let sha = null;
  try { sha = (await ghGetFile(file)).sha; } catch (e) { /* treat as new */ }
  const body = {
    message: message || ("Edit " + file + " via web editor"),
    content: _b64encodeUtf8(content),
    branch: GH.branch,
  };
  if (sha) body.sha = sha;
  const res = await fetch(_ghContentsUrl(file), {
    method: "PUT",
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: "Bearer " + tok,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (res.status === 401 || res.status === 403) {
    ghClearToken();
    throw new Error("Auth failed (" + res.status + "). Token cleared — retry.");
  }
  if (!res.ok) {
    throw new Error("GitHub PUT " + res.status + ": " + (await res.text()).slice(0, 200));
  }
  return res.json();
}
function ghActionsUrl() {
  return `https://github.com/${GH.owner}/${GH.repo}/actions`;
}

/* ============================================================
   EDITOR (dual mode: server.py locally, GitHub API on Pages)
   ============================================================ */
async function _openEditorForFile(file) {
  const overlay  = document.getElementById("editorOverlay");
  const textarea = document.getElementById("editorTextarea");
  const status   = document.getElementById("editorStatus");
  const title    = document.getElementById("editorTitle");

  _editorFile = file;
  title.textContent = "Edit: " + file;
  status.textContent = "Loading…";
  textarea.value = "";
  overlay.classList.add("active");

  try {
    if (ghMode()) {
      textarea.value = (await ghGetFile(file)).content;
    } else {
      const res = await fetch("/song-source?file=" + encodeURIComponent(file));
      if (!res.ok) throw new Error("Server returned " + res.status);
      textarea.value = (await res.json()).content;
    }
    status.textContent = "";
    textarea.setSelectionRange(0, 0);
    textarea.scrollTop = 0;
    textarea.focus();
  } catch (err) {
    status.textContent = "Could not load source: " + err.message;
  }
}

function tocOpenEditor() {
  if (!window.TOC_META || !window.TOC_META.collectionFile) return;
  _openEditorForFile(window.TOC_META.collectionFile);
}

async function tocNewCollection() {
  const input = window.prompt("New collection name (e.g. summer_2026):");
  if (!input) return;
  // Strip any leading "collection-" the user may have typed, and .txt
  const name = input.trim().replace(/^collection-/i, "").replace(/\.txt$/i, "");
  if (!name) return;
  const file = "collection-" + name + ".txt";

  try {
    if (ghMode()) {
      const existing = await ghGetFile(file);
      if (existing.sha &&
          !window.confirm(file + " already exists. Open it for editing?")) return;
      _openEditorForFile(file);
      return;
    }
    const res = await fetch("/new-song", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ file }),
    });
    if (res.status === 409) {
      if (!window.confirm(file + " already exists. Open it for editing?")) return;
    } else if (!res.ok) {
      throw new Error("Server returned " + res.status);
    }
    _openEditorForFile(file);
  } catch (err) {
    alert("Could not create collection: " + err.message);
  }
}

function closeEditor() {
  document.getElementById("editorOverlay").classList.remove("active");
  document.getElementById("editorStatus").textContent = "";
  _editorFile = null;
}

async function saveEditor(andClose = false) {
  const file = _editorFile;
  if (!file) return;
  const content  = document.getElementById("editorTextarea").value;
  const status   = document.getElementById("editorStatus");

  status.textContent = "Saving…";
  try {
    if (ghMode()) {
      await ghPutFile(file, content);
      if (andClose) { closeEditor(); }
      else {
        status.textContent =
          "Committed. The site rebuilds automatically (~1–2 min); " +
          "reload afterwards.";
      }
      return;
    }
    const res = await fetch("/save-song", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ file, content }),
    });
    if (!res.ok) throw new Error("Server returned " + res.status);
    if (andClose) {
      closeEditor();
    } else {
      status.textContent = "Saved. Click Rebuild to regenerate HTML.";
    }
  } catch (err) {
    status.textContent = "Save failed: " + err.message;
  }
}

async function tocRebuildHtml() {
  if (ghMode()) {
    window.open(ghActionsUrl(), "_blank", "noopener");
    return;
  }
  const btn = document.getElementById("toc-rebuildBtn");
  const original = btn.textContent;
  btn.textContent = "Rebuilding…";
  btn.disabled = true;
  try {
    const res = await fetch("/rebuild", { method: "POST" });
    if (!res.ok) throw new Error("Server returned " + res.status);
    window.location.reload();
  } catch (err) {
    alert("Rebuild failed: " + err.message);
    btn.textContent = original;
    btn.disabled = false;
  }
}

// On the deployed site, relabel the Rebuild button to "Build" (status link).
if (ghMode()) {
  const _rb = document.getElementById("toc-rebuildBtn");
  if (_rb) { _rb.textContent = "Build"; _rb.title = "Open the GitHub Actions build status"; }
}

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && document.getElementById("editorOverlay").classList.contains("active")) {
    closeEditor();
  }
});
