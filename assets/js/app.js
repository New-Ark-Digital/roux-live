// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const Hooks = {
  DynamicIsland: {
    mounted() {
      this.animate()
    },
    updated() {
      this.animate()
    },
    animate() {
      // Small delay to let LiveView update the DOM first
      setTimeout(() => {
        const height = this.el.scrollHeight
        if (this.el.classList.contains("opacity-0")) {
          this.el.style.maxHeight = "0px"
        } else {
          this.el.style.maxHeight = height + "px"
        }
      }, 0)
    }
  },
  IngredientAutoScroll: {
    mounted() {
      this.syncPips()
    },
    updated() {
      this.syncPips()
      const highlighted = this.el.querySelector('[data-highlighted="true"]')
      if (highlighted) {
        setTimeout(() => {
          highlighted.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
        }, 100)
      }
    },
    syncPips() {
      const pipsContainer = document.getElementById('ingredient-pips')
      if (!pipsContainer) return

      pipsContainer.innerHTML = ''
      pipsContainer.style.position = 'relative'

      const totalHeight = this.el.scrollHeight
      const items = this.el.querySelectorAll('[data-highlighted="true"]')

      items.forEach(item => {
        const pip = document.createElement('div')
        const top = (item.offsetTop / totalHeight) * 100
        
        pip.className = 'absolute left-0 w-full h-1.5 bg-coral rounded-full opacity-40 shadow-sm transition-all duration-500'
        pip.style.top = `${top}%`
        pipsContainer.appendChild(pip)
      })
    }
  },
  MealPlan: {
    mounted() {
      // On mount, read from localStorage and push to server
      const plan = JSON.parse(localStorage.getItem("roux_meal_plan") || "[]")
      this.pushEvent("load_plan", {plan: plan})

      // Listen for updates from server to save to localStorage
      this.handleEvent("save_plan", ({plan}) => {
        localStorage.setItem("roux_meal_plan", JSON.stringify(plan))
      })

      // Handle preferred cooking mode
      const savedMode = localStorage.getItem("roux_preferred_mode") || "standard"
      this.pushEvent("set_preferred_mode", {mode: savedMode})

      this.handleEvent("save_preferred_mode", ({mode}) => {
        localStorage.setItem("roux_preferred_mode", mode)
      })
    }
  },
  CookingTimer: {
    mounted() {
      this.timer = null;
      this.secondsLeft = 0;
      this.isRunning = false;

      this.display = this.el.querySelector('#timer-display');
      this.toggleBtn = this.el.querySelector('#timer-toggle');
      this.icon = this.el.querySelector('#timer-icon');
      this.progressBar = document.getElementById('global-progress-bar');

      this.toggleBtn.addEventListener('click', () => {
        if (this.isRunning) {
          this.stop();
        } else {
          this.start();
        }
      });

      this.init();
    },
    updated() {
      // If the task changed, reset timer
      const newSeconds = this.getSeconds();
      if (newSeconds !== this.initialSeconds) {
        this.stop();
        this.init();
      }
    },
    init() {
      this.initialSeconds = this.getSeconds();
      this.secondsLeft = this.initialSeconds;
      this.offsetSeconds = parseInt(this.el.dataset.offset) || 0;
      this.totalSeconds = parseInt(this.el.dataset.total) || 0;
      this.updateDisplay();
    },
    getSeconds() {
      const work = parseInt(this.el.dataset.work) || 0;
      const wait = parseInt(this.el.dataset.wait) || 0;
      return (work || wait) * 60;
    },
    start() {
      if (this.secondsLeft <= 0) return;
      this.isRunning = true;
      this.toggleBtn.classList.replace('bg-gray-900', 'bg-red-500');
      this.icon.classList.replace('hero-play', 'hero-pause');
      
      this.timer = setInterval(() => {
        this.secondsLeft--;
        this.updateDisplay();
        this.updateGlobalProgress();
        if (this.secondsLeft <= 0) {
          this.stop();
          this.playAlarm();
        }
      }, 1000);
    },
    stop() {
      this.isRunning = false;
      clearInterval(this.timer);
      this.toggleBtn.classList.replace('bg-red-500', 'bg-gray-900');
      this.icon.classList.replace('hero-pause', 'hero-play');
    },
    updateDisplay() {
      const mins = Math.floor(this.secondsLeft / 60);
      const secs = this.secondsLeft % 60;
      this.display.innerText = `${mins}:${secs.toString().padStart(2, '0')}`;
    },
    updateGlobalProgress() {
      if (!this.progressBar || this.totalSeconds <= 0) return;
      
      const elapsedInTask = this.initialSeconds - this.secondsLeft;
      const totalElapsed = this.offsetSeconds + elapsedInTask;
      const progress = (totalElapsed / this.totalSeconds) * 100;
      
      this.progressBar.style.width = `${progress}%`;

      // Update remaining time display
      const remainingSeconds = Math.max(0, this.totalSeconds - totalElapsed);
      const timeRemainingDisplay = document.getElementById('time-remaining-display');
      if (timeRemainingDisplay) {
        const h = Math.floor(remainingSeconds / 3600);
        const m = Math.floor((remainingSeconds % 3600) / 60);
        const s = remainingSeconds % 60;
        
        let text = "";
        if (h > 0) text += `${h}h `;
        text += `${m}m ${s}s left`;
        timeRemainingDisplay.innerText = text;
      }
    },
    playAlarm() {
      // Simple haptic or audio feedback could go here
      alert("Timer finished!");
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
window.liveSocket = liveSocket
