const isFirefox = navigator.userAgent.toLowerCase().includes('firefox');

////////////////////////////////////////////////////////////////
// Auto-scroll
if (isFirefox) {
    let speed = 5;              // pixels per second (can be very small)
    let scrolling = false;
    let lastTimestamp = 0;
    let fractionalAccumulator = 0;

    function getScrollElement() {
	return document.scrollingElement || document.documentElement;
    }

    function scrollStep(timestamp) {
	if (!scrolling) return;

	if (!lastTimestamp) lastTimestamp = timestamp;

	const delta = timestamp - lastTimestamp;
	lastTimestamp = timestamp;

	const scrollElement = getScrollElement();

	// calculate precise movement
	const exactPixels = (speed * delta) / 1000;

	// accumulate fractions
	fractionalAccumulator += exactPixels;

	// extract whole pixels only
	const wholePixels = Math.floor(fractionalAccumulator);

	if (wholePixels > 0) {
            scrollElement.scrollTop += wholePixels;
            fractionalAccumulator -= wholePixels;
	}

	// stop at bottom
	if (scrollElement.scrollTop + window.innerHeight >= scrollElement.scrollHeight) {
            scrolling = false;
            document.getElementById("startstop").textContent = "Start";
            return;
	}

	requestAnimationFrame(scrollStep);
    }

    function startstop() {
	const btn = document.getElementById("startstop");

	if (!scrolling) {
            scrolling = true;
            lastTimestamp = 0;
            requestAnimationFrame(scrollStep);
            btn.textContent = "Stop";
	} else {
            scrolling = false;
            btn.textContent = "Start";
	}
    }

    document.getElementById("faster").onclick = () => {
	speed += 2;
    };

    document.getElementById("slower").onclick = () => {
	speed = Math.max(0.5, speed - 2);
    };

} else {
    // Chrome
    let speed = 10;        // Default speed
    let intervalId = null;

    function updateSpeed() {
	clearInterval(intervalId);
	intervalId = setInterval(() => {
            window.scrollBy(0, 0.7/getZoomViaDPR()); // Must be 0.2 or above otherwise no scroll
	}, 1000/speed); // Interval time in ms
    }
    
    function getZoomViaDPR() {
	return window.devicePixelRatio || 1; // 1.00 = 100%
    }

    function startstop() {
	let btn = document.getElementById("startstop");
	if (btn.textContent === "Start") {
	    updateSpeed();
	    btn.textContent = "Stop"
	}else{
	    clearInterval(intervalId);
	    btn.textContent = "Start"
	}
    }

    document.getElementById("faster").onclick = () => {
	speed += 5;
	updateSpeed();
    };

    document.getElementById("slower").onclick = () => {
	speed = Math.max(1, speed - 5);
	updateSpeed();
    };
}
////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////
// Transpose
const groups = ["no0","no1","no2","no3",
		"no4","no5","no6","no7",
		"no8","no9","no10","no11"];
let currentIndex = 0;

function showGroup(index) {
    document.querySelectorAll(".chordline").forEach(el => {
	el.style.display = "none";
    });
    if(index >= 0) {
	document.querySelectorAll("." + groups[index]).forEach(el => {
	    el.style.display = "inline-block";
	});
	currentIndex = index;
	// Update buttons
	let btn = document.getElementById("upbutton");
	btn.textContent = "Up " + index;
    }
}

function up() {
    let newIndex = (currentIndex + 1) % groups.length;
    showGroup(newIndex);
}

function down() {
    let newIndex = (currentIndex - 1 + groups.length) % groups.length;
    showGroup(newIndex);
}
////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////
// Chords
function hideshowchords() {
    let btn = document.getElementById("toggleChords");

    if (btn.textContent === "Hide") {
	btn.textContent = "Show";
	showGroup(-1);
    } else {
	btn.textContent = "Hide";
	showGroup(currentIndex);
    }
}

// show first group on load
showGroup(0);
////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////
// Menu folding
document.getElementById("menuToggle").addEventListener("click", function () {
    let controls = document.getElementById("controls");
    let toggle = document.getElementById("menuToggle");

    controls.classList.toggle("collapsed");

    if (controls.classList.contains("collapsed")) {
        toggle.textContent = "▼";
    } else {
        toggle.textContent = "▲";
    }
});
////////////////////////////////////////////////////////////////
