ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'
require "rspec/mocks/standalone"
require 'digest/md5'
require 'minitest/hooks/test'

require_relative 'server'

ENV["SAVE_DIR"] = "test"
ENV['HASH'] = "48542c76b4cfd66aad29d8f27eb05106"
ENV['HASH_DELETE'] = "25ea2279c22867e08b0037e79509f592"

class ExifApiTest < Minitest::Test
  include Rack::Test::Methods , Minitest::Hooks

  def app
    ExifApi
  end

  def after_all
    puts "Removing temp files..."
    Dir.glob(ENV["SAVE_DIR"]+"/#{ENV['HASH_DELETE']}.JPG").each { |file| File.delete(file)}
  end
 
  def test_upload
  	filepath = File.join(ENV["SAVE_DIR"], 'test.JPG')
  	fixedTime = Time.parse("2011-1-2 11:00:00")
  	expectedJSON = { 
        :file_hash  => ENV['HASH']
	}.to_json
	Time.stub :now, fixedTime do
    	post '/exif/upload', "file" => Rack::Test::UploadedFile.new(filepath, "image/jpeg")
	    assert last_response.body == expectedJSON
	    assert last_response.status == 200
  	end
  end

  def test_read_simple
    get "/exif/read/simple/#{ENV['HASH']}"
    assert last_response.body.include?("file")
    assert last_response.status==200
  end

  def test_read_simple_not_found
    get "/exif/read/simple/404"
    expectedJSON = {:status => 404, :error => true, :message => "File not found"}.to_json
    assert last_response.body ==  expectedJSON
    assert last_response.status==404
  end

  def test_read_all
    get "/exif/read/all/#{ENV['HASH']}"
    assert last_response.body.include?("file")
    assert last_response.status==200
  end

  def test_read_all_not_found
    get "/exif/read/all/404"
    expectedJSON = {:status => 404, :error => true, :message => "File not found"}.to_json
    assert last_response.body ==  expectedJSON
    assert last_response.status==404
  end

   def test_read_raw
    get "/exif/read/raw/#{ENV['HASH']}"
    assert last_response.body.include?("file")
    assert last_response.status==200
  end

  def test_read_raw_not_found
    get "/exif/read/raw/404"
    expectedJSON = {:status => 404, :error => true, :message => "File not found"}.to_json
    assert last_response.body ==  expectedJSON
    assert last_response.status==404
  end

  def test_delete
   	expectedJSON = {
   		"Content-Type"=>"image/jpeg", 
   		"Content-Disposition"=>"attachment; filename=\"48542c76b4cfd66aad29d8f27eb05106.JPG\"",
   		"Last-Modified"=>"Thu, 08 Mar 2018 20:16:23 GMT",
   		"Content-Length"=>"139143",
   		"X-Content-Type-Options"=>"nosniff"
   		}.to_json
   	fixedTime = Time.parse("2011-1-2 11:01:00")
   	Time.stub :now, fixedTime do
	    get "/exif/delete/#{ENV['HASH']}"
	    assert last_response.include?("Content-Type")
	    assert last_response.include?("Content-Disposition")
	  	assert last_response.content_type=="image/jpeg"
	   end
  end

end