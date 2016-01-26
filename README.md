# Phantom of the Capitol
### Phantom DC for Short
A RESTful API for retrieving the required fields for and filling out the contact
forms of members of the US Congress.

Phantom DC has three major functions:

* Looking up form fields provided by all members of congress
* Using PhantomJS to proxy fill-in a congress member's form such that they need
not navigate directly to the congress member's web page
* It can return any captcha images and forward the user submitted solution to
the .gov website

This project relies on:

* [Contact Congress](https://github.com/unitedstates/contact-congress) as the
data source for congress member forms.
* [SmartyStreets](https://smartystreets.com/) for locating a user's
representative based on their address.  

[![Build Status](https://travis-ci.org/EFForg/phantom-of-the-capitol.png)]
(http://travis-ci.org/EFForg/phantom-of-the-capitol)





# How to Use This API

This API is deployed for public consumption at [https://congressforms.eff.org/](https://congressforms.eff.org/).  Navigate there to see notes on consumption.    


# How to Contribute to This Project


## Dev/ Production Setup with Docker (Recommended)

Docker makes it easy to set up Phantom DC for development, production, and testing.

Here's an example which will get you a quick production instance:

    $ docker run -it --name=phantom-dc-db \
        -v /var/lib/mysql \
        -e MYSQL_ROOT_PASSWORD=changeme \
        -e MYSQL_APP_PASSWORD=changeme \
        hainish/phantom-of-the-capitol-db

...and in another terminal...

    $ docker run -it --rm --name=phantom-dc \
        --link=phantom-dc-db:db \
        -p 3001:3001 \
        --volumes-from=phantom-dc-db \
        -e CORS_ALLOWED_DOMAINS='http://example.com' \
        -e LOAD_CONGRESS=true \
        -e DEBUG_KEY=changeme \
        hainish/phantom-of-the-capitol

Take a look at `config/phantom-dc_config.rb.example` to get an idea of what configuration options you can pass on to the `phantom-dc` docker instance with the `-e` flag.  In most instances, you'll want to change the AWS config options.

To run in development mode, pass in `-e RACK_ENV=development`.  If you're actively developing, you'll probably also want to share your host git path with the container by passing in `-v $(pwd):/home/phantomdc/phantom-of-the-capitol`.

To run the tests, run the `phantom-dc-db` instance as above, then run:

    $ docker run -it --rm --name=phantom-dc
        --link=phantom-dc-db:db \
        --volumes-from=phantom-dc-db \
        -e RACK_ENV=test \
        hainish/phantom-of-the-capitol \
        bash -l -c 'rspec spec'



## Development Environment Installation and Setup with Vagrant

#### Requirements

* [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (with Extension Pack) and [Vagrant](https://www.vagrantup.com/downloads.html).

Using Debian or Ubuntu?  Here's a one liner to save you time.

    $  apt-get install vagrant virtualbox

* An [AWS](https://aws.amazon.com) account for storing captchas and debug screen shots.

* SmartyStreets Account
An API key for using `SmartyStreets` allows rake tasks to run.

#### Installation

##### On Host

    $  # First, using github.com, fork this repo so you can clone directly \
       # from your own repo \
       git clone git@github.com:<YOUR_ACCOUNT>/phantom-of-the-capitol.git \
       cd phantom-of-the-capitol \

       vagrant up \

       # Edit config (at minimum change DEBUG_KEY and AWS credentials) \
       cp config/phantom-dc_config.rb.example config/phantom-dc_config.rb \
       vi config/phantom-dc_config.rb


##### Within Vagrant VM

    $  vagrant ssh

    $  cd /vagrant; \
       bundle exec rake ar:create; \
       bundle exec rake ar:schema:load; \
       rackup --host 0.0.0.0



## Production Environment Installation and Setup

#### Requirements
On a debian based system (we're testing against **Ubuntu**) download and install
the latest [phantomjs](http://phantomjs.org/) and then run the below apt-get
command.

    $  apt-get install imagemagick libmysql++-dev libpq-dev git libqt4-dev xvfb

[Install ruby with rvm](http://rvm.io), then

    $  gem install bundler; \
       bundle install;

Create the mysql database:

    $  cp config/database.rb.example config/database.rb; \

       # fill in db info as with any rails app \
       vi config/database.rb; \

       # configure the app datafile
       cp config/phantom-dc_config.rb.example config/phantom-dc_config.rb; \
       bundle exec rake ar:create; \
       bundle exec rake ar:schema:load

## Populating the Database

Once you have Phantom DC running, you have to add DataSources.  DataSources are
git repositories containing a subdirectory filled with yml files which tell
Phantom DC how to fill out forms.  In most cases, you want the US congress data
source, which should be added via the below command:

    $  ./phantom-dc datasource add --git-clone \
       https://github.com/unitedstates/contact-congress.git us_congress ./us_congress members/

To update the DataSource repos, run...

    $  bundle exec rake phantom-dc:update_git

Run this rake task any time you want to update the DataSource repos to the latest commit of each repository.  To add and remove DataSources, see the help dialogue for the CLI:

    $  ./phantom-dc datasource --help

# Running

Just run `rackup`

# Testing

If you haven't set up the test db, create it, using `config/database.rb`

Then you'll need to create and prepare the test database:

    $  PADRINO_ENV=test bundle exec rake ar:create; \
       PADRINO_ENV=test bundle exec rake ar:schema:load

And run

    $  bundle exec rspec spec



# Debugging Phantom of the Capitol

The [Congress Forms Debugger](https://github.com/efforg/congress-forms-test/) is a useful tool for debugging Phantom DC.  To run it locally, in `config/phantom-dc_config.rb` first make sure to set `DEBUG_KEY` to a shared secret and `CORS_ALLOWED_DOMAINS` to add `localhost:8000` if the debugger is going to be run on port `8000`.  Then:

    $ git clone https://github.com/EFForg/phantom-of-the-capitol
    $ cd congress-forms-test
    $ vim js/config.js # edit this file so that `CONTACT_CONGRESS_SERVER` points to your own `phantom-of-the-capitol` API root.
    $ python -m SimpleHTTPServer # or configure apache for this endpoint

Now, you should be able to point your browser to `http://localhost:8000/congress-forms-test/?debug_key=DEBUG_KEY` (replacing, of course, `DEBUG_KEY`) and see a list of members of congress with a column for their `Recent Success Rate`.  From here, you can click on the bioguide identifier for a member of congress and be brought to a page where you can then:

 1. send a test form fill
 2. see details about their recent form fills, including (if it was an attempt resulting in `failure` or `error`):
  - the `Delayed::Job` id #
  - a debugging message
  - a screenshot at the point of failure
 3. view the actions for this member of congress, as the database sees them (e.g. if you want to make sure the actions match the latest YAML from `contact-congress`)

## Re-Running Jobs That Resulted in `error` or `failure`

Any jobs that result in an `error` or `failure` are added to the [Delayed::Job](https://github.com/collectiveidea/delayed_job) job queue, unless the `SKIP_DELAY` environment variable is set.  This job queue should be checked periodically and the jobs themselves debugged and re-run to ensure delivery.  A number of convenience rake tasks have been provided for this purpose.

### `rake phantom-dc:delayed_job:jobs_per_member`

Dispays the number of jobs per member of congress in descending order, indicating which members have captchas on their forms and giving a summation at the end.

### `rake phantom-dc:delayed_job:perform_fills[regex,job_id,overrides]`

Perform the form fills in the queue, optionally providing:

  - `regex` which will only perform the fills for members with matching bioguide identifiers
  - `job_id` which will only perform the fill for a given Delayed::Job id
  - `overrides`, a Ruby hash which will override the field values when the fill is performed

Examples:

    $ rake phantom-dc:delayed_job:perform_fills
    $ rake phantom-dc:delayed_job:perform_fills[A000000]
    $ rake phantom-dc:delayed_job:perform_fills[A000000,,'{"$PHONE" => "555-555-5555"}']
    $ rake phantom-dc:delayed_job:perform_fills[,12345,'{"$EMAIL" => "john.doe@example.com"}']

### `rake phantom-dc:override_field[regex,job_id,overrides]`

Override values for jobs in the queue, optionally providing:

  - `regex` which will only override the values for members with matching bioguide identifiers
  - `job_id` which will only override the value for a given Delayed::Job id
  - `overrides`, a Ruby hash which will override the field values for the criteria specified

Examples:

    $ rake phantom-dc:delayed_job:override_field
    $ rake phantom-dc:delayed_job:override_field[A000000]
    $ rake phantom-dc:delayed_job:override_field[A000000,,'{"$PHONE" => "555-555-5555"}']
    $ rake phantom-dc:delayed_job:override_field[,12345,'{"$EMAIL" => "john.doe@example.com"}']

### `rake phantom-dc:delayed_job:zip4_retry[regex]`

Pick out the jobs that have no `$ADDRESS_ZIP4` defined, figure out the zip+4 based on the address and 5-digit zip in the job (requires an account with [SmartyStreets](http://smartystreets.com/) with credentials in `config/phantom-dc_config.rb`), and try the job again.  Optionally provide:

  - `regex` which will only perform the fills for members with matching bioguide identifiers

Examples:

    $ rake phantom-dc:delayed_job:zip4_retry
    $ rake phantom-dc:delayed_job:zip4_retry[A000000]

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
