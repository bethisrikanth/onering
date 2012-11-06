'use strict';

/* Services */

angular.module('apiService', ['ngResource']).
factory('Summary', function($resource){
  return $resource('/api/devices/summary/by-:field', {
    field: '@field'
  });
}).
factory('Query', function($resource){
  return $resource('/api/devices/find/?q=:query', {
    query: '@query'
  });
}).
factory('Device', function($resource){
  return $resource('/api/devices/:id', {
    id: '@id'
  });
}).
factory('Site', function($resource){
  return $resource('/api/devices/summary/by-site/rack/model/?where=site/:site', {
    site: '@site'
  });
}).
factory('SiteContact', function($resource){
  return $resource('/api/org/contacts/find/site/:site', {
    site: '@site'
  });
}).
factory('Rack', function($resource){
  return $resource('/api/devices/summary/by-unit/fqdn/?where=site/:site/rack/:rack', {
    site: '@site',
    rack: '@rack'
  });
});