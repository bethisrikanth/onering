angular.module('coreDirectives', []).
directive('onEnter', function() {
  return {
    link: function(scope, element, attr) {
      element.bind('keypress', function(event) {
        if(event.which === 13) {
          scope.$evalAsync(attr.onEnter);
          scope.$apply();
        }
      });
    }
  }
}).
directive('focusWhen', function() {
  return {
    link: function(scope, element, attr) {
      if($scope.$eval(attr.focusWhen))
        element.focus();
    }
  }
}).
directive('ngModelOnenter', function() {
  return {
    restrict: 'A',
    require: 'ngModel',
    link: function(scope, element, attr, ngModel) {
      if (attr.type === 'radio' || attr.type === 'checkbox') return;

      element.unbind('input').unbind('change');

      element.bind('keydown', function(event){
        if(event.which === 13){
          scope.$apply(function() {
            ngModel.$setViewValue(element.val());
          });
        }
      });
    }
  };
}).
directive('ngModelOnblur', function() {
  return {
    restrict: 'A',
    require: 'ngModel',
    link: function(scope, element, attr, ngModel) {
      if (attr.type === 'radio' || attr.type === 'checkbox') return;

      element.unbind('input').unbind('blur');

      element.bind('blur', function(event){
        scope.$apply(function() {
          ngModel.$setViewValue(element.val());
        });
      });
    }
  };
}).
directive('openDialog', function(){
  return {
    link: function(scope, element, attr){
      function openDialog() {
        var element = angular.element('#'+attr.openDialog);
        var ctrl = element.controller();
        element.modal('show');
      }

      element.bind('click', openDialog);
    }
  }
});
