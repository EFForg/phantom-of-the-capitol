# API Usage

The application has three endpoints which are commonly used by application front-ends:

### `POST /retrieve-form-elements`

> Provide a json object containing an array of [`bio_ids`](http://bioguide.congress.gov/) in string format.  Responds with a json object containing the necessary fields for the congressional contact forms.
>
> Example:
>
>     $ curl -H "Content-Type: application/json" -d '{"bio_ids": ["C000880", "A000360"]}' http://localhost:3001/retrieve-form-elements
>     {"C000880":{"required_actions":[{"maxlength":null,"value":"$NAME_FIRST","options_hash":null},{"maxlength":null,"value":"$NAME_LAST","options_hash":null},{"maxlength":null,"value":"$ADDRESS_STREET","options_hash":null},{"maxlength":null,"value":"$ADDRESS_CITY","options_hash":null},{"maxlength":null,"value":"$ADDRESS_ZIP5","options_hash":null},{"maxlength":null,"value":"$EMAIL","options_hash":null},{"maxlength":null,"value":"$SUBJECT","options_hash":null},{"maxlength":null,"value":"$MESSAGE","options_hash":null},{"maxlength":null,"value":"$NAME_PREFIX","options_hash":{" Mr. ":"Mr."," Mrs. ":"Mrs."," Ms. ":"Ms."," Mr. and Mrs. ":"Mr. and Mrs."," MSgt ":"MSgt"," Dr. ":"Dr."," Reverend ":"Reverend"," Sister ":"Sister"," Pastor ":"Pastor"," The Honorable ":"The Honorable"," Representative ":"Representative"," Senator ":"Senator"}},{"maxlength":null,"value":"$ADDRESS_STATE_POSTAL_ABBREV","options_hash":"US_STATES_AND_TERRITORIES"},{"maxlength":null,"value":"$TOPIC","options_hash":{"Agriculture":"AG","Banking & Credit":"BN","Budget & Taxes":"BU","Business, Commerce & Labor":"CM","Congress":"CG","Federal & Postal Employees":"CS","Education, Science & Technology":"ED","Energy":"EN","Environment, Nat. Resources & Wildlife":"EV","Foreign Affairs":"FA","Health Care & Social Issues":"HC","Homeland Security & Immigration":"HS","Judiciary & Crime":"JU","Native Americans":"NA","Medicaid/Medicare & Welfare":"MD","Seniors & Social Security":"SS","Telecomm. & Transportation":"TC","*Other*":"CWM1"}}]},"A000360":{"required_actions":[{"maxlength":null,"value":"$NAME_FIRST","options_hash":null},{"maxlength":null,"value":"$NAME_LAST","options_hash":null},{"maxlength":null,"value":"$ADDRESS_STREET","options_hash":null},{"maxlength":null,"value":"$ADDRESS_CITY","options_hash":null},{"maxlength":null,"value":"$ADDRESS_ZIP5","options_hash":null},{"maxlength":null,"value":"$EMAIL","options_hash":null},{"maxlength":null,"value":"$MESSAGE","options_hash":null},{"maxlength":null,"value":"$ADDRESS_STATE","options_hash":["AK","AL","AR","AZ","CA","CO","CT","DC","DE","FL","GA","HI","IA","ID","IL","IN","KS","KY","LA","MA","MD","ME","MI","MN","MO","MS","MT","NC","ND","NE","NH","NJ","NM","NV","NY","OH","OK","OR","PA","RI","SC","SD","Tennessee","TX","UT","VA","VT","WA","WI","WV","WY","AS","GU","MP","PR","VI","UM","FM","MH","PW","AA","AE","AP"]},{"maxlength":null,"value":"$TOPIC","options_hash":["Abortion","Agriculture","Animal_Rights","Banking","Budget","Casework","Civil_Rights","Defense","Economy","Education","Energy","Environment","Foreign_Affairs","Guns_Firearms","Health_Care","Homeland_Security","Immigration","Information_Technology","Labor","National_Parks","Postal_Service","Small_Business","Social_Security","Taxes","Trade","Transportation","Veterans","Welfare","Special_Requests"]}]}}

### `POST /fill-out-form`

> Provide a json object containing the `bio_id` of the member of congress, the `fields` to fill out, and a `campaign_tag` for tracking successes.
>
> Responds with a json object containing a status:
>
> - `success` if the request succeeded.
> - `error` if there was a problem. In this case, there will be an additional message giving more information.
> - `captcha_needed` if the form requires a captcha to be filled out.  In this case, a url will be provided which gives a relative path to the captcha image that can be provided to the end user, as well as a `uid` that will have to be provided on the subsequent `fill-out-captcha` request.
>
>
> Example #1, with captcha:
>
>     $ curl -H "Content-Type: application/json" -d '{"bio_id": "A000000", "fields": {"$NAME_FIRST": "John", "$NAME_LAST": "Doe", "$ADDRESS_STREET": "123 Main Street", "$ADDRESS_CITY": "New York", "$ADDRESS_ZIP5": "10112", "$EMAIL": "joe@example.com", "$MESSAGE": "I have concerns about the proposal....", "$NAME_PREFIX": "Grand Moff"}}' http://localhost:3001/fill-out-form
>     {"status":"captcha_needed","url":"/captchas/e410e577123c5e19a526ad3f6b.png"}
>
> Example #2, no captcha:
>
>     $ curl -H "Content-Type: application/json" -d '{"bio_id": "A111111", "campaign_tag": "stop_sopa", "fields": {"$NAME_FIRST": "John", "$NAME_LAST": "Doe", "$ADDRESS_STREET": "123 Main Street", "$ADDRESS_CITY": "New York", "$ADDRESS_ZIP5": "10112", "$EMAIL": "joe@example.com", "$MESSAGE": "I have concerns about the proposal....", "$NAME_PREFIX": "Grand Moff"}}' http://localhost:3001/fill-out-form
>     {"status":"success"}

### `POST /fill-out-captcha`

> For continuing filling in the remote form when a captcha is present.  Provide a json object containing the same `uid` you provided in the previous request to `/fill-out-captcha`, as well as the captcha answer in the `answer` string.  As above, responds with a javascript object containing the status `success` or `error`.
>
> Example for #1 above:
>
>     $ curl -H "Content-Type: application/json" -d '{"answer": "cx9bp", "uid": "example_uid"}' http://localhost:3001/fill-out-captcha
>     {"status":"success"}

## Status Indications and Helpers

The application has a number of other helpful endpoints to indicate status and failures:

### `GET /recent-fill-image/<bio_id>`

> Provide a `bio_id` as part of the GET request.  Responds with a 302 redirect to a badge indicating the status of form fills since the last time the congress member actions were udated.

### `GET /recent-fill-status/<bio_id>`

> Provide a `bio_id` as part of the GET request.  Responds with a hash giving statistics on the number of successes, failures, and errors encountered when trying to fill in forms since the last time the congress member actions were updated.

There area also endpoints which require authorization to access.  The following endpoints are only accessible if a valid `debug_key` is provided as a parameter.

### `GET /recent-statuses-detailed/<bio_id>`

> Provide a `bio_id` as part of the GET request.  Responds with a detailed list of recent statuses when trying to fill in the form for this congress member.  'Recent' means since the last time this congress member has been updated with new success criteria or actions.

### `GET /list-actions/<bio_id>`

> Provide a `bio_id` as part of the GET request.  Responds with a detailed list of all actions that are performed to fill out the form for this congress member.

### `GET /list-congress-members`

> Responds with a list of all congress members and their websites.

### `GET /successful-fills-by-date/<bio_id>`

> Responds with a count of the number of successful fills, grouped by date.  Optionally provide the `<bio_id>` route parameter to retrieve results only for that member.  You can also optionally provide a `campaign_tag` parameter to retrieve results filtered by `campaign_tag`.
>
> Example with `bio_id`, without `campaign_tag`:
>
>     $ curl 'http://localhost:3001/successful-fills-by-date/A000000?debug_key=some_key'
>     {"2014-06-27 00:00:00 -0700":3,"2014-06-28 00:00:00 -0700":0,"2014-06-29 00:00:00 -0700":2,"2014-06-30 00:00:00 -0700":2,"2014-07-01 00:00:00 -0700":4}
>
> Example with `bio_id` and `campaign_tag`:
>
>     $ curl 'http://localhost:3001/successful-fills-by-date/A000000?campaign_tag=some_tag&debug_key=some_key'
>     {"2014-06-27 00:00:00 -0700":1,"2014-06-28 00:00:00 -0700":0,"2014-06-29 00:00:00 -0700":1,"2014-06-30 00:00:00 -0700":2,"2014-07-01 00:00:00 -0700":0}
>
> Example without `bio_id` or `campaign_tag`:
>
>     $ curl 'http://localhost:3001/successful-fills-by-date/?debug_key=some_key'
>     {"2014-06-27 00:00:00 -0700":360,"2014-06-28 00:00:00 -0700":118,"2014-06-29 00:00:00 -0700":232,"2014-06-30 00:00:00 -0700":89,"2014-07-01 00:00:00 -0700":842}
>
> Example without `bio_id`, with `campaign_tag`:
>
>     $ curl 'http://localhost:3001/successful-fills-by-date/?campaign_tag=some_tag&debug_key=some_key'
>     {"2014-06-27 00:00:00 -0700":56,"2014-06-28 00:00:00 -0700":27,"2014-06-29 00:00:00 -0700":48,"2014-06-30 00:00:00 -0700":12,"2014-07-01 00:00:00 -0700":98}

### `GET /successful-fills-by-member/`

> Responds with a count of the number of successful fills, grouped by member of congress bioguide id.  You can also optionally provide a `campaign_tag` parameter to retrieve results filtered by `campaign_tag`.
>
> Example without `campaign_tag`:
>
>     $ curl 'http://localhost:3001/successful-fills-by-member/?debug_key=some_key'
>     {"A000000":312,"B000000":187,"C000000":103,"D000000":782,"E000000":41}
>
> Example with `campaign_tag`:
>
>     $ curl 'http://localhost:3001/successful-fills-by-member/?campaign_tag=some_tag&debug_key=some_key'
>     {"A000000":28,"B000000":20,"C000000":9,"D000000":70,"E000000":5}
