angular.module('app', [
  'ui',
  'corePlugin',
  'assetsPlugin'
]);

try {
  // manual bootstrap, when google api is loaded
  google.load('visualization', '1.0', {'packages':['corechart']});
  google.setOnLoadCallback(function() {
    angular.bootstrap(document.body, ['app']);
  });
} catch(e) {
  if (console && console.log) {
    console.log("Unable to load google: " + e);
  }
}