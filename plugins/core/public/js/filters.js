String.prototype.toTitleCase = function(){
  return this.replace(/\w\S*/g, function(str){
    return str.charAt(0).toUpperCase() + str.substr(1).toLowerCase();
  });
};

String.prototype.titleize = function(){
  var overrides = {
    'noc':    'NOC',
    'centos': 'CentOS',
    'redhat': 'RedHat',
    'pam':    'PAM',
    'ldap':   'LDAP'
  };

  if(overrides.hasOwnProperty(this.toLowerCase()))
    return overrides[this.toLowerCase()];

  return this.replace(/_/g, ' ').toTitleCase();
};

Array.prototype.diff = function(a) {
  return this.filter(function(i) {return !(a.indexOf(i) > -1);});
};

Array.prototype.collect = function(key) {
  var rv = [];


  if(typeof(key) == 'string'){
    for(var i = 0; i < this.length; i++){
      rv.push(this[i][key]);
    }
  }

  return rv;
};

angular.module('coreFilters', ['ng']).
filter('titleize', function(){
  return function(text){
    if(text) return text.toString().titleize();
    return text;
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
filter('section', function(){
  return function(str, delim, start, len){
    if(str){
      var rv = str.split(delim);
      start = parseInt(start);
      len = parseInt(len);

      if($.isNumeric(start)){
        if($.isNumeric(len)){
          return rv.slice(start, len).join(delim);
        }

        return rv.slice(start).join(delim);
      }

      return str;
    }

    return null;
  };
}).
filter('truncate', function () {
  return function(text, length, end){
    if (isNaN(length))
      length = 10;

    if (end === undefined)
      end = "...";

    if (text.length <= length || text.length - end.length <= length){
      return text;
    }
    else {
      return String(text).substring(0, length-end.length) + end;
    }
  };
}).
filter('jsonify', function () {
  return function(obj, indent){
    return JSON.stringify(obj, null, (indent || 4));
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
}]).
config(['$provide', function($provide) {
  $provide.factory('diffFilter', function(){
    return function(array,other){
      if (!(array instanceof Array)) array = [];
      if (!(other instanceof Array)) other = [];

      return array.diff(other);
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('lengthFilter', function(){
    return function(obj){
      if(obj instanceof Array){
        return obj.length;
      }else if($.isPlainObject(obj)){
        return Object.keys(obj).length;
      }else if(typeof(obj) == 'string'){
        return obj.length;
      }else{
        return null;
      }
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('replaceFilter', function(){
    return function(str,find,rep){
      if(str instanceof Array){
        for(var i in str){
          if(typeof(str[i]) == 'string'){
            str[i] = str[i].replace(find, rep);
          }
        }

        return str;
      }else if(typeof(str) == 'string'){
        return str.replace(find, rep);
      }else{
        return str;
      }
    }
  });
}]);

