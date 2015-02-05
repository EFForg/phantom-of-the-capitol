# CongressForms
A RESTful API for retrieving the required fields for and filling out the contact forms of members of the US Congress.
This project relies on [Contact Congress](https://github.com/unitedstates/contact-congress) as the data source for congress member forms.

[![Build Status](https://travis-ci.org/EFForg/congress-forms.png)](http://travis-ci.org/EFForg/congress-forms)

## Installation and Setup

### The easy way (for developers)

#### Requirements

[VirtualBox](https://www.virtualbox.org/wiki/Downloads) (with Extension Pack) and [Vagrant](https://www.vagrantup.com/downloads.html). Using Debian or Ubuntu? Here's a one liner to save you time.

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

 - `apt-get install imagemagick libmysql++-dev libpq-dev git libqt4-dev xvfb`
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

 - `bundle exec rake congress-forms:update_git[contact_congress_directory]`

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

The application has three endpoints which are commonly used by application front-ends:

### `POST /retrieve-form-elements`
 
> Provide a json object containing an array of [`bio_ids`](http://bioguide.congress.gov/) in string format.  Responds with a json object containing the necessary fields for the congressional contact forms.
> 
> Example:
> 
>     $ curl -H "Content-Type: application/json" -d '{"bio_ids": ["C000880", "A000360"]}' http://localhost:9292/retrieve-form-elements
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
>     $ curl -H "Content-Type: application/json" -d '{"bio_id": "A000000", "fields": {"$NAME_FIRST": "John", "$NAME_LAST": "Doe", "$ADDRESS_STREET": "123 Main Street", "$ADDRESS_CITY": "New York", "$ADDRESS_ZIP5": "10112", "$EMAIL": "joe@example.com", "$MESSAGE": "I have concerns about the proposal....", "$NAME_PREFIX": "Grand Moff"}}' http://localhost:9292/fill-out-form
>     {"status":"captcha_needed","url":"/captchas/e410e577123c5e19a526ad3f6b.png"}
> 
> Example #2, no captcha:
> 
>     $ curl -H "Content-Type: application/json" -d '{"bio_id": "A111111", "campaign_tag": "stop_sopa", "fields": {"$NAME_FIRST": "John", "$NAME_LAST": "Doe", "$ADDRESS_STREET": "123 Main Street", "$ADDRESS_CITY": "New York", "$ADDRESS_ZIP5": "10112", "$EMAIL": "joe@example.com", "$MESSAGE": "I have concerns about the proposal....", "$NAME_PREFIX": "Grand Moff"}}' http://localhost:9292/fill-out-form
>     {"status":"success"}

### `POST /fill-out-captcha`

> For continuing filling in the remote form when a captcha is present.  Provide a json object containing the same `uid` you provided in the previous request to `/fill-out-captcha`, as well as the captcha answer in the `answer` string.  As above, responds with a javascript object containing the status `success` or `error`.
> 
> Example for #1 above:
> 
>     $ curl -H "Content-Type: application/json" -d '{"answer": "cx9bp", "uid": "example_uid"}' http://localhost:9292/fill-out-captcha
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
>     $ curl 'http://localhost:9292/successful-fills-by-date/A000000?debug_key=some_key'
>     {"2014-06-27 00:00:00 -0700":3,"2014-06-28 00:00:00 -0700":0,"2014-06-29 00:00:00 -0700":2,"2014-06-30 00:00:00 -0700":2,"2014-07-01 00:00:00 -0700":4}
> 
> Example with `bio_id` and `campaign_tag`:
> 
>     $ curl 'http://localhost:9292/successful-fills-by-date/A000000?campaign_tag=some_tag&debug_key=some_key'
>     {"2014-06-27 00:00:00 -0700":1,"2014-06-28 00:00:00 -0700":0,"2014-06-29 00:00:00 -0700":1,"2014-06-30 00:00:00 -0700":2,"2014-07-01 00:00:00 -0700":0}
> 
> Example without `bio_id` or `campaign_tag`:
>
>     $ curl 'http://localhost:9292/successful-fills-by-date/?debug_key=some_key'
>     {"2014-06-27 00:00:00 -0700":360,"2014-06-28 00:00:00 -0700":118,"2014-06-29 00:00:00 -0700":232,"2014-06-30 00:00:00 -0700":89,"2014-07-01 00:00:00 -0700":842}
> 
> Example without `bio_id`, with `campaign_tag`:
>
>     $ curl 'http://localhost:9292/successful-fills-by-date/?campaign_tag=some_tag&debug_key=some_key'
>     {"2014-06-27 00:00:00 -0700":56,"2014-06-28 00:00:00 -0700":27,"2014-06-29 00:00:00 -0700":48,"2014-06-30 00:00:00 -0700":12,"2014-07-01 00:00:00 -0700":98}

### `GET /successful-fills-by-member/`

> Responds with a count of the number of successful fills, grouped by member of congress bioguide id.  You can also optionally provide a `campaign_tag` parameter to retrieve results filtered by `campaign_tag`.
>
> Example without `campaign_tag`:
>
>     $ curl 'http://localhost:9292/successful-fills-by-member/?debug_key=some_key'
>     {"A000000":312,"B000000":187,"C000000":103,"D000000":782,"E000000":41}
>
> Example with `campaign_tag`:
>
>     $ curl 'http://localhost:9292/successful-fills-by-member/?campaign_tag=some_tag&debug_key=some_key'
>     {"A000000":28,"B000000":20,"C000000":9,"D000000":70,"E000000":5}

## Debugging Congress-Forms

The [Congress Forms Debugger](https://github.com/efforg/congress-forms-test/) is a useful tool for debugging congress-forms.  To run it locally, in `config/congress-forms_config.rb` first make sure to set `DEBUG_KEY` to a shared secret and `CORS_ALLOWED_DOMAINS` to add `localhost:8000` if the debugger is going to be run on port `8000`.  Then:

    $ git clone https://github.com/EFForg/congress-forms-test
    $ cd congress-forms-test
    $ vim js/config.js # edit this file so that `CONTACT_CONGRESS_SERVER` points to your own `congress-forms` API root.
    $ python -m SimpleHTTPServer # or configure apache for this endpoint

Now, you should be able to point your browser to `http://localhost:8000/congress-forms-test/?debug_key=DEBUG_KEY` (replacing, of course, `DEBUG_KEY`) and see a list of members of congress with a column for their `Recent Success Rate`.  From here, you can click on the bioguide identifier for a member of congress and be brought to a page where you can then:

 1. send a test form fill
 2. see details about their recent form fills, including (if it was an attemt resulting in `failure` or `error`):
  - the `Delayed::Job` id #
  - a debugging message
  - a screenshot at the point of failure
 3. view the actions for this member of congress, as the database sees them (e.g. if you want to make sure the actions match the latest YAML from `contact-congress`)

## Re-running jobs that resulted in `error` or `failure`

Any jobs that result in an `error` or `failure` are added to the [Delayed::Job](https://github.com/collectiveidea/delayed_job) job queue, unless the `SKIP_DELAY` environment variable is set.  This job queue shold be checked periodically and the jobs themselves debugged and re-run to ensure delivery.  A number of convenience rake tasks have been provided for this purpose.

### `rake congress-forms:delayed_job:jobs_per_member`

Dispays the number of jobs per member of congress in descending order, indicating which members have captchas on their forms and giving a summation at the end.

### `rake congress-forms:delayed_job:perform_fills[regex,job_id,overrides]`

Perform the form fills in the queue, optionally providing:

  - `regex` which will only perform the fills for members with matching bioguide identifiers
  - `job_id` which will only perform the fill for a given Delayed::Job id
  - `overrides`, a Ruby hash which will override the field values when the fill is performed

Examples:

    $ rake congress-forms:delayed_job:perform_fills
    $ rake congress-forms:delayed_job:perform_fills[A000000]
    $ rake congress-forms:delayed_job:perform_fills[A000000,,'{"$PHONE" => "555-555-5555"}']
    $ rake congress-forms:delayed_job:perform_fills[,12345,'{"$EMAIL" => "john.doe@example.com"}']

### `rake congress-forms:override_field[regex,job_id,overrides]`

Override values for jobs in the queue, optionally providing:

  - `regex` which will only override the values for members with matching bioguide identifiers
  - `job_id` which will only override the value for a given Delayed::Job id
  - `overrides`, a Ruby hash which will override the field values for the criteria specified

Examples:

    $ rake congress-forms:delayed_job:override_field
    $ rake congress-forms:delayed_job:override_field[A000000]
    $ rake congress-forms:delayed_job:override_field[A000000,,'{"$PHONE" => "555-555-5555"}']
    $ rake congress-forms:delayed_job:override_field[,12345,'{"$EMAIL" => "john.doe@example.com"}']

### `rake congress-forms:delayed_job:zip4_retry[regex]`

Pick out the jobs that have no `$ADDRESS_ZIP4` defined, figure out the zip+4 based on the address and 5-digit zip in the job (requires an account with [SmartyStreets](http://smartystreets.com/) with credentials in `config/congress-forms_config.rb`), and try the job again.  Optionally provide:

  - `regex` which will only perform the fills for members with matching bioguide identifiers

Examples:

    $ rake congress-forms:delayed_job:zip4_retry
    $ rake congress-forms:delayed_job:zip4_retry[A000000]

### Padrino Console

If you prefer to dive deep, you can fire up the padrino console with `padrino c` and debug jobs:

    > Delayed::Job.where(queue: "error_or_failure").count # count of all jobs
     => 78
    > job = Delayed::Job.where(queue: "error_or_failure").first # get the first job
     => #<Delayed::Backend::ActiveRecord::Job id: 318, priority: 0, attempts: 1, handler: "--- !ruby/object:Delayed::PerformableMethod\nobject:...", last_error: "Unable to find css \"p\" with text /Thank you!/\n[\"/ho...", run_at: "2014-07-03 12:14:10", locked_at: nil, failed_at: nil, locked_by: nil, queue: "error_or_failure", created_at: "2014-07-03 12:14:10", updated_at: "2014-08-26 18:50:27"> 
    > handler = YAML.load job.handler # get the "handler" which contains the object to be acted upon and the arguments
     => #<Delayed::PerformableMethod:0x0000000544ae30 @object=#<CongressMember id: 60, bioguide_id: "F000457", success_criteria: "---\nheaders:\n  status: 200\nbody:\n  contains: Your m...", created_at: "2014-04-30 19:08:05", updated_at: "2014-07-03 18:54:34">, @method_name=:fill_out_form, @args=[{"$NAME_FIRST"=>"John", "$NAME_LAST"=>"Doe", "$ADDRESS_STREET"=>"123 Fake Street", "$ADDRESS_CITY"=>"Hennepin", "$ADDRESS_ZIP5"=>"55369", "$EMAIL"=>"johndoe@example.com", "subscribe"=>"1", "$SUBJECT"=>"Example subject", "$MESSAGE"=>"Example Message", "$NAME_PREFIX"=>"Mr.", "$ADDRESS_STATE_POSTAL_ABBREV"=>"MN", "$TOPIC"=>"Example Topic", "$PHONE"=>"555-555-5555", "$ADDRESS_ZIP4"=>"1234"}, nil]>
    handler.args[0]['$PHONE'] = '123-456-7890' # set the phone number

Then, when you're ready to retry the fill:

    handler.perform # try filling out the form
    handler.object.fill_out_form(handler.args[0]) do |c|
      puts c
      STDIN.gets.strip
    end # fills out a form with a captcha
