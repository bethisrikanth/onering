angular.module('corePlugin', [
  'coreFilters',
  'coreDirectives',
  'coreRoutes'
]).
run(['$rootScope', '$window', '$http', function($rootScope, $window, $http){
  $rootScope.online = true;

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