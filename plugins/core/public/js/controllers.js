function GlobalController($scope, $http, $rootScope, $window){
  $http.get('/api/users/current').error(function(data, status){
    if(status == 401){
      $window.location = '/login.html';
    }
  });
}

function IndexController($scope){

}

function ErrorController($scope, $location){
  $scope.$watch('errors', function(n){
    if($scope.errors.length == 0){
      $location.path('/');
    }
  });
}


function NavigationController($scope, $rootScope, $http, $route, $window, $routeParams, $cookies, Summary, List, CurrentUser){
  $scope.menuquery = function(query, template){
    var rv = [];

    if(angular.isDefined(query) && angular.isDefined(template)){
      var rv = [{
        name: 'Test',
        counter: 0,
        href: '#/lol'
      }];

      // $http.get(query).success(function(data){
      //   angular.forEach(data, function(i){
      //     rv.push({
      //       name: 'Test',
      //       counter: 0,
      //       href: '#/lol'
      //     })
      //   });
      // });

    }

    return rv;
  };

  $scope.setGroupFilter = function(field, value){
    value.field = field;
    value.query = field+'/'+(value.value || value);

    if(angular.isDefined(value.query)){
      $rootScope.group_filter = value;
      $cookies['onering.group_filter_query'] = value.query;
      console.log("GFC", $cookies['onering.group_filter_query'], value.query)
    }
  }

  $scope.clearGroupFilter = function(clear_cookie){
    $rootScope.group_filter = {
      field:   '',
      value:   '',
      query:   null,
      default: true
    };

    if(angular.isDefined(clear_cookie) && clear_cookie === true){
      delete $cookies['onering.group_filter_query'];
    }

    $scope.reload();
  }

  $scope.reload = function(){
    $http.get('/api/navigation').success(function(data){
      $scope.menu = data;
    });

    $http.get('/api/navigation/filters').success(function(data){
      $scope.group_filters = data;

      var sessionFilter = $cookies['onering.group_filter_query'];

      if(sessionFilter != null){
        var fv = sessionFilter.split('/');

        if(fv.length > 1){
          console.log("LOADING GROUP FILTER FROM COOKIE", sessionFilter, fv);
          $scope.setGroupFilter(fv[0], {
            value: fv[1]
          });
        }
      }
    });

  //get current user details
    CurrentUser.get({}, function(data){
      $rootScope.user = data;
    });

  //get site summary
    Summary.query({
      field: 'site',
      q:     $rootScope.group_filter.query
    }, function(data){
      $scope.sites = data;
    });

  //get status summary
    Summary.query({
      field: 'status',
      q:     $rootScope.group_filter.query
    }, function(data){
      $scope.statuses = data;
    });

  //get maintenance status summary
    Summary.query({
      field: 'maintenance_status',
      q:     $rootScope.group_filter.query
    }, function(data){
      $scope.maintenance_statuses = data;
    });

  //get alert state summary
    Summary.query({
      field: 'alert_state',
      q:     $rootScope.group_filter.query
    }, function(data){
      $scope.alert_states = $.grep(data, function(el){
        return (el.id !== null);
      });
    });

  //get tags
    List.query({
      field: 'tags',
      q:     $rootScope.group_filter.query
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
  $scope.clearGroupFilter();
}

function SearchController($scope, $http, $location, Query){
  $scope.results = null;
  $scope.search_show_help = false;

  // $scope.$watch('query', function(){
  //   $scope.runQuery();
  // });

  $http.get('/api/devices/schema/fields').success(function(data){
    $scope.autocomplete = data;
  });

  $scope.selectAutocomplete = function(scope, locals, a, b, c){
    console.log(scope, locals, a,b,c)
  }

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
      $location.path('/search/'+$scope.query);
    }
  };

  $scope.clearResults = function(){
    $scope.results = null;
    $scope.search_show_help = false;
  };
}
