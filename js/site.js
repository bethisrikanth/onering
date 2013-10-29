---
---
angular.module('app', [
  'ng',
  'ngRoute',
  'ui.bootstrap'
])
.config(['$routeProvider', function($routeProvider) {
  $routeProvider.
  when('/docs', {
    templateUrl: '{{ site.url_prefix }}/views/docs.html',
    controller:  'PageDocsController'
  }).
  otherwise({
    templateUrl: '{{ site.url_prefix }}/views/index.html',
    controller:  'PageIndexController'
  });
}])
.config(['$interpolateProvider', function($interpolateProvider){
  $interpolateProvider.startSymbol('[[');
  $interpolateProvider.endSymbol(']]');
}])
