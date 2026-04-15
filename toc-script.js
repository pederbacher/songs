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
   EDITOR  (reuses /song-source and /save-song endpoints)
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
    const res = await fetch("/song-source?file=" + encodeURIComponent(file));
    if (!res.ok) throw new Error("Server returned " + res.status);
    const data = await res.json();
    textarea.value = data.content;
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

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && document.getElementById("editorOverlay").classList.contains("active")) {
    closeEditor();
  }
});
