String.prototype.toTitleCase = function(){
  return this.replace(/\w\S*/g, function(str){
    return str.charAt(0).toUpperCase() + str.substr(1).toLowerCase();
  });
};

Array.prototype.compact = function(){
  return this.filter(function(i){
    return i;
  });
}

angular.module('filters', ['ng']).
filter('titleize', function(){
  return function(text){
    if([
      'NOC'
    ].indexOf(text.toUpperCase()) >= 0)
      return text.replace(/_/, ' ').toUpperCase();

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
}).
filter('timeAgo', function(){
  return function(date){
    return moment(Date.parse(date)).fromNow();
  };
}).
config(['$provide', function($provide) {
  $provide.factory('skipFilter', function(){
    return function(array, skip){
      if (!(array instanceof Array)) return array;
      skip = parseInt(skip);
      rv = [];

      if(skip > array.length) return [];

      for(var i = skip; i < array.length; i++){
        rv.push(array[i]);
      }

      return rv;
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('joinFilter', function(){
    return function(array, delimiter){
      if (!(array instanceof Array)) return array;
      if(!delimiter) delimiter = '';
      return array.join(delimiter);
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('emptyFilter', function(){
    return function(array,key){
      if (!(array instanceof Array)) return array;
      rv = array.filter(function(i){
        if($.isPlainObject(i))
          return i.hasOwnProperty(key) && !i[key];
        else if(typeof(i) == 'string')
          return (i.length != 0);
        else
          return !i;
      });
      return rv;
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('compactFilter', function(){
    return function(array,key){
      if (!(array instanceof Array)) return array;
      rv = array.filter(function(i){
        if($.isPlainObject(i))
          return i.hasOwnProperty(key) && i[key];
        else if(typeof(i) == 'string')
          return (i.length == 0);
        else
          return i;
      });
      return rv;
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('propertyFilter', function(){
    return function(array,key,exclude){
      if (!(array instanceof Array)) return array;
      rv = array.filter(function(i){
        if($.isPlainObject(i)){
          return (exclude ? !i.hasOwnProperty(key) : i.hasOwnProperty(key));
        }else{
          return array;
        }
      });
      return rv;
    }
  });
}]);

