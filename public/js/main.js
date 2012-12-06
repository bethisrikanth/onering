var app = angular.module('app', ['filters', 'directives', 'ui', 'apiService']);

app.config(['$routeProvider', function($routeProvider) {
  $routeProvider.
    when('/inf', {
      templateUrl: 'views/sites.html',
      controller:  OverviewController
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
}]).run(function($rootScope){
  $rootScope.prepareQuery = function(query){
    var q = query.split(':');
    var field = (q.length > 1 ? q[0] : 'id:name:aliases:tags');
    q = (q[1] || q[0]).trim();
    q = q.replace(/\*/g, '~');

    return field+'/'+q;
  }
});


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
