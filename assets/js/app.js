// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const hooks = {
  edit_tab_complete: {
    mounted() {
      this.el.addEventListener("keydown", e => {
        if (suggestions.children.length > 0 && e.key == "Tab") {
          const values = [...suggestions.children].map(c => c.value)
          let index = values.indexOf(this.el.value)

          if (index == -1) {
            index = 0
          } else {
            index += e.shiftKey ? -1 : 1
          }

          while (index < 0) {
            index += values.length
          }

          this.el.value = values[index % values.length]
          e.preventDefault()
        }
      })
    }
  },
  search_suggestions: {
    select(e) {
      const re = /((?:-{0,1}|[^ ]*?:)\"(?:\\\"|.)*?\"|[^ ]+)/ig

      let terms = (search_input.value + ".").match(re).slice(-2).map(term => {
        if (term.startsWith("-")) { return term.slice(1) } else { return term }
      })

      if (!terms) return

      let term = terms.at(-1)
      if (terms[0].startsWith("\"") && !terms[0].endsWith("\"")) {
        term = terms[0].slice(1) + " " + terms[1]
      }

      term = term.slice(0, -1)

      search_input.value = search_input.value.slice(0, search_input.value.lastIndexOf(term))

      if (e.dataset.name.includes(" ")) {
        search_input.value += `"${e.dataset.name}"`
      } else {
        search_input.value += e.dataset.name
      }

      if (!(search_input.value.endsWith(":") || search_input.value.endsWith(":>")
        || search_input.value.endsWith(":<") || search_input.value.endsWith(":>=")
        || search_input.value.endsWith(":<="))) {
        search_input.value += " "
      }

      search_input.focus()
      search_input.selectionStart = search_input.value.length
    },
    mounted() {
      this.el.addEventListener("click", e => {
        if (e.target.tagName == "A") {
          this.select(e.target)
        } else if (e.target.parentElement.tagName == "A") {
          this.select(e.target.parentElement)
        }
      })

      this.updated()
    },
    updated() {
      this.el.classList.toggle("empty", this.el.children.length == 0)
    }
  }
}

let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks: hooks })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
let topBarScheduled = undefined
window.addEventListener("phx:page-loading-start", () => {
  if (!topBarScheduled) {
    topBarScheduled = setTimeout(() => topbar.show(), 120)
  }
})

window.addEventListener("phx:page-loading-stop", () => {
  clearTimeout(topBarScheduled)
  topBarScheduled = undefined
  topbar.hide()
})

liveSocket.connect()

window.liveSocket = liveSocket

