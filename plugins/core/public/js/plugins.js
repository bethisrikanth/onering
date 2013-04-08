angular.module('corePlugin', [
  'coreFilters',
  'coreDirectives',
  'coreRoutes'
]).
run(['$rootScope', '$window', '$http', function($rootScope, $window, $http){
  $rootScope.online = true;

  $rootScope.prepareQuery = function(query, raw){
    var stack = [];
    query = query.replace(/\s*(\:|==|<=|>=|<|>|!=|\))\s*/g, '$1').split(' ');

//  for each field being queried
    for(var i in query){
      var field = query[i];
      var parts = field.match(/(?:\(([a-z\_]*)\))?\s*(.*)\s*(:|==|<=|>=|<|>|!=)\s*(.*)$/);

    //if the field is valid
      if(parts){
        var q = {
          coerce:     parts[1],
          field:      parts[2],
          comparator: parts[3],
          test:       parts[4]
        };

        var rv = '';

    //  add coercion operator (if present)
        if(q.coerce){ rv += (q.coerce+':') }

    //  add field name
        rv += q.field;

    //  push field expression onto the stack, reset
        stack.push(rv);
        rv = '';

    //  add comparator (if present)
        switch(q.comparator){
    //  greater than
        case '>':
          rv += 'gt:'; break;

    //  greater than/equal to
        case '>=':
          rv += 'gte:'; break;

    //  less than
        case '<':
          rv += 'lt:'; break;

    //  less than/equal to
        case '<=':
          rv += 'lte:'; break;

    //  not equal
        case '!=':
          rv += 'not:'; break;

    //  fallback
        default:
          break;
        }

    //  add test value
        rv += q.test;

    //  push value expression onto stack
        stack.push(rv);

      }else{
      // throw and error, raise a message, fire a flare...inform the user this ain't right
      }
    }

    if(stack.length == 0){
      stack.push('str:id|str:name|tags');
      stack.push(field);
    }

    return stack.join('/');
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