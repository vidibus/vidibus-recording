# Vidibus::Recording

Allows recording of RTMP video streams. Uses RTMPdump. Requires at least Ruby 1.9.

This gem is part of [Vidibus](http://vidibus.org), an open source toolset for building distributed (video) applications.


## Installation

Add `gem 'vidibus-recording'` to the Gemfile of your application. Then call `bundle install` on your console.


## Usage

### Available methods

To control a recording, you may use these methods:

```ruby
recording.start   # starts recording
recording.stop    # stops recording
recording.resume  # continues if recording has been started but is not running
recording.restart # erases recorded data and restarts recording
```


### Custom class names

This gem will set up a model `Recording` if Rails is around. If you want to use the recording logic inside of a custom model, you just have to include the module `Vidibus::Recording::Mongoid`:

```ruby
class MyCustomRecording
  include Mongoid::Document
  include Vidibus::Recording::Mongoid
end
```


### Monitoring

If the worker process does not receive data, it will halt the recording. To monitor and restart a recording perform `Vidibus::Recording.monitor`. Beware, this method is blocking, so better spawn the daemon.


#### Monitoring daemon

To run the monitor as daemon, this gem provides a shell script. Install it with

```
rails g vidibus:recording
```

The daemon requires that `gem 'daemons'` is installed. To spawn him, enter

```
script/recording start
```

#### Possible caveat

To monitor your custom recording classes, `Vidibus::Recording.monitor` requires that all classes that include `Vidibus::Recording::Mongoid` have been loaded.

Because Rails is autoloading almost everything in development, this requirement is not met without the help of a little hack: To trigger autoloading, the monitor collects all aforementioned class names from the `app` directory and constantizes them.

**So here's the caveat:** If you define custom recording models outside of the `app` directory, you'll have to let the listener know. An initializer is perfect for that:

```ruby
# Collect all recording models in lib, too
Vidibus::Recording.autoload_paths << '/lib/**/*.rb'
```


## Deployment

A Capistrano configuration is included. Require it in your Capistrano `config.rb`.

```ruby
require 'vidibus/recording/capistrano'
```

That will add a bunch of callback hooks.

```ruby
after 'deploy:stop',    'vidibus:recording:stop'
after 'deploy:start',   'vidibus:recording:start'
after 'deploy:restart', 'vidibus:recording:restart'
```

If you need more control over the callbacks, you may load just the recipes without the hooks.

```ruby
require 'vidibus/recording/capistrano/recipes'
```


## Testing

To test this gem, call `bundle install` and `bundle exec rspec spec` on your console.


## Copyright

&copy; 2011-2013 André Pankratz. See LICENSE for details.
