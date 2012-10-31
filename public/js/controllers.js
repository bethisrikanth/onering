function DefaultController($scope){

}

function NavigationController($scope, $http, $route, $routeParams, config){
  $http({
    method: 'GET',
    url:    config.get('baseurl') + '/devices/list/site'
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

function DeviceSummaryController($scope, $http, $routeParams, config){
  $scope.field = $routeParams.field || 'site';

  $http.get(config.get('baseurl') + '/devices/summary/by-' + $scope.field
  ).success(function(data){
    $scope.summary = data;
  });

  $scope.orderProp = 'total';
}


function SiteController($scope, $http, $routeParams, config){
  $scope.site = $routeParams.site;

  $http.get(config.get('baseurl') + '/devices/find/site/' + $scope.site
  ).success(function(data){
    $scope.devices = data;
  });
}

function RackController($scope, $http, $routeParams, config){
  $scope.site = $routeParams.site;
  $scope.rack = $routeParams.rack;

  $http.get(config.get('baseurl') + '/devices/find/site/' + $scope.site+'/model/' + $scope.rack
  ).success(function(data){
    $scope.devices = data;
  });
}

function NodeController($scope, $http, $routeParams, config){
  $scope.id = $routeParams.id;

  $http.get(config.get('baseurl') + '/devices/' + $scope.id
  ).success(function(data){
    $scope.device = data;
  });
}