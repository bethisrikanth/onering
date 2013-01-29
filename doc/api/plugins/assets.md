Assets
======

The Assets plugin is one of the primary components of Onering.  Every trackable, searchable, reportable object that you wish to keep in Onering is represented as an asset.  This API is used to create, retrieve, update, and search for assets using any field associated with those assets.


Endpoints Summary
-----------------
* `GET /api/devices/abc123` - get node abc123
* `GET /api/devices/abc123/get/<field>[/<other> ...]` - get a plaintext list of one or more properties
* `GET /api/devices/find/<urlquery>` - find all nodes that match <urlquery>
* `GET /api/devices/list/<field>[/<urlquery>]` - list the value of all <field>s, optionally only for nodes matching <urlquery>
* `POST /api/devices[/abc123]` - create/update node ID 'abc123', submitting JSON as `application/json`.


Get Device
----------

* `GET /api/devices/abc123` will retrieve one and only one node, whose ID is `abc123`.

<pre>
  {
     "id" : "abc123",
     "collected_at" : "2013-01-29T16:25:20Z",
     "created_at" : "2012-11-16T21:20:06Z",
     "updated_at" : "2013-01-29T16:25:20Z",
     "status" : "online",
     "name" : "api-prod-103.dc1.example.com",
     "tags" : [
        "load_test_node"
     ],
     "aliases" : [
        "api-prod-103"
     ],
     "properties" : {
        "gateway" : "192.168.56.1",
        "ip" : "192.168.56.134",
        "arch" : "x86_64",
        "bios_version" : "1.69",
        "kernel" : "2.6.18-194.el5",
        ...
     }
  }
</pre>

Certain fields are important or have a defined purpose:

* **id**: The unique ID for this node.  Can be user specified or auto-generated.
* **created\_at**, **updated\_at**: Automatic timestamps for when the record was created or updated.
* **collected\_at**: Used to specify when an automatic inventory was last collected.  The updated_at time reflects any change to the node, including manually from the frontend.  collected_at only updates when POSTing an update that contains `"inventory": true`.
* **name**: What you call this node.  By convention this matches the FQDN of automatically inventoried node (if the node has an FQDN), but can be anything.
* **tags**: An arbitrary list of tags that can help provide alternate ways to search for nodes.
* **aliases**: Alternate names for this node.  This is a good place to keep legacy and colloquial names for the node.
* **properties**: This is where all non-schema data about a node is kept.

### Properties

The properties attribute on a node is a rich object that many plugins can contribute to.  Other plugins do the work of collecting domain-specific data (like network details, which Chef cookbooks a node belongs to, or what groups the node belongs to in your proxy server).  This allows these data to converge at one point, the node itself, which provides a powerful means of correlating and filtering based on any of these details.  Queries such as "show me all nodes on the US West coast that have the 'httpd' Chef cookbook and have 'Application X' deployed to them" are possible.

Data that were once sequestered in their respective management systems, able to be cross-referenced only through hacks and scripts, can be universally queried using one interface.


Get Property
------------

If you only need to retrieve a few property values as plaintext (useful in scripts), there is a shortcut URL:

* `GET /api/devices/abc123/get/<field>[/<other> ...]` - get a plaintext list of one or more properties

### Example:

`GET /api/devices/abc123/get/site/ip/gateway`:

<pre>
dc1
192.168.56.134
192.168.56.1
</pre>


Find Devices
------------

### URL Query Syntax

URL queries are filters applied to all assets, in sequence, to narrow down the list to a set of results.  All searches in Onering are done using URL queries.  The general syntax looks like this:  `field/value/field2/value2`.  You specify queries in field-value pairs, paring down your results with each pair.

URL queries support special operations to help build more (or less) specific searches.


#### Values

By default, the `value` search operates as "if x contains 'value'".  You can specify certain modifiers to control this behavior:

* `^value` : _starts with_ "value".
* `value$` : _ends with_ "value".
* `val~e` :  greedy contains "val[any characters]e" (e.g.: matches **value**, **vale**, **vale**t, **valet ke**y)


#### Fields

You can specify multiple fields to search on by separating them with a colon `:`:

* `field:other:more/value`, which reads as "if field OR other OR more contains 'value'"

And you can specify whether a field is absent with:

* `^field`, which reads as "if field is not present". This must appear as the last statement in the URL query.


### Endpoints

* `GET /api/devices/find/<urlquery>` will return all nodes that match `<urlquery>`
  * **Returns**: An array of nodes.

* `GET /api/devices/list/<field>/where/<urlquery>` will return a list of the values of all _field_s that match `<urlquery>`
  * **Returns:** An array of values.


Create / Update Device
----------------------

* `POST /api/devices[/abc123]` will create/update node ID 'abc123', setting the status field to "online".  If you specify an "id" field in the submitted document, you may omit the ID from the URL.

<pre>
{
  "id": "abc123"
  "status": "online"
}
</pre>

Creating and updating nodes uses the same API endpoint.  This method requires that you build a JSON-formatted object and `POST` it to the endpoint with `Content-Type: application/json`.  Onering, by default, will perform a deep merge of the object you just submitted with the existing object (if there is one).  The semantics of this merge are as follows:

### Scalars

For scalar values (strings, numbers, booleans, dates), any existing values will be _replaced_ by new ones:

#### Submitted JSON...
<pre>
{
  "id": "abc123",
  "status": "fault"
}
</pre>

#### ...merges with existing node...
<pre>
{
  "id": "abc123",
  "status": "online",
  "name" : "api-prod-103.dc1.example.com",
  ...
}
</pre>

#### ...and becomes:
<pre>
{
  "id": "abc123",
  "status": "fault",
  "name" : "api-prod-103.dc1.example.com",
  ...
}
</pre>

### Vectors

For vector values (arrays, hashes [aka. objects, maps, dictionaries, ...]), existing values will be augmented with new ones.  For hashes, new keys will be added to the existing hash, and existing keys will be handled using the same rules described here and above (that is, scalars are replaced and vectors are merged).  If a new value appears in an incoming array, it will be added to the existing array.  Note that the reverse is not true; values in the existing array/hash not appearing in the new one won't be removed. See the @ (replace) modifier for more).

#### Submitted...

<pre>
{
  "id": "abc123",
  "properties": {
    "new": "value",
    "existing": "newvalue"
  }
}
</pre>

#### ...merges with...

<pre>
{
  "id": "abc123",
  "properties": {
    "existing": "outdated",
    "other":    1234,
    ...
  }
}
</pre>

#### ...becoming:

<pre>
{
  "id": "abc123",
  "properties": {
    "new": "value",
    "existing": "newvalue",
    "other":    1234,
    ...
  }
}
</pre>


## Disable Deep Merge: @key

Sometimes there are occasions when the deep merge behavior is undesirable for a particular key.  For example, if you have a plugin that collects network data via LLDP for a node's network interfaces, deep merge would not be useful for that data.  As the data changes, you could potentially see old values and new values showing up at the same time.  While there are conventions in data modeling that can minimize this risk, it's all around simpler to specify that whenever Onering sees the key _properties.network_, the existing _properties.network_ object should be cleared out and the new data should replace it.

The POSTed JSON would look something like this:

<pre>
{
  "id": "abc123",
  "properties": {
    "@network": {
      "interfaces": [{
        "name": "eth0",
        "switch": "sw-rack3-ring0.dc1.example.com",
        ...
      }]
    }
  }
}
</pre>

By using the '@' sign in the submitted JSON, Onering knows to delete any existing _properties.network_ object before saving the incoming one.  Note that the '@' will be omitted from the name before being saved.