var app = angular.module('app', ['filters', 'directives', 'ui', 'apiService']);

app.config(['$routeProvider', function($routeProvider) {
  $routeProvider.
    when('/inf', {
      templateUrl: 'views/sites.html',
      controller:  SummaryController,
      params: {
        field: 'site'
      }
    }).
    when('/inf/summary/:field', {
      templateUrl: 'views/summary.html',
      controller:  SummaryController
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
    otherwise({
      templateUrl: 'views/index.html',
      controller:  DefaultController
    })
}]);


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
