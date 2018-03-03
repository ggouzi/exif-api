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
          exif = getExifInfo(filename, false)
          result = exif.to_json
      rescue Exception => e
          result = {:status => 500, :message => e.message, :error => true}.to_json
      end
    else
      result = {:status => 422, :message => "Missing file parameter", :error => true}.to_json
    end
    result
end

post '/exif/read/all' do
    result = nil
    if params.include?('file')
      tempfile = params[:file][:tempfile]
      filename = params[:file][:filename]
      begin
          duplicateFile(tempfile, SAVE_DIR)
          exif = getExifInfo(filename, true)
          result = exif.to_json
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

def getExifInfo(filename, all)
  data = MiniExiftool.new(filename)
  exif=Hash.new
  file=Hash.new
  camera=Hash.new
  gps=Hash.new
  technical=Hash.new
  picture=Hash.new


  #puts data.to_hash.to_json


  # ---- File ----
  # FileName
  # FileSize
  # FileModifyDate
  # FileAccessDate
  # Image Height
  # Image Width
  # ModifyDate
  file[:file_name]=filename
  file[:file_size]=data.file_size.to_s
  file[:file_access_date]=DateTime.strptime(data.file_access_date.to_s, "%Y-%m-%d %H:%M:%s") rescue nil
  file[:file_modify_date]=DateTime.strptime(data.file_modify_date.to_s, "%Y-%m-%d %H:%M:%s") rescue nil
  file[:image_height]=data.image_height.to_i
  file[:image_width]=data.image_width.to_i

  # ---- Camera ----
  # Compression
  # DateTime Original
  # Make
  # Megapixels                      
  # Model
  # Orientation
  # Software
  camera[:make]=data.make
  camera[:model]=data.model
  camera[:compression]=data.compression
  camera[:date_time_original]=DateTime.strptime(data.date_time_original.to_s, "%Y-%m-%d %H:%M:%s") rescue nil
  camera[:megapixels]=data.megapixels.to_f
  camera[:orientation]=data.orientation
  camera[:software]=data.software

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

  technical[:aperture]=data.aperture.to_f
  technical[:brightness]=data.brightness.to_f
  technical[:contrast]=data.contrast
  technical[:exposure_time]=data.exposure_time
  technical[:filter_effect]=data.filter_effect
  technical[:flash]=data.flash
  technical[:flash_setting]=data.flash_setting
  technical[:f_number]=data.f_number.to_f
  technical[:focal_length]=data.focal_length
  technical[:iso]=data.iso.to_i
  technical[:light_source]=data.light_source
  technical[:light_value]=data.light_value.to_f
  technical[:max_aperture_value]=data.max_aperture_value.to_f
  technical[:saturation]=data.saturation
  technical[:shutter_speed]=data.shutter_speed
  technical[:white_balance]=data.white_balance

  # ---- GPS ----
  # GPS Date/Time                                   
  # GPS Latitude                    
  # GPS Latitude Ref                
  # GPS Longitude                   
  # GPS Longitude Ref 

  gps[:gps_date_time]=DateTime.strptime(data.gps_date_time.to_s, "%Y-%m-%d %H:%M:%s") rescue nil
  dms_latitude = data.gps_latitude.to_s.scan(/\d+\.?\d+/) rescue nil
  gps[:gps_latitude]=(dms_latitude[0].to_f+(dms_latitude[1].to_f/60)+dms_latitude[2].to_f/3600).round(5)|| nil
  gps[:gps_latitude_ref]=data.gps_latitude_ref.to_s[0] rescue nil
  dms_longitude = data.gps_longitude.to_s.scan(/\d+\.?\d+/) rescue nil
  gps[:gps_longitude]=(dms_longitude[0].to_f+(dms_longitude[1].to_f/60)+dms_longitude[2].to_f/3600).round(5)|| nil
  gps[:gps_longitude_ref]=data.gps_longitude_ref.to_s[0] rescue nil


  if all
    # BitsPerSample
    # FileType
    # Image Size  
    # MIMEType
    # User Comment
    file[:image_size]=data.image_size
    file[:bits_per_sample]=data.bits_per_sample
    file[:file_type]=data.file_type
    file[:mime_type]=data.mime_type
    file[:user_comment]=data.user_comment

    # ResolutionUnit
    # XResolution
    # YResolution
    camera[:resolution_unit]=data.resolution_unit
    camera[:x_resolution]=data.x_resolution
    camera[:y_resolution]=data.y_resolution

    # DigitalZoom
    # DigitalZoomRatio
    # DistortionControl
    # ExposureCompensation
    # ExposureMode
    # ExposureProgram
    # FocalLengthIn35mmFormat
    # FocusMode
    # FOV
    # GainControl
    # HyperfocalDistance
    # MaxApertureValue
    # NoiseReduction
    # ScaleFactor35efl
    # SceneCaptureType
    # SceneMode
    # SceneType
    # Sharpness
    # ShutterSpeedValue
    technical[:digital_zoom]=data.digital_zoom
    technical[:digital_zoom_ratio]=data.digital_zoom_ratio
    technical[:distortion_control]=data.distortion_control
    technical[:exposure_compensation]=data.exposure_compensation
    technical[:exposure_mode]=data.exposure_mode
    technical[:exposure_program]=data.exposure_program
    technical[:focal_length_in_35mm_format]=data.focal_length_in_35mm_format
    technical[:focus_mode]=data.focus_mode
    technical[:fov]=data.fov
    technical[:gain_control]=data.gain_control
    technical[:hyperfocal_distance]=data.hyperfocal_distance
    technical[:max_aperture_value]=data.max_aperture_value
    technical[:noise_reduction]=data.noise_reduction
    technical[:scale_factor_35efl]=data.scale_factor_35efl
    technical[:scene_capture_type]=data.scene_capture_type
    technical[:scene_mode]=data.scene_mode
    technical[:scene_type]=data.scene_type
    technical[:sharpness]=data.sharpness
    technical[:shutter_speed_value]=data.shutter_speed_value

    # GPS Satellites            DateTime.strptime("12/22/2011", "%m/%d/%Y")      
    gps[:gps_satellites]=data.gps_satellites


  end

  exif[:file]=file.sort.to_h
  exif[:camera]=camera.sort.to_h
  exif[:technical]=technical.sort.to_h
  exif[:gps]=gps.sort.to_h

  return convertNilValues(exif)
end
