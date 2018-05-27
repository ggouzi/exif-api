ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'
require "rspec/mocks/standalone"
require 'digest/md5'
require 'minitest/hooks/test'

require_relative 'server'

ENV["SAVE_DIR"] = "test"
ENV['TEST_FILE'] = "test"
ENV['HASH'] = "48542c76b4cfd66aad29d8f27eb05106"

class ExifApiTest < Minitest::Test
  include Rack::Test::Methods , Minitest::Hooks

  def app
    ExifApi
  end

  def after_all
    puts "Removing temp files..."
     Dir::foreach(ENV['SAVE_DIR']) do |filename|
      next if(filename==ENV['TEST_FILE']+".JPG")
      filepath=File.join(ENV["SAVE_DIR"],filename)
      if File::file?(filepath)
        FileUtils.rm (filepath)
      end
    end
  end
 
  def test_upload
  	filepath = File.join(ENV["SAVE_DIR"], ENV['TEST_FILE']+".JPG")
  	fixedTime = Time.parse("2011-1-2 11:00:00")
  	expectedJSON = { 
        :file_hash  => ENV['HASH']
	}.to_json
	Time.stub :now, fixedTime do
    	post '/upload', "file" => Rack::Test::UploadedFile.new(filepath, "image/jpeg")
	    assert last_response.body == expectedJSON
	    assert last_response.status == 200
  	end
  end

  def test_read_simple
    get "/read/simple/#{ENV['TEST_FILE']}"
    assert last_response.body.include?("file")
    assert last_response.status==200
  end

  def test_read_simple_not_found
    get "/read/simple/404"
    expectedJSON = {:status => 404, :error => true, :message => "File not found"}.to_json
    assert last_response.body ==  expectedJSON
    assert last_response.status==404
  end

  def test_read_full
    get "/read/full/#{ENV['TEST_FILE']}"
    assert last_response.body.include?("file")
    assert last_response.status==200
  end

  def test_read_full_not_found
    get "/read/full/404"
    expectedJSON = {:status => 404, :error => true, :message => "File not found"}.to_json
    assert last_response.body ==  expectedJSON
    assert last_response.status==404
  end

  def test_read_raw
    get "/read/raw/#{ENV['TEST_FILE']}"
    assert last_response.body.include?("file")
    assert last_response.status==200
  end

  def test_read_raw_not_found
    get "/read/raw/404"
    expectedJSON = {:status => 404, :error => true, :message => "File not found"}.to_json
    assert last_response.body ==  expectedJSON
    assert last_response.status==404
  end

  def test_delete
   	fixedTime = Time.parse("2011-1-2 11:01:00")
   	Time.stub :now, fixedTime do
	    get "/delete/#{ENV['TEST_FILE']}"
	    assert last_response.include?("Content-Type")
	    assert last_response.include?("Content-Disposition")
	  	assert last_response.content_type=="image/jpeg"
	   end
  end

end