angular.module('assetsPlugin', [
  'assetsService',
  'assetsRoutes'
]).run(['$rootScope', '$filter', function($rootScope, $filter){
  $rootScope.note_tip_options = function(notes){
    return {
      placement: 'left',
      trigger: 'hover',
      delay: 250,
      html: true,
      content: (function(){
        var rv = '<ul class="notes-tip">';

        for(var time in notes){
          rv += '<li><b>'+$filter('date')((time*1000), 'short')+':</b> '+notes[time].body+'</li>';
        }

        rv += '</ul>';
        return rv;
      })()
    }
  };
}]);