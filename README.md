# Cur

Mongrel dog?  Contemptible man?  No, its Containers Using Rake!  Though it may be a bit of a mongrel lib primarily authored by a contemptible man.

Cur extends the Rake task DSL to provide support for running Docker containers as part of a tasks execution with an eye towards multi-container
build pipelines.  It aims to make it easier to build non-trivial build systems through convention-over-configuraiton, intelligent defaults and
boilerplate elimination.  Its primary benefits over tools like docker-compose is that evaluable code trumps static configuration (YAML) when
your needs get more complex.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cur'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cur

## Usage
TBW

## Details
TBW

## Build Servers/Continuous Integration
#### Travis
In your ```.travis.yml``` file, declare your dependency on docker:

```
services:
  - docker
```

Also in ```.travis.yml```, declare the script to run the integration test task:

```
script: bundle exec rake test:integration
```

#### Jenkins
First, you must ensure the host where jobs are being performed has the following dependencies installed:

* docker
* ruby
* rake and cur gems

Exactly how this is performed for a jenkins build host is outside of the scope of this document.  Consult the jenkins documentation for details.  You can verify docker is correctly installed with:

```
> docker info
... lots of output
```

You can verify ruby is set up correctly with the following command:

```
> ruby -e "require 'rake'; require 'cur'; puts 'all good!'"
all good!
```

Define a job for your build through the Jenkins UI.  Within it, set up a build step to move into the worksapce and run the integration test task.

```
cd $WORKSPACE
bundle exec rake test:integration
```

Your build step will look something like this:

![jenkins](http://i.imgur.com/7VuIli9.png)

Since the present working directory is mounted into the containers, and any and the present workding directory is the $WORKSPACE, all build artifacts are available to jenkins as they might normally be if the build was executed outside of containers.  This allows for jenkins plugins that rely on artifacts in the workspace (jacoco, code coverage, etc...) to function properly.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/cur.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

