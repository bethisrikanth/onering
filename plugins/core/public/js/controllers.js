function GlobalController($scope, $http, $rootScope, $window){
  $http.get('/api/core/users/current').error(function(data, status){
    if(status == 401){
      $window.location = '/login.html';
    }
  });
}

function LoginController($scope, $rootScope, $http, $window){
  $scope.user = {};

  $scope.login = function(){
    if($scope.user && $scope.user.name && $scope.user.password){
      $http.post('/api/core/users/login', {
        username: $scope.user.name,
        password: $scope.user.password
      }).success(function(data){
        $window.location = '/';
      });
    }
  }
}

function LogoutController($scope, $http, $rootScope, $window){
  $http.get('/api/core/users/logout').success(function(){
    $window.location = '/login.html';
  });
}

function NavigationController($scope, $rootScope, $http, $route, $window, $routeParams, Summary, List, CurrentUser){
  $scope.reload = function(){
  //get current user details
    CurrentUser.get({}, function(data){
      $rootScope.user = data;
      $scope.addError("Test", "Testing")
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

function UserManagerController($scope, $http, User, UserList, GroupList, CapabilityList){
  $scope._userClass = 'span12';

  $scope.toggleUserPane = function(user){
    if(user){
      if($scope.userPaneUser && ($scope.userPaneUser.id == user.id)){
    //  same user triggered, hide the pane
        $scope.userPaneUser = null;
        $scope._userClass = 'span12';
      }else{
    //  different (or new) user, show pane and update
        $scope._userClass = 'span8';
        $scope.userPaneUser = user;
      }
    }
  }


  $scope._groupClass = 'span12';

  $scope.toggleGroupPane = function(group){
    if(group){
      if($scope.groupPaneGroup && ($scope.groupPaneGroup.id == group.id)){
    //  same group triggered, hide the pane
        $scope.groupPaneGroup = null;
        $scope._groupClass = 'span12';
      }else{
    //  different (or new) user, show pane and update
        $scope._groupClass = 'span8';
        $scope.groupPaneGroup = group;
      }
    }
  }

  $scope._capabilityClass = 'span12';


////////////////////////////////////////////////////////////////////////////////
// YO! FUTURE GARY!  ************* READ THIS *************
////////////////////////////////////////////////////////////////////////////////
// these should be methods on the User() service instance
// there *must* be a way to do this
//
// this would let me call this junk directly in the template and
// avoid all this boilerplate in the controller
  $scope.addGroup = function(user, group){
    if(user && group){
      $http.get('/api/core/groups/'+group+'/add/'+user).success(function(){
        $scope.reload();
      });
    }
  }

  $scope.removeGroup = function(user, group){
    if(user && group){
      $http.get('/api/core/groups/'+group+'/remove/'+user).success(function(){
        $scope.reload();
      });
    }
  }

//reloaders
  $scope.reloadUsers = function(){
    UserList.query({}, function(data){
      $scope.users = data;
    });
  }

  $scope.reloadGroups = function(){
    GroupList.query({}, function(data){
      $scope.groups = data;
    });
  }

  $scope.reloadCapabilities = function(){
    CapabilityList.query({}, function(data){
      $scope.capabilities = data;
    });
  }

  $scope.reload = function(){
    $scope.reloadUsers();
    $scope.reloadGroups();
    $scope.reloadCapabilities();
  }

  $scope.reload();
}