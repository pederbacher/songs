// --- Environment detection
const isFirefox = navigator.userAgent.toLowerCase().includes("firefox");

// --- Globals
let autoHideTimeout = null;
let lastScrollY = 0;          // kept for completeness
let splitMode = false;        // split view state
let isSyncingScroll = false;  // prevent recursive scroll syncing

// Master menu visibility via mouse right edge (10%)
let mouseInRightEdge = false; // rightmost 10% of window triggers menu show

// Split TOTAL width control (both panes grow/shrink together)
let splitScale = 1.0;         // fraction of viewport width (0..1)
let hoveredPane = null;       // 'left', 'right', or null
const SCALE_STEP = 0.05;
const SCALE_MIN = 0.50;
const SCALE_MAX = 1.00;

// Per-pane toolbar auto-hide state
const paneHide = {
  left: { timer: null, installed: false },
  right: { timer: null, installed: false },
};
const TOP_ZONE_PX = 110;  // mouse must be within this top area to show toolbars
const HIDE_DELAY_MS = 500;

const controls = document.getElementById("controls");

// --- Utility: current vertical scroll position (for some logic if needed)
function getCurrentScrollY() {
  if (splitMode) {
    const left = document.getElementById("paneLeft");
    return left ? left.scrollTop : 0;
  }
  return window.scrollY;
}

// --- Utility: scroll targets (document or both panes)
function getDocScrollElement() {
  return document.scrollingElement || document.documentElement;
}
function getScrollTargets() {
  if (splitMode) {
    const l = document.getElementById("paneLeft");
    const r = document.getElementById("paneRight");
    return [l, r].filter(Boolean);
  }
  return [getDocScrollElement()];
}
function allTargetsAtBottom(targets) {
  return targets.every(
    (el) => el.scrollTop + el.clientHeight >= el.scrollHeight - 1
  );
}

/* ============================================================
   MASTER MENU: Appear when mouse enters rightmost 10% (both modes)
   Auto-hide after 3s of inactivity.
   ============================================================ */
let mouseOverControls = false;

function autoHideMenu() {
  controls.classList.add("fullyHidden");
}
function resetAutoHideTimer() {
  clearTimeout(autoHideTimeout);
  if (!mouseOverControls) {
    autoHideTimeout = setTimeout(autoHideMenu, 500);
  }
}
function showControls() {
  controls.classList.remove("fullyHidden");
  resetAutoHideTimer();
}

// Keep controls visible while the mouse is over them
controls.addEventListener("mouseenter", () => { mouseOverControls = true;  clearTimeout(autoHideTimeout); });
controls.addEventListener("mouseleave", () => { mouseOverControls = false; resetAutoHideTimer(); });

// Track mouse — in single mode show controls when in top zone; hidden in split mode
window.addEventListener("mousemove", (e) => {
  if (!splitMode && e.clientY <= TOP_ZONE_PX) {
    showControls();
  }
}, { passive: true });

// Keep lastScrollY updated (not used for menu visibility anymore, but harmless)
window.addEventListener("scroll", () => {
  lastScrollY = getCurrentScrollY();
}, { passive: true });

/* ============================================================
   AUTO-SCROLL (Firefox vs. Chrome) with split-view support
   Global API used by master and per-pane toolbars
   ============================================================ */
let api = {
  startstop: null,
  speedUp: null,
  speedDown: null,
};

if (isFirefox) {
  // ---------- FIREFOX: precise rAF scrolling
  let speed = 10; // pixels per second (can be fractional via accumulator)
  let scrolling = false;
  let lastTimestamp = 0;
  let fractionalAccumulator = 0;

  function scrollStep(timestamp) {
    if (!scrolling) return;

    if (!lastTimestamp) lastTimestamp = timestamp;
    const delta = timestamp - lastTimestamp;
    lastTimestamp = timestamp;

    // precise movement
    const exactPixels = (speed * delta) / 1000;
    fractionalAccumulator += exactPixels;

    // apply whole pixels to all targets
    const wholePixels = Math.floor(fractionalAccumulator);
    if (wholePixels > 0) {
      const targets = getScrollTargets();
      targets.forEach((el) => (el.scrollTop += wholePixels));
      fractionalAccumulator -= wholePixels;
    }

    requestAnimationFrame(scrollStep);
  }

  function startstop() {
    const btn = document.getElementById("startstop");
    if (!scrolling) {
      scrolling = true;
      lastTimestamp = 0;
      requestAnimationFrame(scrollStep);
      if (btn) btn.textContent = "Stop";
    } else {
      scrolling = false;
      if (btn) btn.textContent = "Start";
    }
  }
  function speedUp() { speed += 2; }
  function speedDown() { speed = Math.max(0.5, speed - 2); }

  // Hook global (master) buttons
  document.getElementById("faster").onclick = speedUp;
  document.getElementById("slower").onclick = speedDown;

  // expose
  api.startstop = startstop;
  api.speedUp = speedUp;
  api.speedDown = speedDown;
  api.getSpeed = () => speed;
  window.startstop = startstop;
} else {
  // ---------- CHROME/OTHERS: small-step setInterval scrolling
  let speed = 10; // default "units per second"
  let intervalId = null;

  function getZoomViaDPR() {
    return window.devicePixelRatio || 1;
  }

  function tick() {
    const step = 0.7 / getZoomViaDPR(); // must be >= ~0.2 to move
    const targets = getScrollTargets();

    // If in single mode targeting the document, use window.scrollBy for consistency
    if (!splitMode && targets[0] === getDocScrollElement()) {
      window.scrollBy(0, step);
    } else {
      targets.forEach((el) => (el.scrollTop += step));
    }
  }

  function updateSpeed() {
    if (intervalId) clearInterval(intervalId);
    intervalId = setInterval(tick, 1000 / speed);
  }

  function startstop() {
    const btn = document.getElementById("startstop");
    if (!intervalId) {
      updateSpeed();
      if (btn) btn.textContent = "Stop";
    } else {
      clearInterval(intervalId);
      intervalId = null;
      if (btn) btn.textContent = "Start";
    }
  }
  function speedUp() {
    speed += 5;
    if (document.getElementById("startstop")?.textContent === "Stop") {
      updateSpeed();
    }
  }
  function speedDown() {
    speed = Math.max(1, speed - 5);
    if (document.getElementById("startstop")?.textContent === "Stop") {
      updateSpeed();
    }
  }

  // Hook global (master) buttons
  document.getElementById("faster").onclick = speedUp;
  document.getElementById("slower").onclick = speedDown;

  // expose
  api.startstop = startstop;
  api.speedUp = speedUp;
  api.speedDown = speedDown;
  api.getSpeed = () => speed;
  window.startstop = startstop;
}

/* ============================================================
   SPEED INDICATOR: brief toast showing current speed
   ============================================================ */
let toastTimer = null;
function showToast(text) {
  const el = document.getElementById("speedIndicator");
  if (!el) return;
  el.textContent = text;
  el.classList.add("visible");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("visible"), 1000);
}
function showSpeedIndicator() { showToast(Math.round(api.getSpeed())); }

/* ============================================================
   TRANSPOSE (single + per-pane)
   ============================================================ */
const groups = [
  "no0","no1","no2","no3",
  "no4","no5","no6","no7",
  "no8","no9","no10","no11"
];
let currentIndex = 0; // single mode

function showGroup(index) {
  // single mode: affect global content
  document.querySelectorAll("#pageContent .chordline").forEach((el) => {
    el.style.display = "none";
  });
  if (index >= 0) {
    document
      .querySelectorAll("#pageContent ." + groups[index])
      .forEach((el) => (el.style.display = "inline-block"));
    currentIndex = index;
    // Highlight active transpose button
    document.querySelectorAll("#transposeButtons button").forEach((btn, i) => {
      btn.classList.toggle("active", i === index);
    });
  }
}
function up() {
  const newIndex = (currentIndex + 1) % groups.length;
  showGroup(newIndex);
}
function down() {
  const newIndex = (currentIndex - 1 + groups.length) % groups.length;
  showGroup(newIndex);
}
function hideshowchords() {
  const btn = document.getElementById("toggleChords");
  const rows = document.querySelectorAll("#pageContent .chordrow");
  if (btn.textContent === "ChordsHide") {
    btn.textContent = "ChordsShow";
    rows.forEach(r => r.style.display = "none");
    document.getElementById("pageContent").classList.add("chords-hidden");
    showGroup(-1);
  } else {
    btn.textContent = "ChordsHide";
    rows.forEach(r => r.style.display = "");
    document.getElementById("pageContent").classList.remove("chords-hidden");
    showGroup(currentIndex);
  }
}
window.up = up;
window.down = down;
window.hideshowchords = hideshowchords;

// Wrap each chord row (12 transposition spans + trailing \n) in a .chordrow
// so the entire line can be hidden without leaving a blank gap.
function wrapChordRows(container) {
  const pre = container.querySelector('pre');
  if (!pre) return;
  const children = Array.from(pre.childNodes);
  let i = 0;
  while (i < children.length) {
    const node = children[i];
    if (node.nodeType === Node.ELEMENT_NODE && node.classList.contains('chordline')) {
      const wrapper = document.createElement('span');
      wrapper.className = 'chordrow';
      pre.insertBefore(wrapper, node);
      // Collect all consecutive chordline spans
      while (i < children.length &&
             children[i] &&
             children[i].nodeType === Node.ELEMENT_NODE &&
             children[i].classList.contains('chordline')) {
        wrapper.appendChild(children[i]);
        i++;
      }
      // Include the trailing newline so hiding the wrapper removes the blank line
      if (i < children.length &&
          children[i] &&
          children[i].nodeType === Node.TEXT_NODE &&
          children[i].textContent === '\n') {
        wrapper.appendChild(children[i]);
        i++;
      }
    } else {
      i++;
    }
  }
}

// Initialize first chord group (single mode)
showGroup(0);
wrapChordRows(document.getElementById('pageContent'));

/* ============================================================
   SPLIT VIEW: Two synced panes with per-pane toolbars
   - TOTAL width control via master +width/-width buttons
   - Per-pane toolbars auto-hide and appear when mouse in top of pane
   ============================================================ */
const paneState = {
  left: { index: 0, chordsVisible: true },
  right: { index: 0, chordsVisible: true },
};

function ensureSplitContainer() {
  if (document.getElementById("splitContainer")) return;

  const split = document.createElement("div");
  split.id = "splitContainer";

  function paneToolbarHTML(side) {
    return `
    <div class="paneControls hidden" data-pane="${side}">
      <button data-action="startstop">Start</button>
      <button data-action="faster" class="speed-btn">+</button>
      <button data-action="slower" class="speed-btn">-</button>
      <button data-action="toggleChords">ChordsHide</button>
      <button data-action="toc" class="speed-btn">TOC</button>
      <button data-action="single">Single</button>
      <div class="paneTransposeButtons">
        ${Array.from({length: 12}, (_, i) => `<button data-action="transpose" data-index="${i}">${i}</button>`).join('')}
      </div>
    </div>
    <div class="paneContent"></div>
  `;
  }

  const left = document.createElement("div");
  left.className = "split-pane";
  left.id = "paneLeft";
  left.innerHTML = paneToolbarHTML("left");

  const right = document.createElement("div");
  right.className = "split-pane";
  right.id = "paneRight";
  right.innerHTML = paneToolbarHTML("right");

  split.appendChild(left);
  split.appendChild(right);

  const pageContent = document.getElementById("pageContent");
  pageContent.insertAdjacentElement("afterend", split);
}

function paneShowGroup(paneContentEl, index) {
  const chordlines = paneContentEl.querySelectorAll(".chordline");
  chordlines.forEach((el) => (el.style.display = "none"));
  if (index >= 0) {
    paneContentEl
      .querySelectorAll("." + groups[index])
      .forEach((el) => (el.style.display = "inline-block"));
  }
}

function paneSetGroup(paneKey, index) {
  const paneRoot = document.getElementById(`pane${capitalize(paneKey)}`);
  if (!paneRoot) return;
  const contentEl = paneRoot.querySelector(".paneContent");
  const toolbar   = paneRoot.querySelector(".paneControls");
  paneState[paneKey].index = index;
  paneShowGroup(contentEl, index);
  if (toolbar) {
    toolbar.querySelectorAll("[data-action='transpose']").forEach((b, i) => {
      b.classList.toggle("active", i === index);
    });
  }
}
function paneUp(paneKey) {
  paneSetGroup(paneKey, (paneState[paneKey].index + 1) % groups.length);
}
function paneDown(paneKey) {
  paneSetGroup(paneKey, (paneState[paneKey].index - 1 + groups.length) % groups.length);
}

function attachPaneScrollSync() {
  const left = document.getElementById("paneLeft");
  const right = document.getElementById("paneRight");
  if (!left || !right) return;

  function sync(source, target) {
    if (isSyncingScroll) return;
    isSyncingScroll = true;

    const sMax = source.scrollHeight - source.clientHeight;
    const tMax = target.scrollHeight - target.clientHeight;
    const perc = sMax > 0 ? source.scrollTop / sMax : 0;

    target.scrollTop = perc * tMax;
    isSyncingScroll = false;
  }

  left.addEventListener("scroll", () => sync(left, right), { passive: true });
  right.addEventListener("scroll", () => sync(right, left), { passive: true });
}

function wirePaneToolbar(toolbarEl) {
  // Remove old listeners if re-enabling split
  const fresh = toolbarEl.cloneNode(true);
  toolbarEl.parentNode.replaceChild(fresh, toolbarEl);

  const paneKey = fresh.getAttribute("data-pane"); // 'left' or 'right'
  const paneRoot =
    paneKey === "left" ? document.getElementById("paneLeft") : document.getElementById("paneRight");
  const contentEl = paneRoot.querySelector(".paneContent");

  fresh.addEventListener("click", (e) => {
    const btn = e.target.closest("button[data-action]");
    if (!btn) return;
    const action = btn.getAttribute("data-action");

    switch (action) {
      case "startstop":
        api.startstop();
        break;
      case "faster":
        api.speedUp();
        break;
      case "slower":
        api.speedDown();
        break;
      case "transpose": {
        const idx = parseInt(btn.getAttribute("data-index"));
        paneState[paneKey].index = idx;
        paneShowGroup(contentEl, idx);
        fresh.querySelectorAll("[data-action='transpose']").forEach((b, i) => {
          b.classList.toggle("active", i === idx);
        });
        break;
      }
      case "toggleChords": {
        const st = paneState[paneKey];
        st.chordsVisible = !st.chordsVisible;
        btn.textContent = st.chordsVisible ? "ChordsHide" : "ChordsShow";
        if (st.chordsVisible) {
          contentEl.querySelectorAll(".chordrow").forEach(r => r.style.display = "");
          contentEl.classList.remove("chords-hidden");
          paneShowGroup(contentEl, st.index);
        } else {
          contentEl.querySelectorAll(".chordrow").forEach(r => r.style.display = "none");
          contentEl.classList.add("chords-hidden");
        }
        break;
      }
      case "toc":
        window.location.href = "index.html";
        break;
      case "single":
        disableSplitView();
        break;
    }
  });

  return fresh;
}

/* ---------- Per-pane toolbar auto-hide ---------- */
function showPaneControls(paneKey) {
  const toolbar = document.querySelector(`#pane${capitalize(paneKey)} .paneControls`);
  if (!toolbar) return;
  toolbar.classList.remove("hidden");

  // Clear any pending hide timer
  if (paneHide[paneKey].timer) {
    clearTimeout(paneHide[paneKey].timer);
    paneHide[paneKey].timer = null;
  }
}
function hidePaneControlsLater(paneKey) {
  if (paneHide[paneKey].timer) clearTimeout(paneHide[paneKey].timer);
  paneHide[paneKey].timer = setTimeout(() => {
    const toolbar = document.querySelector(`#pane${capitalize(paneKey)} .paneControls`);
    toolbar?.classList.add("hidden");
  }, HIDE_DELAY_MS);
}
function installPaneAutoHide(paneKey) {
  if (paneHide[paneKey].installed) return; // install only once
  paneHide[paneKey].installed = true;

  const pane = document.getElementById(`pane${capitalize(paneKey)}`);
  const toolbar = pane.querySelector(".paneControls");

  // Show when mouse is inside the top zone of the pane
  pane.addEventListener("mousemove", (e) => {
    const bounds = pane.getBoundingClientRect();
    const y = e.clientY - bounds.top;
    if (y <= TOP_ZONE_PX) {
      showPaneControls(paneKey);
    } else {
      // start hide timer when moving away from top
      hidePaneControlsLater(paneKey);
    }
  });

  // Keep visible while hovering the toolbar itself
  toolbar.addEventListener("mouseenter", () => showPaneControls(paneKey));
  toolbar.addEventListener("mouseleave", () => hidePaneControlsLater(paneKey));

  // Start hidden shortly after enabling split
  setTimeout(() => hidePaneControlsLater(paneKey), 1200);
}

function capitalize(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

/* ---------- TOTAL split width control ---------- */
function applySplitTotalWidth() {
  const split = document.getElementById("splitContainer");
  if (!split) return;
  const vw = Math.round(splitScale * 100);
  split.style.setProperty("--split-width", `${vw}vw`);
}

function enableSplitView() {
  ensureSplitContainer();

  const split = document.getElementById("splitContainer");
  const leftPane = document.getElementById("paneLeft");
  const rightPane = document.getElementById("paneRight");
  const leftContent = leftPane.querySelector(".paneContent");
  const rightContent = rightPane.querySelector(".paneContent");
  const pageContent = document.getElementById("pageContent");

  // Clone inner HTML (avoid duplicate IDs)
  leftContent.innerHTML = pageContent.innerHTML;
  rightContent.innerHTML = pageContent.innerHTML;

  // Initialize per-pane chord state
  paneState.left.index = 0;
  paneState.left.chordsVisible = true;
  paneShowGroup(leftContent, paneState.left.index);

  paneState.right.index = 0;
  paneState.right.chordsVisible = true;
  paneShowGroup(rightContent, paneState.right.index);

  // Wire pane toolbars (replace nodes to avoid duplicate listeners)
  const leftToolbar  = wirePaneToolbar(leftPane.querySelector(".paneControls"));
  const rightToolbar = wirePaneToolbar(rightPane.querySelector(".paneControls"));

  // Highlight initial transpose button (index 0) in each pane
  leftToolbar.querySelectorAll("[data-action='transpose']")[0]?.classList.add("active");
  rightToolbar.querySelectorAll("[data-action='transpose']")[0]?.classList.add("active");

  // Show split; hide original content
  pageContent.style.display = "none";
  split.classList.add("active");
  splitMode = true;

  // Body becomes full width in split mode
  document.body.classList.add("split-mode");

  // Prevent body scroll (we now scroll panes)
  document.body.style.overflow = "hidden";

  // Track which pane the mouse is over (for keyboard transpose routing)
  leftPane.addEventListener("mouseenter",  () => { hoveredPane = "left";  }, { passive: true });
  rightPane.addEventListener("mouseenter", () => { hoveredPane = "right"; }, { passive: true });
  leftPane.addEventListener("mouseleave",  () => { if (hoveredPane === "left")  hoveredPane = null; }, { passive: true });
  rightPane.addEventListener("mouseleave", () => { if (hoveredPane === "right") hoveredPane = null; }, { passive: true });

  attachPaneScrollSync();

  // Install per-pane auto-hide behavior (only once per side)
  installPaneAutoHide("left");
  installPaneAutoHide("right");

  // Rebase lastScrollY for completeness
  lastScrollY = getCurrentScrollY();

  // Apply initial TOTAL width
  applySplitTotalWidth();
}

function disableSplitView() {
  const split = document.getElementById("splitContainer");
  const pageContent = document.getElementById("pageContent");

  if (split) split.classList.remove("active");
  if (pageContent) pageContent.style.display = "";

  document.body.style.overflow = "";
  splitMode = false;

  // Return body to constrained width
  document.body.classList.remove("split-mode");

  // Rebase lastScrollY back to window
  lastScrollY = getCurrentScrollY();

  // Restart the auto-hide behavior (will show when mouse hits right edge)
  // No change needed here; timer starts on first reveal
}

// Split toggle button (in master menu)
document.getElementById("splitToggle")?.addEventListener("click", () => {
  if (!splitMode) enableSplitView();
  else disableSplitView();
});

// Width controls (master menu) — TOTAL width of the split area
document.getElementById("wider")?.addEventListener("click", () => {
  if (!splitMode) return;
  splitScale = Math.min(SCALE_MAX, splitScale + SCALE_STEP);
  applySplitTotalWidth();
});
document.getElementById("narrower")?.addEventListener("click", () => {
  if (!splitMode) return;
  splitScale = Math.max(SCALE_MIN, splitScale - SCALE_STEP);
  applySplitTotalWidth();
});

/* ============================================================
   Hook master buttons for speed in both engines (already done above)
   ============================================================ */
// Firefox handlers registered in that branch; same for Chrome.

// --- Spacebar toggles auto-scroll
document.addEventListener("keydown", (e) => {
  if (e.target.matches("input, textarea, button, select")) return;
  if (e.code === "Space") {
    e.preventDefault();
    api.startstop();
  } else if (e.key === "+" || e.key === "=") {
    api.speedUp();
    showSpeedIndicator();
  } else if (e.key === "-") {
    api.speedDown();
    showSpeedIndicator();
  } else if (e.key >= "0" && e.key <= "9") {
    if (splitMode && hoveredPane) paneSetGroup(hoveredPane, parseInt(e.key));
    else showGroup(parseInt(e.key));
    showToast(splitMode && hoveredPane ? paneState[hoveredPane].index : currentIndex);
  } else if (e.key === "u") {
    if (splitMode && hoveredPane) paneUp(hoveredPane);
    else up();
    showToast(splitMode && hoveredPane ? paneState[hoveredPane].index : currentIndex);
  } else if (e.key === "d") {
    if (splitMode && hoveredPane) paneDown(hoveredPane);
    else down();
    showToast(splitMode && hoveredPane ? paneState[hoveredPane].index : currentIndex);
  } else if (splitMode) {
    // In split mode, route scroll keys to the hovered pane
    const paneRoot = hoveredPane ? document.getElementById(`pane${capitalize(hoveredPane)}`) : null;
    if (!paneRoot) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      paneRoot.scrollTop += 60;
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      paneRoot.scrollTop -= 60;
    } else if (e.key === "PageDown") {
      e.preventDefault();
      paneRoot.scrollTop += paneRoot.clientHeight * 0.9;
    } else if (e.key === "PageUp") {
      e.preventDefault();
      paneRoot.scrollTop -= paneRoot.clientHeight * 0.9;
    }
  }
});

// --- Ensure page has keyboard focus on load (no click required)
document.body.tabIndex = -1;
document.body.focus();

// --- Initialize menu hidden; it will appear on first move to right edge
lastScrollY = getCurrentScrollY();
