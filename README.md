# CongressForms
A RESTful API for retrieving the required fields for and filling out the contact forms of members of the US Congress.
This project relies on [Contact Congress](https://github.com/unitedstates/contact-congress) as the data source for congress member forms.

[![Build Status](https://travis-ci.org/Hainish/congress-forms.png)](http://travis-ci.org/Hainish/congress-forms)

## Requirements

 - apt-get install xvfb imagemagick

## Installation

 - apt-get install ruby

or [install ruby with rvm](http://rvm.io).

 - gem install bundler
 - bundle install

Create the database, then

 - cp config/database-example.rb config/database.rb
 - vim config/database.rb # fill in db info
 - bundle exec rake ar:create ar:schema:load

## Populating the database

Grab a copy of contact-congress and store it somewhere:

 - git clone https://github.com/unitedstates/contact-congress

Then cd back over to congress-forms and run

 - bundle exec rake congress-forms:map_forms[contact_congress_yaml_directory]

replacing contact_congress_yaml_directory with the directory path.

## Running

Just run `config.ru`
