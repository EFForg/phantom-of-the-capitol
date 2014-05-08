# CongressForms
A RESTful API for retrieving the required fields for and filling out the contact forms of members of the US Congress.
This project relies on [Contact Congress](https://github.com/unitedstates/contact-congress) as the data source for congress member forms.

[![Build Status](https://travis-ci.org/Hainish/congress-forms.png)](http://travis-ci.org/Hainish/congress-forms)

## Installation and Setup

### The easy way (for developers)

#### Requirements

 - `apt-get install vagrant virtualbox`

#### Installation

 - `vagrant up`
 - `vim config/congress-forms_config.rb # edit settings here`

#### Running

 - `vagrant ssh`
 - `cd /vagrant`
 - `rackup`

### The hard way (or when running in production)

#### Requirements

 - `apt-get install imagemagick libmysql++-dev libpq-dev git libqt4-dev`
 - Download and install the latest phantomjs from http://phantomjs.org/

#### Installation

 - `apt-get install ruby`

or [install ruby with rvm](http://rvm.io).

 - `gem install bundler`
 - `bundle install`

Create the database, then

 - `cp config/database-example.rb config/database.rb`
 - `vim config/database.rb # fill in db info`
 - `cp config/congress-forms_config.rb.example config/congress-forms_config.rb`
 - `bundle exec rake ar:create ar:schema:load`

#### Populating the database

Clone a copy of the contact-congress and store it somewhere:

 - `git clone https://github.com/unitedstates/contact-congress`

Then cd back over to congress-forms and run

 - `bundle exec rake congress-forms:map_forms[contact_congress_directory]`

replacing `contact_congress_directory` with the path where you cloned the `contact-congress` project.

#### Running

Just run `rackup`

## Testing

If you haven't set up the test db, create it, then

 - `vim config/database.rb # fill in the test db info`

Create and prepare the test database:

 - `PADRINO_ENV=test bundle exec rake ar:create ar:schema:load`

And run

 - `bundle exec rspec spec`

## Usage

The application has three endpoints to post to:

### `/retrieve-form-elements`

Provide a json object containing an array of [`bio_ids`](http://bioguide.congress.gov/) in string format.  Responds with a json object containing the necessary fields for the congressional contact forms.

Example:

    $ curl -H "Content-Type: application/json" -d '{"bio_ids": ["C000880", "A000360"]}' http://localhost:9292/retrieve-form-elements
    {"C000880":{"required_actions":[{"maxlength":null,"value":"$NAME_FIRST","options_hash":null},{"maxlength":null,"value":"$NAME_LAST","options_hash":null},{"maxlength":null,"value":"$ADDRESS_STREET","options_hash":null},{"maxlength":null,"value":"$ADDRESS_CITY","options_hash":null},{"maxlength":null,"value":"$ADDRESS_ZIP5","options_hash":null},{"maxlength":null,"value":"$EMAIL","options_hash":null},{"maxlength":null,"value":"$SUBJECT","options_hash":null},{"maxlength":null,"value":"$MESSAGE","options_hash":null},{"maxlength":null,"value":"$NAME_PREFIX","options_hash":{" Mr. ":"Mr."," Mrs. ":"Mrs."," Ms. ":"Ms."," Mr. and Mrs. ":"Mr. and Mrs."," MSgt ":"MSgt"," Dr. ":"Dr."," Reverend ":"Reverend"," Sister ":"Sister"," Pastor ":"Pastor"," The Honorable ":"The Honorable"," Representative ":"Representative"," Senator ":"Senator"}},{"maxlength":null,"value":"$ADDRESS_STATE_POSTAL_ABBREV","options_hash":"US_STATES_AND_TERRITORIES"},{"maxlength":null,"value":"$TOPIC","options_hash":{"Agriculture":"AG","Banking & Credit":"BN","Budget & Taxes":"BU","Business, Commerce & Labor":"CM","Congress":"CG","Federal & Postal Employees":"CS","Education, Science & Technology":"ED","Energy":"EN","Environment, Nat. Resources & Wildlife":"EV","Foreign Affairs":"FA","Health Care & Social Issues":"HC","Homeland Security & Immigration":"HS","Judiciary & Crime":"JU","Native Americans":"NA","Medicaid/Medicare & Welfare":"MD","Seniors & Social Security":"SS","Telecomm. & Transportation":"TC","*Other*":"CWM1"}}]},"A000360":{"required_actions":[{"maxlength":null,"value":"$NAME_FIRST","options_hash":null},{"maxlength":null,"value":"$NAME_LAST","options_hash":null},{"maxlength":null,"value":"$ADDRESS_STREET","options_hash":null},{"maxlength":null,"value":"$ADDRESS_CITY","options_hash":null},{"maxlength":null,"value":"$ADDRESS_ZIP5","options_hash":null},{"maxlength":null,"value":"$EMAIL","options_hash":null},{"maxlength":null,"value":"$MESSAGE","options_hash":null},{"maxlength":null,"value":"$ADDRESS_STATE","options_hash":["AK","AL","AR","AZ","CA","CO","CT","DC","DE","FL","GA","HI","IA","ID","IL","IN","KS","KY","LA","MA","MD","ME","MI","MN","MO","MS","MT","NC","ND","NE","NH","NJ","NM","NV","NY","OH","OK","OR","PA","RI","SC","SD","Tennessee","TX","UT","VA","VT","WA","WI","WV","WY","AS","GU","MP","PR","VI","UM","FM","MH","PW","AA","AE","AP"]},{"maxlength":null,"value":"$TOPIC","options_hash":["Abortion","Agriculture","Animal_Rights","Banking","Budget","Casework","Civil_Rights","Defense","Economy","Education","Energy","Environment","Foreign_Affairs","Guns_Firearms","Health_Care","Homeland_Security","Immigration","Information_Technology","Labor","National_Parks","Postal_Service","Small_Business","Social_Security","Taxes","Trade","Transportation","Veterans","Welfare","Special_Requests"]}]}}

### `/fill-out-form`

Provide a json object containing the `bio_id` of the member of congress, the `fields` to fill out, a `campaign_tag` for tracking successes, and a unique `uid` that will have to be provided if a subsequent captcha request is required.  Responds with a json object containing a status: `success` if the request succeeded, `error` if there was a problem, or `captcha_needed` if the form requires a captcha to be filled out.  If `error` there will be an additional message giving more information.  If `captcha_needed` a url will be provided which gives a relative path to the captcha image that can be provided to the end user.

Example #1, with captcha:

    $ curl -H "Content-Type: application/json" -d '{"bio_id": "A000000", "uid": "example_uid", "fields": {"$NAME_FIRST": "John", "$NAME_LAST": "Doe", "$ADDRESS_STREET": "123 Main Street", "$ADDRESS_CITY": "New York", "$ADDRESS_ZIP5": "10112", "$EMAIL": "joe@example.com", "$MESSAGE": "I have concerns about the proposal....", "$NAME_PREFIX": "Grand Moff"}}' http://localhost:9292/fill-out-form
    {"status":"captcha_needed","url":"/captchas/e410e577123c5e19a526ad3f6b.png"}

Example #2, no captcha:

    $ curl -H "Content-Type: application/json" -d '{"bio_id": "A111111", "campaign_tag": "stop_sopa", "uid": "example_uid_2", "fields": {"$NAME_FIRST": "John", "$NAME_LAST": "Doe", "$ADDRESS_STREET": "123 Main Street", "$ADDRESS_CITY": "New York", "$ADDRESS_ZIP5": "10112", "$EMAIL": "joe@example.com", "$MESSAGE": "I have concerns about the proposal....", "$NAME_PREFIX": "Grand Moff"}}' http://localhost:9292/fill-out-form
    {"status":"success"}

### `/fill-out-captcha`

For continuing filling in the remote form when a captcha is present.  Provide a json object containing the same `uid` you provided in the previous request to `/fill-out-captcha`, as well as the captcha answer in the `answer` string.  As above, responds with a javascript object containing the status `success` or `error`.

Example for #1 above:

    $ curl -H "Content-Type: application/json" -d '{"answer": "cx9bp", "uid": "example_uid"}' http://localhost:9292/fill-out-captcha
    {"status":"success"}

## Status Indications and Helpers

The application has a number of other helpful endpoints to indicate status and failures:

### `/recent-fill-image/<bio_id>`

Provide a `bio_id` as part of the GET request.  Responds with a 302 redirect to a badge indicating the status of form fills since the last time the congress member actions were udated.

### `/recent-fill-status/<bio_id>`

Provide a `bio_id` as part of the GET request.  Responds with a hash giving statistics on the number of successes, failures, and errors encountered when trying to fill in forms since the last time the congress member actions were updated.

### `/most-recent-error-or-failure/<bio_id>`

Provide a `bio_id` as part of the GET request.  Responds with the last error or failure encountered when trying to fill in the form for this congress member.  This endpoint is only valid if `DEBUG_ENDPOINTS` is set to `true` in `config/congress-forms_config.rb`.
