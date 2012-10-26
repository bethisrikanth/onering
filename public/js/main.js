String.prototype.toTitleCase = function(){
  return this.replace(/\w\S*/g, function(str){
    return str.charAt(0).toUpperCase() + str.substr(1).toLowerCase();
  });
};

var app = angular.module('app', ['filters']);


angular.module('filters', []).
filter('titleize', function(){
  return function(text){
    return text.replace(/_/, ' ').toTitleCase();
  };
});


app.config(['$routeProvider', function($routeProvider) {
  $routeProvider.
    when('/inf', {
      templateUrl: 'views/inf-overview.html',
      controller:  DeviceSummaryController
    }).
    when('/inf/summary/:field', {
      templateUrl: 'views/summary.html',
      controller:  DeviceSummaryController
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
    when('/inf/show/:field/:query', {
      templateUrl: 'views/devices.html',
      controller: QueryController
    }).
    otherwise({
      templateUrl: 'views/index.html',
      controller:  DefaultController
    })
}]);