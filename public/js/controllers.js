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

function SearchController($scope, $http, Query){
  $scope.results = null;

  $scope.$watch('query', function(){
    $scope.runQuery();
  });


  $scope.runQuery = function(query){
    if(query) $scope.query = query;

    if($scope.query && $scope.query.length > 2){
      var q = $scope.query.split(':');
      var field = (q.length > 1 ? q[0] : 'name');
      q = (q[1] || q[0]).trim();

      Query.query({
        query: field+'/'+q
      }, function(data){
        $scope.results = (data.length > 0 ? data : null);
      });
    }else{
      $scope.clearResults();
    }
  };

  $scope.clearResults = function(){
    $scope.results = null;
  };
}

function QueryController($scope, $http, $route, $routeParams, Query){
  if($routeParams.field) $scope.field = $routeParams.field;
  $scope.query = $routeParams.query;
  $scope.params = $route.current.$route.params;

//run arbitrary query
  if($scope.query){
    Query.query({
      query: [$scope.field, $scope.query].compact().join('/')
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


function SiteController($scope, $http, $routeParams, Device, Query, Site, SiteContact){
  $scope.site = $routeParams.site;

//site summary
  Site.query({
    site: $scope.site
  }, function(data){
    $scope.summary = data[0];

    if($scope.summary){
      $scope.racks = $scope.summary.children;
    }
  });

//racked devices
  SiteContact.query({
    site: $scope.site
  }, function(data){
    $scope.contact = data[0];
  });

//unracked devices
  Query.query({
    query: 'site/'+$scope.site+'/^rack',
  }, function(data){
    $scope.devices = data;
  });

  $scope.addRack = function(){
    $scope.racks.push({
      'id': 'Untitled'
    })
  }

  $scope.saveRack = function(rack, old){
    delete rack.editing;
    var devices = [];

    console.log(rack.id, rack.old)
    $http.post('/api/devices/find/site/'+$scope.site+'/rack/'+rack.old+'/?set=rack:'+rack.id);
  };

  $scope.saveUnracked = function(){
    $.each($scope.devices, function(idx, i){
      if(i.properties)
        if(i.properties.rack)
          if(i.properties.rack.length > 0)
            Device.save({
              id: i.id,
              properties: {
                rack: i.properties.rack
              }
            });
    });
  }
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

function RackerController($scope, $window, Query){
  $scope.recheck = function(){
    if(!$scope.editing){
      Query.query({
        query: 'identify/on'
      }, function(data){
        $scope.device = data[0];
      });
    }
  };

  $scope.recheck();
  $window.setInterval($scope.recheck, 2000);
}