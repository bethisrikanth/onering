The Onering API
===============

All interactions with Onering, either directly (via curl, wget, etc.) or indirectly (via the web interface) happen using a REST-style API.  It uses JSON as its primary serialization format, optionally returning plain text or YAML for certain endpoints.  Authentication is HTTP Basic Authentication via SSL.


Making a request
----------------

All URLs start with `https://onering/api/`.  Unauthenticated requests can use HTTP _or_ HTTPS, but authenticated requests can only use HTTPS.  It is recommended to always use HTTPS for all transactions.  All requests should plan to include the `version` query string.  If major backwards-incompatible API changes occur, this parameter will be honored to present older versions of the API in a functional state.  Without this parameter, the API will default to honoring the newest API version available.

All API requests happen using the standard HTTP verbs `GET`, `POST`, and `DELETE`.  For example, to view a list of all devices by ID, issue the following request:

```shell
curl -u user:pass -H 'User-Agent: MyApp (yourname@example.com)' https://onering/api/devices/list/id
```

To create or update something, the process is similar except that you MUST use the HTTPS site with your authentication, and you have to include the `Content-Type` header with your JSON data :

```shell
curl -u user:pass \
  -H 'Content-Type: application/json' \
  -H 'User-Agent: MyApp (yourname@example.com)' \
  -d '{ "id": "abc123" }' \
  https://onering/api/devices
```


Authentication
--------------

Currently, Onering supports HTTP Basic authentication for API endpoints your supplied credentials have access to.  This is secure since all authenticated requests use SSL.  If the credentials supplied are not valid, the server will return a `401 Unauthorized` status code.  If the credentials are not allowed to invoke a particular API endpoint, the server will return a `403 Forbidden` response.  All other successful responses will be answered with `200 OK`.

If the server itself is having trouble, it will issue a 500-series HTTP status and you should try your request later.


Identify your app
-----------------

You should include a `User-Agent` header with the name of your application and a link to it or your email address so it can be identified :

    User-Agent: Awesome Nagios Integrator (ariel@example.com)

If you are using the API for anything other than one-off queries (a tool that performs one-off queries does not count as one-off), please specify a custom User Agent to make tracking down sources of load easier on the application administrators.


Supports Plaintext, Where Applicable
------------------------------------

JSON is the default serialization format for all responses, and is the ONLY acceptable format for submissions.  Other formats can be returned for convenience in parsing the output.  These formats are specified using the `format=` query string.  They include:

* `format=yaml` : Returns the requested endpoint as a YAML document with the mimetype of `text/x-yaml`.
* `format=txt`  : Returns the requested endpoint as `snake_case_key: value` pairs, one per line as mimetype `text/plain`.

For all other `format=` values, JSON objects or arrays will be returned with a mimetype of `application/json`.


API endpoints ready for use
---------------------------

* [Core](plugins/core.md)
* [Devices](plugins/devices.md)
* [Provisioning](plugins/provisioning.md)