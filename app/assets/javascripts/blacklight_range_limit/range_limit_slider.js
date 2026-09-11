// OVERRIDE blacklight_range_limit 8.5.0 to neutralize Hyku's vendored pre-8 copy.
//
// The gem's bundle, loaded by the range_limit_shared override, supplies the
// slider. The restore below is a safety net: that file normally hands `define`
// back, and this keeps the AMD loader from staying hidden if it ever does not.

if (window.knapsackStashedAmdDefine) {
  window.define = window.knapsackStashedAmdDefine;
  window.knapsackStashedAmdDefine = null;
}
