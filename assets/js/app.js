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
