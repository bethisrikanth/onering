function GlobalController($scope, $http, $rootScope, $window){
  $http.get('/api/users/current').error(function(data, status){
    if(status == 401){
      $window.location = '/login.html';
    }
  });
}

function IndexController($scope){
  $scope.tgt = "http://graphite.outbrain.com/render/?format=json&target=services.prod.onering.ring-10001-prod-nydc1.worker.tasks.*.runtime.mean";
}

function ErrorController($scope, $location){
  $scope.$watch('errors', function(n){
    if($scope.errors.length == 0){
      $location.path('/');
    }
  });
}


function NavigationController($scope, $rootScope, $http, $route, $window, $routeParams, Summary, List, CurrentUser){
  $scope.reload = function(){
  //get current user details
    CurrentUser.get({}, function(data){
      $rootScope.user = data;
    });

  //get site summary
    Summary.query({
      field: 'site'
    }, function(data){
      $scope.sites = data;
    });

  //get status summary
    Summary.query({
      field: 'status'
    }, function(data){
      $scope.statuses = data;
    });

  //get maintenance status summary
    Summary.query({
      field: 'maintenance_status'
    }, function(data){
      $scope.maintenance_statuses = data;
    });

  //get alert state summary
    Summary.query({
      field: 'alert_state'
    }, function(data){
      $scope.alert_states = $.grep(data, function(el){
        return (el.id !== null);
      });
    });

  //get tags
    List.query({
      field: 'tags'
    }, function(data){
      $scope.tags = [];

  //  WHY IS THIS SO COMPLICATED? #didntreadlol
      $.each(data, function(ix, i){
        var s = '';

        for(var ss in i){
          if(typeof(i[ss]) == 'string') s += i[ss];
        }

        $scope.tags.push(s);
      });
    });
  }

  $window.setInterval($scope.reload, 45000);
  $scope.reload();
}

function SearchController($scope, $http, $location, Query){
  $scope.results = null;
  $scope.search_show_help = false;

  // $scope.$watch('query', function(){
  //   $scope.runQuery();
  // });

  $scope.runQuery = function(query){
    if(query) $scope.query = query;

    if($scope.query && $scope.query.length > 2){
      Query.query({
        query: $scope.prepareQuery($scope.query),
        limit: 10
      }, function(data){
        $scope.results = (data.length > 0 ? data : null);
      });
    }else{
      $scope.clearResults();
    }
  };

  $scope.goQuery = function(query){
    $scope.clearResults();
    if(query) $scope.query = query;

    if($scope.query){
      $location.path('/inf/show/'+$scope.query);
    }
  };

  $scope.clearResults = function(){
    $scope.results = null;
    $scope.search_show_help = false;
  };
}
