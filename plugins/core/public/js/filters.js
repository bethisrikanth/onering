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

Array.prototype.firstWith = function(key, value){
  for(var i = 0; i < this.length; i++){
    if(this[i].hasOwnProperty(key)){

      if(angular.isUndefined(value)){
        return this[i];
      }else{
        if(this[i][key] == value){
          return this[i];
        }
      }
    }
  }

  return null;
}

Array.prototype.max = function() {
  return Math.max.apply(null, this);
};

Array.prototype.min = function() {
  return Math.min.apply(null, this);
};

angular.module('coreFilters', ['ng']).
filter('titleize', function(){
  return function(text){
    if(text) return text.toString().titleize();
    return text;
  };
}).
filter('autosize', function(){
  return function(bytes,fixTo,fuzz){
    bytes = parseInt(bytes);
    fuzz = (angular.isUndefined(fuzz) ? 0.99 : +fuzz);
    if(angular.isUndefined(fuzz)) fixTo = 2;

    if(bytes >=   (Math.pow(1024,8) * fuzz))
      return (bytes / Math.pow(1024,8)).toFixed(fixTo) + ' YiB';

    else if(bytes >=   (Math.pow(1024,7) * fuzz))
      return (bytes / Math.pow(1024,7)).toFixed(fixTo) + ' ZiB';

    else if(bytes >=   (Math.pow(1024,6) * fuzz))
      return (bytes / Math.pow(1024,6)).toFixed(fixTo) + ' EiB';

    else if(bytes >=   (Math.pow(1024,5) * fuzz))
      return (bytes / Math.pow(1024,5)).toFixed(fixTo) + ' PiB';

    else if(bytes >=   (Math.pow(1024,4) * fuzz))
      return (bytes / Math.pow(1024,4)).toFixed(fixTo) + ' TiB';

    else if(bytes >=   (1073741824 * fuzz))
      return (bytes / 1073741824).toFixed(fixTo) + ' GiB';

    else if(bytes >=   (1048576 * fuzz))
      return (bytes / 1048576).toFixed(fixTo) + ' MiB';

    else if(bytes >=   (1024 * fuzz))
      return (bytes / 1024).toFixed(fixTo) + ' KiB';

    else
      return bytes + ' bytes';
  }
}).
filter('autospeed', function(){
  return function(speed,unit,fixTo,fuzz){
    speed = parseInt(speed);
    fuzz = (angular.isUndefined(fuzz) ? 0.99 : +fuzz);
    if(angular.isUndefined(fuzz)) fixTo = 2;

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
      return (speed/1000000000000).toFixed(fixTo)+' THz';

    else if(speed >= 1000000000*fuzz)
      return (speed/1000000000).toFixed(fixTo)+' GHz';

    else if(speed >= 1000000*fuzz)
      return (speed/1000000).toFixed(fixTo)+' MHz';

    else if(speed >= 1000*fuzz)
      return (speed/1000).toFixed(fixTo)+' KHz';

    else
      return speed.toFixed(fixTo) + ' Hz';
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
filter('timeDuration', function(){
  return function(date,unit,delim){
    var rv = [];
    var start = moment(date);
    var now = moment();

    if(!angular.isArray(unit)){
      unit = [unit];
    }

    for(var i = 0; i < unit.length; i++){
      var upair = unit[i];
      var u = unit[i];

      if(u.indexOf(':') > 0){
        u = upair.split(':').splice(-1,1)[0];
        unit[i] = upair.split(':')[0];
      }

      var v = now.diff(start, unit[i]);

      if(v == 0)
        continue;

      rv.push(v.toString()+u);
      start.add(unit[i], v-1);
    }

    return rv.join(delim || ' ');
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
    return function(array,key,value,exclude){
      if (!(array instanceof Array)) return array;
      rv = array.filter(function(i){
        if($.isPlainObject(i)){
          var v = (exclude ? !i.hasOwnProperty(key) : i.hasOwnProperty(key));

          if(v && typeof(value) != 'null' && typeof(value) != 'undefined' && i[key] == value){
            return true;
          }else{
            return false;
          }
        }else{
          return array;
        }
      });
      return rv;
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('pluckFilter', function(){
    return function(array,key){
      if (!(array instanceof Array)) return array;

      rv = []

      for(var i = 0; i < array.length; i++){
        if(angular.isObject(array[i])){
          if(array[i].hasOwnProperty(key)){
            rv.push(array[i][key]);
          }
        }
      }

      console.log(rv);
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
  $provide.factory('minFilter', function(){
    return function(obj,field){
      if(obj instanceof Array){
        return obj.min();
      }else if($.isPlainObject(obj) && angular.isDefined(field) && obj[field] instanceof Array){
        return obj[field].min();
      }else{
        return null;
      }
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('maxFilter', function(){
    return function(obj,field){
      if(obj instanceof Array){
        return obj.max();
      }else if($.isPlainObject(obj) && angular.isDefined(field) && obj[field] instanceof Array){
        return obj[field].max();
      }else{
        return null;
      }
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('startsWithFilter', function(){
    return function(obj,test,ci){
      if(angular.isUndefined(obj) || obj === null){
        return false;
      }

      return obj.toString().match(new RegExp("^"+test,(ci==true ? "g" : undefined)));
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('endsWithFilter', function(){
    return function(obj,test,ci){
      if(angular.isUndefined(obj) || obj === null){
        return false;
      }

      return obj.toString().match(new RegExp(test+"$",(ci==true ? "g" : undefined)));
    }
  });
}]).
config(['$provide', function($provide) {
  $provide.factory('replaceFilter', function(){
    return function(str,find,rep,all){
      if(str instanceof Array){
        for(var i in str){
          if(typeof(str[i]) == 'string'){
            if(all == true){
              str[i] = str[i].replace(new RegExp(find,'g'), rep);
            }else{
              str[i] = str[i].replace(find, rep);
            }
          }
        }

        return str;
      }else if(typeof(str) == 'string'){
        if(all == true){
          return str.replace(new RegExp(find,'g'), rep);
        }

        return str.replace(find, rep);
      }else{
        return str;
      }
    }
  });
}]);

