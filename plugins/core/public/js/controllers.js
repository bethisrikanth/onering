function GlobalController($scope, $http, $rootScope, $window){
  $http.get('/api/core/users/current').error(function(data, status){
    if(status == 401){
      $window.location = '/login.html';
    }
  });
}

function ErrorController($scope, $location){
  $scope.$watch('errors', function(n){
    if($scope.errors.length == 0){
      $location.path('/');
    }
  });
}

function LoginController($scope, $rootScope, $http, $window){
  $scope.user = {};
  $scope.submitting = false;

  $scope.login = function(){
    $rootScope.clearErrors();
    $scope.submitting = true;

    if($scope.user && $scope.user.name && $scope.user.password){
      $http.post('/api/core/users/login', {
        username: $scope.user.name,
        password: $scope.user.password
      }).success(function(data){
        $window.location = '/';
      }).error(function(){
        $scope.submitting = false;
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

function UserManagerController($scope, $http, User, UserType, UserList, GroupList, CapabilityList){
//USERS
  $scope.submitting = false;
  $scope._userClass = 'span12';

  $scope.toggleUserPane = function(user){
    if(user){
      if($scope.userPaneUser && ($scope.userPaneUser.id == user.id)){
    //  same user triggered, hide the pane
        $scope._userClass = 'span12';
        $scope._userPaneClass = 'hide';
        $scope.userPaneUser = null;
      }else{
    //  different (or new) user, show pane and update
        $scope._userClass = 'span4';
        $scope._userPaneClass = 'span8';
        $scope.userPaneUser = user;
      }
    }
  }


//GROUPS
  $scope._groupClass = 'span12';

  $scope.toggleGroupPane = function(group){
    if(group){
      if($scope.groupPaneGroup && ($scope.groupPaneGroup.id == group.id)){
    //  same group triggered, hide the pane
        $scope._groupClass = 'span12';
        $scope._groupPaneClass = 'hide';
        $scope.groupPaneGroup = null;
      }else{
    //  different (or new) group, show pane and update
        $scope._groupClass = 'span4';
        $scope._groupPaneClass = 'span8';
        $scope.groupPaneGroup = group;
      }
    }
  }


//CAPABILITIES
  $scope._capabilityClass = 'span12';

  $scope.toggleCapabilityPane = function(capability){
    if(capability){
      if($scope.capabilityPaneCapability && ($scope.capabilityPaneCapability.id == capability.id)){
    //  same capability triggered, hide the pane
        $scope._capabilityClass = 'span12';
        $scope._capabilityPaneClass = 'hide';
        $scope.capabilityPaneCapability = null;
      }else{
    //  different (or new) capability, show pane and update
        $scope._capabilityClass = 'span4';
        $scope._capabilityPaneClass = 'span8';
        $scope.capabilityPaneCapability = group;
      }
    }
  }


//operations
  $scope.saveUser = function(user){
    if(user){
      $scope.submitting = true;

      User.save({
        user: user.id
      }, user, function(u){
    //  user object saved, check for change in type
    //  if type changed, save it then reload
        if(user.type != u.type){
          UserType.get({
            user: user.id,
            type: user.type
          }, function(){
            $scope.submitting = false;
            $scope.reload();
          });

    //  otherwise just reload
        }else{
          $scope.submitting = false;
          $scope.reload();
        }
      });
    }
  }

  $scope.addUserToGroup = function(user, group){
    if(user && group){
      $http.get('/api/core/groups/'+group+'/add/'+user).success(function(){
        $scope.reload();
      });
    }
  }

  $scope.removeUserFromGroup = function(user, group){
    if(user && group){
      $http.get('/api/core/groups/'+group+'/remove/'+user).success(function(){
        $scope.reload();
      });
    }
  }

  $scope.grantCapability = function(capability, type, id){
    if(capability && type && id){
    // grant
    }
  }

  $scope.revokeCapability = function(capability, type, id){
    if(capability && type && id){
    // revoke
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

    $http.get('/api/core/users/list/types').success(function(data){
      $scope.userTypes = [];

      angular.forEach(data, function(i){
        $scope.userTypes.push({
          value: i,
          label: i.replace('User','').titleize()
        });
      })
    })
  }

  $scope.reload();
}