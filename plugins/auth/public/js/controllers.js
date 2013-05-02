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


function UserProfileController($scope, $http, $dialog, CurrentUser){
  $scope.reload = function(){
    CurrentUser.get({}, function(data){
      $scope.user = data;
    })
  }

  $scope.createKeyDialog = function(){
    var $parent = $scope;

    var d = $dialog.dialog({
      backdrop:    true,
      keyboard:    true,
      templateUrl: 'createKeyDialog',
      controller:  function($scope, $dialog){
        $scope.save = function(response){
          $parent.reload();
          $parent.showKeyDialog($scope.key_name, response.data.split(/\n{2,}/))
          $scope.close();
        }

        $scope.close = function(){
          d.close()
        };
      }
    });

    d.open()
  };

  $scope.showKeyDialog = function(name, data){
    var $parent = $scope;

    var d = $dialog.dialog({
      backdrop:    true,
      keyboard:    true,
      templateUrl: 'showKeyDialog',
      controller:  function($scope, $dialog){
        $scope.name = name;
        $scope.private_key = data[0].trim();
        $scope.public_key  = data[1].trim();

        $scope.close = function(){
          d.close()
        };
      }
    });

    d.open()
  };

  $scope.reload();
}


function UserManagerController($scope, $http, $dialog, User, UserType, UserList, GroupList, CapabilityList){
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

  $scope.reload = function(){
    $scope.reloadUsers();
    $scope.reloadGroups();
  }

  $scope.userDialog = function(user){
    var $parent = $scope;

    var d = $dialog.dialog({
      backdrop:    true,
      keyboard:    true,
      templateUrl: 'userDialog',
      controller:  function($scope, $dialog, User){
        $scope.user = user;
        $scope.groups = $parent.groups;

        $scope.reload = function(){
          User.get({
            id: $scope.user.id
          }, function(data){
            $scope.user = data;
          });
        }

        $scope.close = function(){
          d.close()
        };
      }
    });

    d.open()
  };

  $scope.reload();
}