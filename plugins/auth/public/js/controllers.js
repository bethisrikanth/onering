function LoginController($scope, $rootScope, $http, $window){
  $scope.user = {};
  $scope.submitting = false;

  $scope.login = function(){
    $rootScope.clearErrors();
    $scope.submitting = true;

    if($scope.user && $scope.user.name && $scope.user.password){
      $http.post('/api/users/login', {
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
  $http.get('/api/users/logout').success(function(){
    $window.location = '/login.html';
  });
}


function UserProfileController($scope, $http, CurrentUser){
  CurrentUser.get({}, function(data){
    $scope.user = data;
  })
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
      $http.get('/api/groups/'+group+'/add/'+user).success(function(){
        $scope.reload();
      });
    }
  }

  $scope.removeUserFromGroup = function(user, group){
    if(user && group){
      $http.get('/api/groups/'+group+'/remove/'+user).success(function(){
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
      if($scope.userPaneUser){
        $scope.userPaneUser = $.grep($scope.users, function(n){
          return (n.id == $scope.userPaneUser.id);
        })[0];
      }
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

    $http.get('/api/users/list/types').success(function(data){
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