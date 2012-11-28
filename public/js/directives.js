angular.module('directives', []).directive('onEnter', function() {
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
}).
directive('chart', function() {
  return {
    restrict: 'EAC',
    link: function(scope, element, attr) {
      var chart = new google.visualization.PieChart(element[0]);
      var columns = scope.$eval(attr.columns);

      scope.$watch(attr.rows, function(rows) {
        scope.$eval(rows);
        var dataMaster = new google.visualization.DataTable();
        var options = {
          width: parseInt(attr.width || 400),
          height: parseInt(attr.height || 200),
          enableInteractivity: (attr.interactive || false),

          legend: {
            position: attr.legendPosition
          },
          tooltip: {
            trigger: attr.tooltipTrigger
          }
        };

        if(attr.title) options['title'] = attr.title;


    //  PIE CHART OPTIONS
        options['pieSliceText'] = attr.labelStyle;
        options['sliceVisibilityThreshold'] = 0.01;

        if(attr.hideLastSlice){
          options['slices'] = {};
          options['slices'][columns.length-1] = {
            color: '#D9E6FF'
          };
        }

    //  Add data
        dataMaster.addColumn('string', 'Series');
        dataMaster.addColumn('number', 'Number');

        for(var i = 0; i < columns.length; i++){
          dataMaster.addRow([columns[i], rows[i]]);
        }



        //console.log(options)
        chart.draw(dataMaster, options);
      }, true);

    }
  };
});
