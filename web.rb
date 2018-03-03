require 'sinatra'
require 'mini_exiftool'
require 'fileutils'
require 'digest/md5'

set :port, ENV["PORT"] || 3000

EXCLUDE_LIST = [ 'thumbnail_image', 'data_dump' ]
NIL_VALUES = [ "", " ", "Unknown", "Unknown ()", "n/a", "null" ]
SAVE_DIR = "tmp"

def to_snake_case(camel_cased_word)
 camel_cased_word.to_s.gsub(/::/, '/').
   gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
   gsub(/([a-z\d])([A-Z])/,'\1_\2').
   tr("- ", "_ ").downcase
end

def hashFile(filename)
  Digest::MD5.hexdigest(File.read(filename)+Time.now.to_s) # Include timestamp in the hash to ensure unicity
end

def duplicateFile(filename, filedir)
  hash = hashFile(filename)
  FileUtils.mkdir_p(filedir) unless File.exists?(filedir)
  fileLocation = File.join(filedir, hash+".jpg")
  # Check number of files in the folder
  File.open(fileLocation, 'wb') do |file|
      file.write(filename.read)
  end
  return fileLocation
end


get '/' do
  'Welcome to ExifExtractor!'
end

post '/exif/read/simple' do
    result = nil
    if params.include?('file')
      tempfile = params[:file][:tempfile]
      filename = params[:file][:filename]
      begin
      	  duplicateFile(tempfile, SAVE_DIR)
          exif = getExifInfo(filename)
          result = exif.to_json
          puts result
      rescue Exception => e
          result = {:status => 500, :message => e.message, :error => true}.to_json
      end
    else
      result = {:status => 422, :message => "Missing file parameter", :error => true}.to_json
    end

    result
end

post '/exif/read/raw' do
    result = nil
    if params.include?('file')
      tempfile = params[:file][:tempfile]
      filename = params[:file][:filename]
      begin
          duplicateFile(tempfile, SAVE_DIR)
          exif = getRawExifInfo(filename)
          result = exif.to_json
      rescue Exception => e
          result = {:status => 500, :message => e.message, :error => true}.to_json
      end
    else
      result = {:status => 422, :message => "Missing file parameter", :error => true }.to_json
    end

    result
end

post '/exif/copy' do
    result = nil
    if params.include?('file_source') && params.include?('file_dest')
      tempfileSource = params[:file_source][:tempfile]
      filenameSource = params[:file_source][:filename]

      tempfileDest = params[:file_dest][:tempfile]
      filenameDest = params[:file_dest][:filename]

      begin
          hashSource = duplicateFile(tempfileSource, SAVE_DIR)
          hashDest = duplicateFile(tempfileDest, SAVE_DIR)
          copyTags(hashSource, hashDest)
          send_file hashDest, :filename => filenameDest, type: 'image/jpeg'
      rescue Exception => e
          result = {:status => 500, :message => e.message, :error => true}.to_json
      end
    else
      result = {:status => 422, :message => "Missing file parameter", :error => true}.to_json
    end

    result
end

post '/exif/delete' do
    result = nil
    if params.include?('file') && params.include?('tags')
      tempFile = params[:file][:tempfile]
      fileName = params[:file][:filename]

      tagsToDelete = params[:tags].split(',')

      begin
        hash = duplicateFile(tempFile, SAVE_DIR)
        removeExifTags(hash, tagsToDelete)
        send_file hash, :filename => fileName, type: 'image/jpeg'
      rescue Exception => e
          result = {:status => 500, :message => e.message, :error => true}.to_json
      end
    else
      result = {:status => 422, :message => "Missing parameter", :error => true}.to_json
    end

    result
end

def convertNilValues(hash)
  hash.each do |k, v|
    if v.is_a?(String)
      if NIL_VALUES.include? v
        hash[k]=nil
      end
    elsif v.is_a?(Hash)
      convertNilValues v
    end
  end
  return hash
end


def hashToSnakeCase(hash)
  newHash=Hash.new
  hash.each { |k,v| newHash[to_snake_case(k)]=v }
  return newHash
end

def parseExif(data)
  hash = hashToSnakeCase(data.to_hash)
  exif = hash.delete_if { |k,v| EXCLUDE_LIST.include? k }
  return exif
end

def removeTags(data)
  tags = hashToSnakeCase(tags)
  hash = hashToSnakeCase(data.to_hash)
  hash = hash.delete_if { |k,v| EXCLUDE_LIST.include? k or tags.include? k }
  return hash
end

def getRawExifInfo(filename)
  data = MiniExiftool.new(filename)
  exif = convertNilValues(parseExif(data))
  return exif.sort.to_h
end

def copyTags(filenameSource, filenameDest)
  tagsSourceFile = MiniExiftool.new(filenameSource)
  tagsDestFile = MiniExiftool.new(filenameDest)
  tagsDestFile.initialize_from_hash(Hash.new)
  tagsDestFile.copy_tags_from(filenameSource, tagsSourceFile.all_tags)
  tagsDestFile.save
  puts tagsDestFile.to_hash
end

def removeExifTags(filename, tags)
  exifTags = MiniExiftool.new(filename)
  tempHash = removeTags(exifTags, tags)
  newTags = MiniExiftool.new nil
  newTags.initialize_from_hash(tempHash)
  newTags.tags.each do |tag|
    #exifTags[tag]=newTags[tag]
    puts "#{tag}: #{newTags[tag]}"
  end
  #puts exifTags.to_hash
  exifTags.save
end

def getExifInfo(filename)
  data = MiniExiftool.new(filename)
  exif=Hash.new
  file=Hash.new
  camera=Hash.new
  gps=Hash.new
  technical=Hash.new
  picture=Hash.new

# ---- File ----
# FileName
# FileSize
# FileModifyDate
# FileAccessDate
# Image Height
# Image Width
# ModifyDate
  file[:file_name]=filename.to_s
  file[:file_size]=data.file_size.to_s
  file[:file_access_date]=data.file_access_date.to_s
  file[:file_modify_date]=data.file_modify_date.to_s
  file[:image_height]=data.image_height.to_s
  file[:image_width]=data.image_width.to_s
  exif[:file]=file

  # ---- Camera ----
  # Compression
  # DateTime Original
  # Make
  # Megapixels                      
  # Model
  # Orientation
  # Software
  camera[:make]=data.make.to_s
  camera[:model]=data.model.to_s
  camera[:compression]=data.compression.to_s
  camera[:date_time_original]=data.date_time_original.to_s
  camera[:megapixels]=data.megapixels.to_s
  camera[:orientation]=data.orientation.to_s
  camera[:software]=data.software.to_s
  exif[:camera]=camera

# ---- Techincal ----
# Aperture
# Brightness
# Contrast
# ExposureTime
# FilterEffect
# Flash
# FlashSetting
# FNumber
# FocalLength
# ISO
# LightSource
# LightValue
# MaxApertureValue
# Saturation
# ShutterSpeed
# WhiteBalance

  technical[:aperture]=data.aperture.to_s
  technical[:brightness]=data.brightness.to_s
  technical[:contrast]=data.contrast.to_s
  technical[:exposure_time]=data.exposure_time.to_s
  technical[:filter_effect]=data.filter_effect.to_s
  technical[:flash]=data.flash.to_s
  technical[:flash_setting]=data.flash_setting.to_s.to_s
  technical[:f_number]=data.f_number.to_s
  technical[:focal_length]=data.focal_length.to_s
  technical[:iso]=data.iso.to_s
  technical[:light_source]=data.light_source.to_s
  technical[:light_value]=data.light_value.to_s
  technical[:max_aperture_value]=data.max_aperture_value.to_s
  technical[:saturation]=data.saturation.to_s
  technical[:shutter_speed]=data.shutter_speed.to_s
  technical[:white_balance]=data.white_balance.to_s
  exif[:technical]=technical

# ---- GPS ----
# GPS Date/Time                                   
# GPS Latitude                    
# GPS Latitude Ref                
# GPS Longitude                   
# GPS Longitude Ref 

  gps[:gps_date_time]=data.gps_date_time.to_s
  gps[:gps_latitude]=data.gps_latitude.to_s
  gps[:gps_latitude_ref]=data.gps_latitude_ref.to_s
  gps[:gps_longitude]=data.gps_longitude.to_s
  gps[:gps_longitude_ref]=data.gps_longitude_ref.to_s
  exif[:gps]=gps

  return convertNilValues(exif)
end
