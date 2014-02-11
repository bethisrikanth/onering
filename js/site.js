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
  when('/docs/reference', {
    templateUrl: '{{ site.url_prefix }}/views/reference.html',
    controller:  'PageReferenceController'
  }).
  when('/docs/reference/:plugin', {
    templateUrl: '{{ site.url_prefix }}/views/reference.html',
    controller:  'PageReferenceController'
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
