// OVERRIDE blacklight_range_limit 8.5.0 to hide the AMD loader from its bundle.
//
// almond makes `define.amd` truthy, so the gem's UMD wrapper takes the AMD
// branch and its anonymous `define` throws, leaving no global and no slider.
// Hyku requires this file first; range_limit_shared restores `define` as soon as
// the bundle has loaded.

window.knapsackStashedAmdDefine = null;

if (typeof define === 'function' && define.amd) {
  window.knapsackStashedAmdDefine = define;
  window.define = undefined;
}
