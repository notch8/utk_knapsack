// OVERRIDE Hyrax v5.3.0 hyrax/search.js to set the chosen work type and its label in the Digital Collection
// themes' search bar, where Hyrax's script switched the form to a dashboard search. Hyrax's script still
// loads but finds no [data-search-option] items to bind in this form.
(function () {
  var ITEM = '#search-form-header [data-work-type]'
  var EVENT = 'click.knapsackSearchWorkType'

  $(document).off(EVENT).on(EVENT, ITEM, function () {
    var item = $(this)
    var form = item.closest('form')

    form.find('#search-work-type').val(item.attr('data-work-type'))
    form.find('[data-work-type-current]').text(item.attr('data-work-type-label'))
    form.find('[data-work-type]').attr('aria-current', 'false')
    item.attr('aria-current', 'true')
    form.find('#search-work-type-toggle').trigger('focus')
  })
})()
