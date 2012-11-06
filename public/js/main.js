var app = angular.module('app', ['filters', 'apiService']);

app.directive('chart', function() {
  return {
    restrict: 'EAC',
    link: function(scope, elm, attr) {
      var chart = new google.visualization.PieChart(elm[0]);
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

app.config(['$routeProvider', function($routeProvider) {
  $routeProvider.
    when('/inf', {
      templateUrl: 'views/sites.html',
      controller:  SummaryController,
      params: {
        field: 'site'
      }
    }).
    when('/inf/summary/:field', {
      templateUrl: 'views/summary.html',
      controller:  SummaryController
    }).
    when('/node/:id', {
      templateUrl: 'views/node.html',
      controller:  NodeController
    }).
    when('/site/:site/:rack', {
      templateUrl: 'views/rack.html',
      controller:  RackController
    }).
    when('/site/:site', {
      templateUrl: 'views/site.html',
      controller:  SiteController
    }).
    when('/inf/:field', {
      templateUrl: 'views/devices.html',
      controller: QueryController
    }).
    when('/inf/show/:field/:query', {
      templateUrl: 'views/devices.html',
      controller: QueryController
    }).
    otherwise({
      templateUrl: 'views/index.html',
      controller:  DefaultController
    })
}]);


try {
  // manual bootstrap, when google api is loaded
  google.load('visualization', '1.0', {'packages':['corechart']});
  google.setOnLoadCallback(function() {
    angular.bootstrap(document.body, ['app']);
  });
} catch(e) {
  if (console && console.log) {
    console.log("Unable to load google: " + e);
  }
}
