// OVERRIDE blacklight_range_limit 8.5.0 to load the gem's own built bundle.
//
// 8.5.0 ships only the umd/esm builds under this directory, so Hyku's three
// `//= require`s resolve to its own vendored pre-8 copies, which define the
// global the old way and never call `initialize`. The knapsack's asset path is
// searched first (config/initializers/knapsack_assets.rb), so overriding these
// three logical paths swaps in the version-matched bundle.
//
//= require blacklight_range_limit/blacklight_range_limit.umd

if (window.knapsackStashedAmdDefine) {
  window.define = window.knapsackStashedAmdDefine;
  window.knapsackStashedAmdDefine = null;
}

// Everything below reaches its globals through `window` and bails if one is
// absent, so a missing prerequisite makes this file a no-op instead of throwing.
// A bare reference would raise at top level and abort the rest of the bundle,
// which is the very failure this override exists to stop. The bundle can load
// without setting the global if `define` is ever present and tolerant of an
// anonymous module: requirejs is in this bundle alongside almond.
(function () {
  var jq = window.jQuery;
  var rangeLimit = window.BlacklightRangeLimit;
  var blacklight = window.Blacklight;

  if (!jq || !rangeLimit || !blacklight) return;

  // Hover is switched off at its source. flot re-reads `grid.hoverable` from the
  // plot's live options on each mouse event, so clearing it stops `plothover`
  // firing whoever is listening. Unbinding the gem's handler is not enough (a
  // redraw rebinds it), and removing its `mouseout` too leaves a tooltip that
  // can never dismiss, because `tooltip('hide')` throws under jQuery UI.
  rangeLimit.knapsackDisableChartHover = function (container) {
    var plot = container.data('plot');

    if (plot && plot.getOptions && plot.getOptions().grid) {
      plot.getOptions().grid.hoverable = false;
    }

    container.off('mouseout').off('plothover');

    var describedBy = container.attr('aria-describedby');
    var stale = describedBy && document.getElementById(describedBy);

    if (stale) stale.parentNode.removeChild(stale);

    container.removeAttr('title').removeAttr('aria-describedby');
  };

  // Attached at file scope, before any Blacklight.onLoad callback, so it cannot
  // miss the chart `initialize` draws synchronously for an already-open facet.
  jq(document).on(rangeLimit.redrawnEvent, function (event) {
    rangeLimit.knapsackDisableChartHover(jq(event.target));
  });

  blacklight.onLoad(function () {
    var modalSelector = (blacklight.modal && blacklight.modal.modalSelector) ||
      (blacklight.Modal && blacklight.Modal.modalSelector);

    rangeLimit.initialize(modalSelector);
  });
})();
