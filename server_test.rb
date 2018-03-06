ENV['RACK_ENV'] = 'test'
 
require 'minitest/autorun'
require 'rack/test'
require_relative 'server'
 
class MainAppTest < Minitest::Test
  include Rack::Test::Methods 
 
  def app
    Sinatra::Application
  end
 
  def test_upload
    get '/exif/upload'
    assert last_response.status==200
  end

end