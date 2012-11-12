(function() {

  describe('SiteController', function() {
    var contact, controller, http, routeParams, scope, site, summary;
    beforeEach(module('app'));
    controller = scope = http = routeParams = summary = contact = site = null;
    beforeEach(inject(function(_$httpBackend_, $rootScope, $controller) {
      scope = $rootScope.$new();
      routeParams = {
        site: 's'
      };
      summary = [
        {
          "id": "ladc1",
          "count": 3,
          "children": [
            {
              "id": "ar5",
              "count": 2,
              "children": [
                {
                  "id": null,
                  "count": 2,
                  "children": [
                    {
                      "id": null,
                      "count": 2
                    }
                  ]
                }
              ]
            }, {
              "id": "ar6",
              "count": 1,
              "children": [
                {
                  "id": null,
                  "count": 1,
                  "children": [
                    {
                      "id": null,
                      "count": 1
                    }
                  ]
                }
              ]
            }
          ]
        }
      ];
      contact = [
        {
          x: 1
        }
      ];
      site = [
        {
          y: 5
        }
      ];
      http = _$httpBackend_;
      http.expectGET("/api/devices/summary/by-site/rack/model/fqdn/?where=site/" + routeParams.site).respond(summary);
      http.expectGET("/api/org/contacts/find/site/" + routeParams.site).respond(contact);
      http.expectGET("/api/devices/find/?q=site%2Fs%2F%5Erack").respond(site);
      return controller = $controller(SiteController, {
        $scope: scope,
        $routeParams: routeParams
      });
    }));
    it('should attach to $scope.summary', function() {
      http.flush();
      return expect(JSON.stringify(scope.summary)).toEqual(JSON.stringify(summary[0]));
    });
    it('should attach to $scope.racks', function() {
      http.flush();
      return expect(JSON.stringify(scope.racks)).toEqual(JSON.stringify(summary[0].children));
    });
    it('should attach to $scope.contact', function() {
      http.flush();
      return expect(JSON.stringify(scope.contact)).toEqual(JSON.stringify(contact[0]));
    });
    return it('should attach to $scope.devices', function() {
      http.flush();
      return expect(JSON.stringify(scope.devices)).toEqual(JSON.stringify(site));
    });
  });

}).call(this);
