angular.module('authPlugin', [
  'authService',
  'authRoutes'
]).
config(function($httpProvider){
  $httpProvider.responseInterceptors.push(function($q, $rootScope, $location){
    return function(promise) {
      return promise.then(function(response){
        return response;
      }, function(response){
        if(response.data && $.isPlainObject(response.data)){
          if(response.data.error){
        //  only reject severe issues
            switch(response.data.error.severity){
              case 'ignore':
                return response;

              case 'debug':
              case 'info':
                $rootScope.addError(response.data.error, response.status, response.data.error.severity);
                return response;

              case 'warning':
                $rootScope.addError(response.data.error, response.status, response.data.error.severity);
                break;

              default:
                $rootScope.addError(response.data.error, response.status, response.data.error.severity);
                $location.path('/error');
            }
          }
        }

        return $q.reject(response);
      });
    }
  });
}).
run(['$rootScope', '$window', '$http', function($rootScope, $window, $http){
  $rootScope.user = null;
  $rootScope.errors = [];

  $rootScope.addError = function(object, code, severity){
    if($rootScope.errors.length > 0){
      for(var i in $rootScope.errors){
        if($rootScope.errors[i].type == object.type && $rootScope.errors[i].message == object.message){
          return false;
        }
      }
    }

    switch(severity){
      case 'warning':
        alertClass = null;
        badgeClass = 'badge-warning';
        labelClass = 'badge-warning';
        break;
      case 'info':
        alertClass = 'alert-success';
        badgeClass = 'badge-success';
        labelClass = 'label-success';
        break;
      case 'debug':
        alertClass = 'alert-info';
        badgeClass = 'badge-info';
        labelClass = 'label-info';
        break;
      default:
        alertClass = 'alert-error';
        badgeClass = 'badge-important';
        labelClass = 'label-important';
        break;
    }

    $rootScope.errors.push($.extend(object,{
      code:     code,
      severity: severity,
      alertClass: alertClass,
      badgeClass: badgeClass,
      labelClass: labelClass
    }));

    return true;
  }

  $rootScope.clearErrors = function(i){
    if(i >= 0){
      $rootScope.errors.splice(i,1);
    }else{
      $rootScope.errors = [];
    }
  }
}]);