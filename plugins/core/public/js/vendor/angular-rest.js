angular.module('rest', [])
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
.directive('rest', function() {
  return {
    restrict: 'A',
    controller: function($scope, $element, $attrs, $http){
      $element.callHttp = function(){
        var method = $attrs.restMethod;
        var url =  $attrs.rest;
        var data = $scope.$eval($attrs.restData);

        if(url){
          $http({
            method: (method ? method.toUpperCase() : 'GET'),
            url:    url,
            data:   (angular.isUndefined(data) ? null : JSON.stringify(data())),
            params: {
              severity: ($attrs.restSeverity || 'ignore')
            }
          }).success(function(data, status, headers, config){
            if(angular.isUndefined($attrs.restSuccess)) return false;

            $scope.$evalAsync(function(){
              var response = {
                data:    data,
                status:  status,
                headers: headers,
                config:  config
              };

              $scope.$eval($attrs.restSuccess);
            })
          }).error(function(data, status, headers, config){
            if(angular.isUndefined($attrs.restError)) return false;


            $scope.$evalAsync(function(){
              var response = {
                data:    data,
                status:  status,
                headers: headers,
                config:  config
              };

              $scope.$eval($attrs.restError);
            })
          });
        }
      }
    },

    link: function($scope, $element, $attrs) {
      $element.bind('click', function(){
        $element.callHttp();
      });
    }
  }
})