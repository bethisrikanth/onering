angular.module('assetsPlugin', [
  'assetsService',
  'assetsRoutes'
]).run(['$rootScope', function($rootScope){
  $rootScope.prepareQuery = function(query, raw){
//  explictly specify raw=true to send the query directly to the API
//  without client-side processing
    if(raw) return query;

    var rv = [];
    query = $.trim(query).split(' ');

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

          console.log(field, q)

          rv.push(field)
          rv.push(q);
        }
      }
    }

    return rv.join('/');
  }
}]);