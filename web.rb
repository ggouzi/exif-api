require 'sinatra'
require 'mini_exiftool'
require 'fileutils'
require 'digest/md5'

set :port, ENV["PORT"] || 3000

EXCLUDE_LIST = [ 'ThumbnailImage', 'DataDump' ]

# Based on https://stackoverflow.com/questions/23521230/flattening-nested-hash-to-a-single-hash-with-ruby-rails
def flatten_hash(hash)
  hash.each_with_object({}) do |(k, v), h|
    if v.is_a? Hash
      flatten_hash(v).map do |h_k, h_v|
        h["#{h_k}".to_sym] = h_v
      end
    else 
      h[k] = v
    end
   end
end

def to_snake_case(camel_cased_word)
 camel_cased_word.to_s.gsub(/::/, '/').
   gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
   gsub(/([a-z\d])([A-Z])/,'\1_\2').
   tr("-", "_").downcase
end

def hashFile(filename)
  Digest::MD5.hexdigest(File.read(filename)+Time.now.to_s) # Include timestamp in the hash to ensure unicity
end

def replaceUnsetValues(hash)
  h=hash
  hash.each do |k,v|
    if v.is_a? Hash
      h[k]=replaceUnsetValues(v).compact!
    elsif (v.nil? || v.to_s.strip.empty? || v.to_s.downcase=="unknown")
        h[k]=nil
    end
  end
  return h
end

def cleanExifData(hash)
  replaceUnsetValues(hash).compact!
end

def duplicateFileile(filename, filedir)
  hash = hashFile(filename)
  FileUtils.mkdir_p(filedir) unless File.exists?(filedir)
  fileLocation = File.join(filedir, hash)
  # Check number of files in the folder
  File.open(fileLocation, 'wb') do |file|
      file.write(filename.read)
  end
end


get '/' do
  'Welcome to ExifExtractor!'
end

post '/exif/read/simple' do
    result = nil
    if params.include?('file')
      tempfile = params[:file][:tempfile]
      filename = params[:file][:filename]
      save_dir = "tmp"
      begin
      	  duplicateFileile(tempfile, save_dir)
          exif = getExifInfo(filename)
          result = exif.to_json
      rescue Exception => e
          result = {:status => 500, :error_message => e.message}.to_json
      end
    else
      result = {:status => 422, :error_message => "Missing file parameter"}.to_json
    end

    result
end

post '/exif/read/raw' do
    result = nil
    if params.include?('file')
      tempfile = params[:file][:tempfile]
      filename = params[:file][:filename]
      save_dir = "tmp"
      begin
          duplicateFileile(tempfile, save_dir)
          exif = getRawExifInfo(filename)
          result = exif.to_json
      rescue Exception => e
          result = {:status => 500, :error_message => e.message}.to_json
      end
    else
      result = {:status => 422, :error_message => "Missing file parameter"}.to_json
    end

    result
end

def getRawExifInfo(filename)
  data = MiniExiftool.new(filename)
  exif=data.to_hash.delete_if { |k,v| EXCLUDE_LIST.include? k }
  exif.each { |k,v| k=to_snake_case(k) }
  return exif.sort.to_h
end

def getExifInfo(filename)
  data = MiniExiftool.new(filename)
  exif=Hash.new()
  gps=Hash.new()
  technical=Hash.new()
  picture=Hash.new()

  picture[:time_zone_offset]=data.time_zone_offset
  picture[:date_time_original]=data.date_time_original
  picture[:image_length]=data.image_length
  picture[:image_width]=data.image_width
  picture[:orientation]=data.orientation
  exif[:picture]=picture

  technical[:aperture_value]=data.aperture_value
  technical[:brightness_value]=data.brightness_value
  technical[:battery_level]=data.battery_level
  technical[:compressed_bits_per_pixel]=data.compressed_bits_per_pixel
  technical[:contrast]=data.contrast
  technical[:exposure_time]=data.exposure_time
  technical[:flash]=data.flash
  technical[:focal_length]=data.focal_length
  technical[:gamma]=data.gamma
  technical[:light_source]=data.light_source
  technical[:resolution_unit]=data.resolution_unit
  technical[:saturation]=data.saturation
  technical[:scene_type]=data.scene_type
  technical[:sensing_method]=data.sensing_method
  technical[:shutter_speed_value]=data.shutter_speed_value
  technical[:software]=data.software
  technical[:white_balance]=data.white_balance
  technical[:x_resolution]=data.x_resolution
  technical[:y_resolution]=data.y_resolution
  exif[:technical]=technical

  gps[:latitude]=data.gps_latitude
  gps[:longitude]=data.gps_longitude
  gps[:latitude_ref]=data.gps_latitude_ref
  gps[:longitude_ref]=data.gps_longitude_ref
  exif[:gps]=gps

  return exif.sort.to_h
end
