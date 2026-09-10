(function () {
  var ACTION = "[data-action='sequence-sort-action']"
  var STATUS = '[data-sequence-sort-status]'
  var EVENT = 'click.knapsackSequenceSort'

  var INTEGER = /^-?\d+$/
  var EXACT = typeof BigInt === 'function'

  function sort_key(element) {
    var value = $(element).attr('data-sequence')
    if (!INTEGER.test(value)) { return null }
    return EXACT ? BigInt(value) : Number(value)
  }

  function sort_sequence(manager) {
    var sequenced = []
    var unsequenced = []

    manager.element.children().get().forEach(function (child) {
      var key = sort_key(child)
      if (key === null) {
        unsequenced.push(child)
      } else {
        sequenced.push({ key: key, element: child })
      }
    })

    sequenced.sort(function (a, b) { return a.key < b.key ? -1 : a.key > b.key ? 1 : 0 })

    sequenced.forEach(function (entry) { manager.element.append(entry.element) })
    unsequenced.forEach(function (child) { manager.element.append(child) })

    manager.register_order_change()
    announce()
  }

  function announce() {
    var status = $(STATUS)
    status.text('')
    setTimeout(function () { status.text(status.attr('data-message')) }, 0)
  }

  $(document).off(EVENT).on(EVENT, ACTION, function (event) {
    event.preventDefault()
    if (window.new_sort_manager) { sort_sequence(window.new_sort_manager) }
  })
})()
