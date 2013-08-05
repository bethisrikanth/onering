angular.module('assetsRoutes', ['ng']).
config(['$routeProvider', function($routeProvider){
  $routeProvider.
  when('/overview', {
    templateUrl: 'views/overview.html',
    controller:  OverviewController
  }).
  when('/inf/summary/:field', {
    templateUrl: 'views/summary.html',
    controller:  SummaryController
  }).
  when('/compare', {
    templateUrl: 'views/compare.html',
    controller:  NodeCompareController
  }).
  when('/compare/:query/:fields', {
    templateUrl: 'views/compare.html',
    controller:  NodeCompareController
  }).
  when('/node/:id', {
    templateUrl: 'views/node.html',
    controller:  NodeController
  }).
  when('/site/:site/:rack', {
    templateUrl: 'views/rack.html',
    controller:  RackController
  }).
  when('/site/:site', {
    templateUrl: 'views/site.html',
    controller:  SiteController
  }).
  when('/inf/:field', {
    templateUrl: 'views/devices.html',
    controller: QueryController
  }).
  when('/inf/show/:query', {
    templateUrl: 'views/devices.html',
    controller: QueryController
  }).
  when('/search/:query', {
    templateUrl: 'views/devices.html',
    controller: QueryController
  }).
  when('/node/find/:query', {
    templateUrl: 'views/devices.html',
    controller: QueryController
  }).
  when('/assets/manage', {
    templateUrl: 'views/asset-manager.html',
    controller:  AssetManagerController
  });
}]);