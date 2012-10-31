function graphiteDirective(){
  var createHighchart = function(config){
    Highcharts.setOptions({
      global: {
        useUTC: false
      }
    });

    var options = {
      title: {
        text: (config.attributes.title || null),
      },

      chart: {
        animation: false,
        renderTo: config.target.parents(0).get(0),
        backgroundColor: null,
        className: config.attributes.class,
        zoomType: 'x',
        type: config.attributes.graphType
      },

      loading: {
        style: {
          backgroundColor: null
        }
      },

      tooltip: {
        enabled: true,
        crosshairs: true,
        valueDecimals: 2
      },

      xAxis: {
        type: 'datetime'
      },

      yAxis: {
        gridLineColor: 'rgba(45,45,45,0.75)',
        title: {
          text: (config.attributes.yAxisTitle || null)
        }
      },

      legend: {
        borderWidth: 0
      },

      element: config,

      plotOptions: {
        series: {
          connectNulls: (config.attributes.lineMode == 'connected' ? true : false),
          lineWidth: 3,

          events: {
            legendItemClick: function(e){
              $(e.target.chart).trigger('legendItemClick', e);
            },

            checkboxClick: function(e){
              $(e.target.chart).trigger('legendItemCheck', e);
            },

            click: function(e){
              $(e.target.chart).trigger('seriesClick', e);
            },

            hide: function(e){
              $(e.target.chart).trigger('seriesHide', e);
            },

            show: function(e){
              $(e.target.chart).trigger('seriesShow', e);
            },

            mouseOver: function(e){
              $(e.target.chart).trigger('seriesMouseOver', e);
            },

            mouseOut: function(e){
              $(e.target.chart).trigger('seriesMouseOut', e);
            },
          }
        }
      },

      credits: {
        enabled: false
      }
    };

    //console.log(options);

    return new Highcharts.Chart(options);
  };

  var populateChartFromGraphite = function(chart, url){
    $.getJSON(url, function(data){

      for(var series in data){
        var points = [];
        for(var point in data[series].datapoints){
          point = data[series].datapoints[point];
          points.push([parseFloat(point[1]*1000), (point[0] ? parseFloat(point[0]) : null)]);
        }

        chart.addSeries({
          name: data[series].target,
          data: points,
          marker: {
            enabled: false
          }
        }, false, false);
      }

      chart.redraw();
      //chart.hideLoading();
    });
  };

  var populateChartFromJSON = function(chart, data){
    // chart.addSeries({
    //   name: data[series].target,
    //   data: points,
    //   marker: {
    //     enabled: false
    //   }
    // }, false, false);

    // chart.redraw();
  };

  return {
    restrict: 'EAC',
    scope: {
      url: '@',
      origin: '@',
      lineMode: '@',
      type: '@',
      yAxisTitle: '@',
      data: '@'
    },
    link: function(scope, element, attrs){
      var config = {
        target: element,
        attributes: attrs
      };

      if(attrs.hasOwnProperty('title'))
        config.title = {
          text: attrs.title
        };

      attrs.$observe('url', function(url){
        var chart = createHighchart(config);
        //chart.showLoading(attrs.loading);
        chart.options.element.url = url;

        switch(attrs.origin){
        case "graphite":
          populateChartFromGraphite(chart, chart.options.element.url);
          break;

        default:
          //populateChartFromJSON(chart, $.parseJSON(element))
        }
      });

    }
  };    
}