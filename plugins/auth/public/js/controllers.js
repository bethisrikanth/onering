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


function UserProfileController($scope, $http, $modal, $timeout, CurrentUser){
  $scope.reload = function(delay){
    var _reload = function(){
      CurrentUser.get({}, function(data){
        $scope.user = data;
      })
    }

    if(angular.isUndefined(delay)){
      _reload();
    }else{
      if(!angular.isArray(delay)){
        delay = [delay];
      }

      for(var i = 0; i < delay.length; i++){
        $timeout(_reload, delay[i]);
      }
    }
  }

  $scope.showKeyDialog = function(name, data){
    var $parent = $scope;

    var d = $modal.open({
      backdrop:    true,
      keyboard:    true,
      templateUrl: 'showKeyDialog',
      controller:  function($scope, $modal){
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


function UserManagerController($scope, $http, $modal, User, UserType, UserList, GroupList, CapabilityList){
  $scope.sortField = 'id';


  $scope.reloadUsers = function(){
    UserList.query({}, function(data){
      $scope.users = data;
    });

    $http.get('/api/users/list/machines').success(function(data){
      $scope.devices = data;
    })

    $http.get('/api/users/list/types').success(function(data){
      $scope.userTypes = data;
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

  $scope.userDialog = function(user, tpl){
    var $parent = $scope;

    var d = $modal.open({
      backdrop:    true,
      keyboard:    true,
      templateUrl: (tpl || 'userDialog'),
      controller:  function($scope, $modal, User){
        $scope.user = user;
        $scope.groups = $parent.groups;
        $scope.userTypes = $parent.userTypes;
        $scope.parent = $parent;

        $scope.reload = function(){
          User.get({
            id: $scope.user.id
          }, function(data){
            $scope.user = data;
          });
        }

        $scope.close = function(){
          $parent.reload();
          d.close()
        };
      }
    });

    d.open()
  };

  $scope.reload();
}