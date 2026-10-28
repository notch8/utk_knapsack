// OVERRIDE browse-everything 1.5.0 browse_everything/behavior.js, whose Submit handler calls Bootstrap 3's
// button('loading'). Hyku's $.fn.button is jQuery UI's, which throws on it, so the selection was never sent.
(function () {
  var button = $.fn.button
  if (button.knapsackEvSubmit) return

  $.fn.button = function (option) {
    if (option === 'loading' && this.is('.ev-submit')) return this
    return button.apply(this, arguments)
  }
  $.fn.button.knapsackEvSubmit = true
})()
