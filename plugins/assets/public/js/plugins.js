angular.module('assetsPlugin', [
  'assetsService',
  'assetsRoutes'
]).run(['$rootScope', function($rootScope){
  $rootScope.prepareQuery = function(query, raw){
    var q = query.split(':');
    var field = (q.length > 1 ? q[0] : 'id:name:aliases:tags');
    q = (q[1] || q[0]).trim();
    q = q.replace(/\*/g, '~');

    return (raw ? q : field+'/'+q);
  }
}]);