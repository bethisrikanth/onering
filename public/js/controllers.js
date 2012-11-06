function DefaultController($scope){

}

function NavigationController($scope, $http, $route, $routeParams, Summary){
//get site summary
  Summary.query({
    field: 'site'
  }, function(data){
    $scope.sites = data;
  });
}

function QueryController($scope, $http, $route, $routeParams, Query){
  $scope.query = $routeParams.query;
  $scope.params = $route.current.$route.params;

//run arbitrary query
  if($scope.query){
    Query.query({
      query: $scope.query
    }, function(data){
      $scope.devices = data;
    });
  }
}

function SummaryController($scope, $http, $routeParams, $route, Summary){
  $scope.params = ($route.current.$route.params || {});
  $scope.field = $routeParams.field || $scope.params.field;
  $scope.orderProp = 'total';

  Summary.query({
    field: $scope.field
  }, function(data){
    $scope.summary = data;
  });
}


function SiteController($scope, $http, $routeParams, Query, Site, SiteContact){
  $scope.site = $routeParams.site;

  Site.query({
    site: $scope.site
  }, function(data){
    $scope.summary = data[0];
  });

  SiteContact.query({
    site: $scope.site
  }, function(data){
    $scope.contact = data[0];
  });

  Query.query({
    query: 'site/'+$scope.site+'/^rack',
  }, function(data){
    $scope.unracked = data;
  });
}

function RackController($scope, $http, $routeParams, Rack){
  $scope.site = $routeParams.site;
  $scope.rack = $routeParams.rack;

  Rack.query({
    site: $scope.site,
    rack: $scope.rack
  }, function(data){
    $scope.devices = data;
  });
}

function NodeController($scope, $http, $routeParams, Device){
  $scope.id = $routeParams.id;

  Device.get({
    id: $scope.id
  }, function(data){
    $scope.device = data;
  });
}