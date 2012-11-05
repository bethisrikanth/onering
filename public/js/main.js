String.prototype.toTitleCase = function(){
  return this.replace(/\w\S*/g, function(str){
    return str.charAt(0).toUpperCase() + str.substr(1).toLowerCase();
  });
};

var app = angular.module('app', ['filters', 'oneringServices']);

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

angular.module('filters', []).
filter('titleize', function(){
  return function(text){
    return text.replace(/_/, ' ').toTitleCase();
  };
}).
filter('autosize', function(){
  return function(bytes){
    bytes = parseInt(bytes);
    fuzz = 0.99;

    if(bytes >=   (Math.pow(1024,8) * fuzz))
      return (bytes / Math.pow(1024,8)).toFixed(2) + ' YiB';

    else if(bytes >=   (Math.pow(1024,7) * fuzz))
      return (bytes / Math.pow(1024,7)).toFixed(2) + ' ZiB';

    else if(bytes >=   (Math.pow(1024,6) * fuzz))
      return (bytes / Math.pow(1024,6)).toFixed(2) + ' EiB';

    else if(bytes >=   (Math.pow(1024,5) * fuzz))
      return (bytes / Math.pow(1024,5)).toFixed(2) + ' PiB';

    else if(bytes >=   (Math.pow(1024,4) * fuzz))
      return (bytes / Math.pow(1024,4)).toFixed(2) + ' TiB';

    else if(bytes >=   (1073741824 * fuzz))
      return (bytes / 1073741824).toFixed(2) + ' GiB';

    else if(bytes >=   (1048576 * fuzz))
      return (bytes / 1048576).toFixed(2) + ' KiB';

    else
      return bytes + ' bytes';
  }
}).
filter('autospeed', function(){
  return function(speed, unit){
    speed = parseInt(speed);
    fuzz = 0.99;

    if(unit){
      switch(unit.toUpperCase()){
      case 'K':
        speed = speed * 1000;
        break;
      case 'M':
        speed = speed * 1000000;
        break;
      case 'G':
        speed = speed * 1000000000;
        break;
      case 'T':
        speed = speed * 1000000000000;
        break;
      }
    }

    if(speed >= 1000000000000*fuzz)
      return (speed/1000000000000)+' THz';

    else if(speed >= 1000000000*fuzz)
      return (speed/1000000000)+' GHz';

    else if(speed >= 1000000*fuzz)
      return (speed/1000000)+' MHz';

    else if(speed >= 1000*fuzz)
      return (speed/1000)+' KHz';

    else
      return speed + ' Hz';
  };
}).
filter('fix', function(){
  return function(number, fixTo){
    return parseFloat(number).toFixed(parseInt(fixTo));
  }
});


app.factory('config', function(){
  var config = {
    'baseurl': 'http://localhost:8080'
  };

  $.getJSON('/config/web.json', function(data){
    $.extend(true, config, data);
  });

  return {
    get: function(value){
      var root = config;
      var s = value.split('.');

      for(var k in s){
        if(!root.hasOwnProperty(s[k])) return null;
        root = root[s[k]];
      }

      return root;
    }
  };
});

app.config(['$routeProvider', function($routeProvider) {
  $routeProvider.
    when('/inf', {
      templateUrl: 'views/sites.html',
      controller:  DeviceSummaryController
    }).
    when('/inf/summary/:field', {
      templateUrl: 'views/summary.html',
      controller:  DeviceSummaryController
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
