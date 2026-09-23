// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: https://codemirror.net/LICENSE

// OVERRIDE Hyku 7 app/assets/javascripts/codemirror-autorefresh.js
//
// Both branches of the upstream UMD wrapper throw inside Hyku's bundle: almond
// makes `define.amd` truthy and rejects an anonymous define, and
// codemirror-rails 0.3.1 predates `defineOption`. The throw is uncaught at the
// top level of application.js, so it aborted every file concatenated after it.
// Guard on the API and skip the module dance, which cannot be right here.

(function (mod) {
  if (typeof CodeMirror === "undefined") return
  if (typeof CodeMirror.defineOption !== "function") return

  mod(CodeMirror)
})(function(CodeMirror) {
  "use strict"

  CodeMirror.defineOption("autoRefresh", false, function(cm, val) {
    if (cm.state.autoRefresh) {
      stopListening(cm, cm.state.autoRefresh)
      cm.state.autoRefresh = null
    }
    if (val && cm.display.wrapper.offsetHeight == 0)
      startListening(cm, cm.state.autoRefresh = {delay: val.delay || 250})
  })

  function startListening(cm, state) {
    function check() {
      if (cm.display.wrapper.offsetHeight) {
        stopListening(cm, state)
        if (cm.display.lastWrapHeight != cm.display.wrapper.clientHeight)
          cm.refresh()
      } else {
        state.timeout = setTimeout(check, state.delay)
      }
    }
    state.timeout = setTimeout(check, state.delay)
    state.hurry = function() {
      clearTimeout(state.timeout)
      state.timeout = setTimeout(check, 50)
    }
    CodeMirror.on(window, "mouseup", state.hurry)
    CodeMirror.on(window, "keyup", state.hurry)
  }

  function stopListening(_cm, state) {
    clearTimeout(state.timeout)
    CodeMirror.off(window, "mouseup", state.hurry)
    CodeMirror.off(window, "keyup", state.hurry)
  }
});
