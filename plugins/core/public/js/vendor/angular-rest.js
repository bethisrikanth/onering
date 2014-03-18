function AngularRestModalConfirmController($scope, $modalInstance, callback, config){
  $scope.title = (config.title || "Confirm Action");
  $scope.text  = (config.text || "Are you sure you want to perform the selected action?");

  $scope.confirm = function(){
    callback();
    $modalInstance.close();
  }

  $scope.cancel = function(){
    $modalInstance.dismiss('cancel');
  }
}

angular.module('rest', ['ui.bootstrap'])
.directive('restShow', function(){
  return {
    restrict:   'A',

    controller: function($scope, $element, $attrs, $http, $window){
      var testResponse = function(status, fallback){
        if(angular.isUndefined($attrs.restCode)){
          return fallback;
        }else{
          var code = $attrs.restCode;

          if(!angular.isArray(code)){
            code = [code];
          }

          return (code.indexOf(s) > -1);
        }
      }

      $element.showHide = function(show){
        if(show === true){
          $element.show();
        }else{
          $element.hide();
        }
      }

      $element.checkHttpStatus = function(method, url){
        if(url){
          $http({
            method: (method || 'head'),
            url:    url,
            params: {
              severity: ($attrs.restSeverity || 'ignore')
            }
          })
          .success(function(d,s,h,c){
            $element.showHide(testResponse(s,true))
          })
          .error(function(d,s,h,c){
            $element.showHide(testResponse(s,false))
          })
        }
      }
    },

    link: function($scope, $element, $attrs){
      $element.recheck = function(){
        $element.checkHttpStatus($attrs.restMethod, $attrs.restShow);
      }

      if($attrs.restInterval){
        $window.setInterval($element.recheck, +$attrs.restInterval);
      }

      $attrs.$observe('restShow', function(value){
        if(!angular.isUndefined(value)){
          $element.recheck();
        }
      });

      $scope.$on('reload', $element.recheck);
    }
  };
})
.directive('rest', function($modal, $timeout, $interpolate) {
  return {
    restrict: 'A',
    controller: function($scope, $element, $attrs, $http){
      var disabler = function(event) {
        event.preventDefault();
        return false;
      }

      var rest_confirm = function(func, config){

        if(angular.isString(config)){
          config = {
            text: config
          };
        };

        $modal.open({
          templateUrl: 'views/angular-rest-modal-confirm.html',
          scope:       $scope,
          controller:  AngularRestModalConfirmController,
          backdrop:    true,
          resolve: {
            callback: function(){
              return func
            },
            config: function(){
              return config;
            }
          }
        });
      }

      $element.run = function(){
        if(angular.isDefined($attrs.restConfirm)){
          rest_confirm($element.callHttp, $attrs.restConfirm);
        }else{
          $element.callHttp();
        }
      }

      $element.callHttp = function(){
        var method = $attrs.restMethod;
        var url =  $attrs.rest;
        var data = $scope.$eval($attrs.restData);

        if(url){
          $element.toggleClass('disabled', true);
          $element.bind('click', disabler);

          $http({
            method: (method ? method.toUpperCase() : 'GET'),
            url:    url,
            data:   (angular.isUndefined(data) ? null : JSON.stringify(data)),
            params: {
              severity: ($attrs.restSeverity || 'ignore')
            }
          }).success(function(data, status, headers, config){
            $element.toggleClass('disabled', false);
            $element.unbind('click', disabler);

        //  if specified, eval the code in scope
            if(angular.isDefined($attrs.restSuccess)){
              $scope.$evalAsync(function(){
                var response = {
                  data:    data,
                  status:  status,
                  headers: headers,
                  config:  config
                };

                $scope.$eval($attrs.restSuccess, response);
              });
            }
          }).error(function(data, status, headers, config){
            $element.toggleClass('disabled', false);
            $element.unbind('click', disabler);

            if(angular.isUndefined($attrs.restError)) return false;

            $scope.$evalAsync(function(){
              var response = {
                data:    data,
                status:  status,
                headers: headers,
                config:  config
              };

              $scope.$eval($attrs.restError, response);
            })
          });
        }
      }
    },

    link: function($scope, $element, $attrs) {
      $element.bind('click', function(){
        if($scope.$eval($attrs.restDisable) != true){
          $element.run($attrs);
        }else{
          console.error('Not calling REST endpoint '+$attrs.rest+', element is disabled')
        }
      });
    }
  }
})
.directive('restModel', function($interpolate, $http) {
  return {
    restrict: 'A',
    link:     function($scope, $element, $attrs){
      var fallback = $attrs.restDefault;

      if(angular.isDefined($attrs.restDefault)){
        fallback = $interpolate(fallback)($scope);
        $element.text(fallback);
      }else{
        $element.text('');
      }
      
      $scope.$watch('restModel', function(){
        var params = {};

        angular.forEach($attrs, function(val, key){
          if(key.match(/^restParam/)){
            params[key.replace(/^restParam/,'').toLowerCase()] = val;
          }
        });

        if(angular.isString($attrs.restModel)){
          $http({
            method: ($attrs.restMethod ? $attrs.restMethod.toUpperCase() : 'GET'),
            url:    $interpolate($attrs.restModel)($scope),
            params: params
          }).success(function(data){
            if(data.length == 0){
              data = fallback;
            }
            
            $element.text(data);

          }).error(function(data){
            $element.text(fallback);
          });
        }
      });
    }
  }
});
