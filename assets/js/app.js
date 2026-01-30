// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/roux_live"
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
        // Delay scroll slightly to ensure layout is ready
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
      console.log("MealPlan hook mounted")
      // On mount, read from localStorage and push to server
      const plan = JSON.parse(localStorage.getItem("roux_meal_plan") || "[]")
      console.log("Loading plan from localStorage:", plan)
      this.pushEvent("load_plan", {plan: plan})

      // Listen for updates from server to save to localStorage
      this.handleEvent("save_plan", ({plan}) => {
        console.log("Saving plan to localStorage:", plan)
        localStorage.setItem("roux_meal_plan", JSON.stringify(plan))
      })
    }
  }
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
        // Delay scroll slightly to ensure layout is ready
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
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

