# EXIF API

### Purpose
This API provides ways to retrieve/delete/copy EXIF metadata from pictures
[API Documentation here](https://ggouzi.github.io/exif/index.html)

### Tech

EXIF API is based on open source projects:

* [Sinatra](https://github.com/sinatra/sinatra) - Opensource Ruby framework to create routes-based web applications
* [ExifTool](https://www.sno.phy.queensu.ca/~phil/exiftool/) - Opensource CLI application for editing/reading EXIF metadata

### Dependencies
* [Ruby ExifTool wrapper](https://github.com/janfri/mini_exiftool)

[See Gemfile](https://github.com/ggouzi/exif-api/blob/master/Gemfile)
### Installation

Install the dependencies:
```ruby
$ bundle install
```

Execute unit tests:
```ruby
$ bundle exec rake test
```

Launch the server:
```ruby
$ bundle exec rackup
```

### Todos

 - Write MORE Unit Tests
 - Add support for other formats (e.g: PDF)
 - Add route to edit metadata

### License
----
The MIT License (MIT)
