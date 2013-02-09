angular.module('corePlugin', [
  'coreService',
  'coreFilters',
  'coreDirectives',
  'coreRoutes'
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
              case 'info':
                return response;

              case 'debug':
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
  $rootScope.online = true;
  $rootScope.user = null;
  $rootScope.errors = [];

  $rootScope.addError = function(object, code, severity){
    if($rootScope.errors.length > 0){
      for(var i in $rootScope.errors){
        if(i == 'compact') continue;

        if($rootScope.errors[i].type == type && $rootScope.errors[i].message == message){
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

  $rootScope.prepareQuery = function(query, raw){
//  explictly specify raw=true to send the query directly to the API
//  without client-side processing
    if(raw) return query;

    var rv = [];
    query = $.trim(query).replace(/\s*:\s*/g, ':').split(' ');

    for(var part in query){
      if(typeof(query[part]) == 'string'){
        var q = query[part].split(':');

    //  field negation operator should be processed in raw mode
        if(query[part].indexOf('^') !== -1){
          rv.push(query[part]);

    //  normal query
        }else{
          var field = (q.length > 1 ? q[0] : 'id:name:aliases:tags');
          q = $.trim(q[1] || q[0]);
          q = q.replace(/\*/g, '~');

          rv.push(field.toLowerCase());
          rv.push(q);
        }
      }
    }

    return rv.join('/');
  }

  $rootScope.ping = function(){
    $http.get('/api').
    success(function(data){
      $rootScope.online = true;
      $rootScope.$broadcast('online');
    }).
    error(function(data){
      $rootScope.online = false;
      $rootScope.$broadcast('offline');
    });
  }

  $window.setInterval($rootScope.ping, 15000);
}]);