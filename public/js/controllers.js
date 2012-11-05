function DefaultController($scope){

}

function NavigationController($scope, $http, $route, $routeParams, config){
  $http({
    method: 'GET',
    url:    config.get('baseurl') + '/devices/summary/by-site'
  }).success(function(data){
    $scope.sites = data;
  });
}

function QueryController($scope, $http, $route, $routeParams, config){
  $scope.field = $routeParams.field;
  $scope.query = $routeParams.query || '';
  $scope.params = $route.current.$route.params;

  $http.get(config.get('baseurl') + '/devices/find/' + $scope.field + '/' + $scope.query
  ).success(function(data){
    $scope.devices = data;
  });
}

function DeviceSummaryController($scope, $http, $routeParams, config, DeviceSummary){
  $scope.summary = DeviceSummary.query({field: $routeParams.field || 'site'});
  $scope.orderProp = 'total';
}


function SiteController($scope, $http, $routeParams, config){
  $scope.site = $routeParams.site;
  $scope.drilldown = ['rack','model'];

  $scope.compact = function(i){
    return (i && i['id']);
  };

  $scope.empty = function(i){
    return (i && i['id']);
  };

  $http.get(config.get('baseurl') + '/devices/summary/by-site/' + $scope.drilldown.join('/') + '/?where=site/' + $scope.site
  ).success(function(data){
    $scope.summary = data[0];
  });
}

function RackController($scope, $http, $routeParams, config){
  $scope.site = $routeParams.site;
  $scope.rack = $routeParams.rack;

  $http.get(config.get('baseurl') + '/devices/summary/by-unit/fqdn/?where=site/' + $scope.site + '/rack/' + $scope.rack
  ).success(function(data){
    $scope.devices = data;
  });
}

function NodeController($scope, $http, $routeParams, config, Device){
  $scope.device = Device.get({id: $routeParams.id});
}