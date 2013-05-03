angular.module('authService', ['ngResource']).
factory('User', function($resource){
  return $resource('/api/users/:id', {
    id: '@id'
  });
}).
factory('CurrentUser', function($resource){
  return $resource('/api/users/current');
}).
factory('UserList', function($resource){
  return $resource('/api/users/list');
}).
factory('UserType', function($resource){
  return $resource('/api/users/:user/type/:type', {
    user: '@user',
    type: '@type'
  });
}).
factory('GroupList', function($resource){
  return $resource('/api/groups/list');
}).
factory('CapabilityList', function($resource){
  return $resource('/api/capabilities/list');
});