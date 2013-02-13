angular.module('uiD3', []).
directive('blockchart', function(){
  return {
    restrict: 'EC',
    scope: {
      data: '=',
      height: '=',
      width: '='
    },
    link: function(scope, element, attrs){
      var block_size = attrs.blockSize;
      var block_height = attrs.height;
      var block_width = attrs.width;
      var height = block_size * block_height;
      var width = block_size * block_width;
      var root = d3.select(element[0]);
      var svg = root.append('svg');

      svg.attr("width", width)
        .attr("height", height)
        .attr("class", "blockchart")
        .append("rect")
        .attr("class", "background")
        .attr("width", width)
        .attr("height", height);

      var plot = svg.append("g")
        .attr("class", "plot")
        .attr("width", width)
        .attr("height", height);

  //  draw grid on top
  //  verticals
      svg.selectAll("line.vertical")
      .data(d3.range(1, width, block_size))
      .enter().append("line")
      .attr("class", "vertical")
      .attr("x1", function(d){
        return d;
      })
      .attr("y1", 0)
      .attr("x2", function(d){
        return d;
      })
      .attr("y2", height);

  //  horizontals
      svg.selectAll("line.horizontal")
      .data(d3.range(1, height, block_size))
      .enter().append("line")
      .attr("class", "horizontal")
      .attr("x1", 0)
      .attr("y1", function(d){
        return d;
      })
      .attr("x2", width)
      .attr("y2", function(d){
        return d;
      });

      scope.$watch('data', function(d){
        var max = (attrs.yMax || d3.max(scope.data));
        var order = Math.pow(10, parseInt(max.toString().length)-1);
        var ymax = Math.ceil(max/order) * order;
        
        var ds = plot.selectAll('rect').data(scope.data);

        ds.enter().append('rect')
          .attr('width', block_size);

        ds.attr("height", function(d,i){
        //  bar height: ceil(value / values-per-block) * block height
            return Math.ceil(d / (ymax/block_height)) * block_size;
          })
          .attr("y", function(d,i){
        //  height less block bar height
            if(attrs.invertY == 'true')
              return 0;

              return height - $(this).attr('height');
          })
          .attr("x", function(d,i){
            return block_size*i
          });

        ds.exit().remove();
      });
    }
  };
});