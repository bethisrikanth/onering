angular.module('corePlugin', [
  'coreFilters',
  'coreDirectives',
  'coreRoutes',
  'toaster'
]).
run(['$rootScope', '$window', '$http', '$modal', '$location', 'toaster', function($rootScope, $window, $http, $modal, $location, toaster){
  $rootScope.online = true;
  $rootScope.location = $location;

  $rootScope.go = function(path){
    $location.path(path);
    try{
      $rootScope.$apply(function(){
        $rootScope.$broadcast('location-changed', path);
      });
    }catch(e){ ; }
  };


  $rootScope.toast = function(severity, title, text, timeout){
    console.log('SAY', title, text)
    toaster.pop(severity, title, text, 3000);
  };

  $rootScope.prepareQuery = function(query, raw){
    var stack = [];

//  prepend global filter
    if($rootScope.group_filter.default != true){
      var s = $rootScope.group_filter.query.split('/');

      if(s.length > 0 && s.length % 2 == 0){
        stack = s;
      }
    }

    query = query.replace(/\s*(\:|==|<=|>=|<|>|!=|\)|after|before)\s*/g, '$1').split(' ');

//  for each field being queried
    for(var i = 0; i < query.length; i++){
      var field = query[i];
      var parts = field.match(/(?:\(([a-z\_]*)\))?\s*(.*)\s*(:|==|<=|>=|<|>|!=|after|before)\s*(.*)$/);

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

    //  before
        case 'before':
          rv += 'before:'; break;

    //  since
        case 'since':
          rv += 'since:'; break;

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
      stack.push('str:id|str:name|str:dns.name|tags');
      stack.push(field);
    }

    return stack.join('/');
  }

  $rootScope.getProperty = function(obj, path, fallback){
    var root = obj;
    path = path.split('.');

    for(var i = 0; i < path.length; i++){
      if(root.hasOwnProperty(path[i])){
        root = root[path[i]];

        if($.isArray(root)){
          for(var j = 0; j < root.length; j++){
            root = root[path[i]];
          }
        }else{
          if(i == (path.length - 1)){
            if(root){
              return root;
            }
          }else{
            continue;
          }
        }
      }else{
        return fallback;
      }
    }

    return fallback;
  }

  $rootScope.ping = function(){
    $http.get('/api', {
      severity: 'ignore'
    }).
    success(function(data){
      $rootScope.first_ping = true;
      $rootScope.state = data;
      $rootScope.$broadcast('online');
    }).
    error(function(data){
      $rootScope.first_ping = true;
      $rootScope.state = false;
      $rootScope.$broadcast('offline');
    });
  }

  $rootScope.openDialog = function(tpl, parent, controller){
    if(angular.isFunction(controller)){
      var subcontroller = controller;
    }

    var d = $modal.open({
      backdrop:    true,
      keyboard:    true,
      templateUrl: tpl,
      controller:  function($scope, $modal){
        if(!angular.isUndefined(parent)){
          $scope.parent = parent;
        }

        $scope.close = function(){
          d.close()
        };

        if(!angular.isUndefined(subcontroller)){
          subcontroller($scope, $modal);
        }
      }
    });
  }

  $rootScope.validateIpAddress = function(value){
    if(!angular.isUndefined(value)){
      if(value.match(/^\s*[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\s*$/)){
        return true;
      }
    }

    return false;
  }

  $rootScope.validateDotless = function(value){
    if(!angular.isUndefined(value)){
      return (value.indexOf('.') < 0)
    }

    return false;
  }

  $rootScope.setTitle = function(value){
    $scope.title = value;
  }


  $rootScope.first_ping = false;
  $rootScope.ping();
  $window.setInterval($rootScope.ping, 10000);
}]);
