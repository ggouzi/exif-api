require 'sinatra'
require 'mini_exiftool'
require 'objspace'
require_relative 'utils'

set :port, 3000

EXCLUDE_LIST = [ 'thumbnail_image', 'data_dump' ]
NIL_VALUES = [ "", " ", "Unknown", "Unknown ()", "n/a", "null" ]
SAVE_DIR = "tmp"
LIMIT_FILE_SIZE=65*1024 # 65 MB MAX

before '/exif/*' do
  content_type :json
end

get '/exif/read/simple/?' do
  return {:status => 404, :message => "Route not found", :error => true}.to_json
end

get '/exif/read/all/?' do
  return {:status => 404, :message => "Route not found", :error => true}.to_json
end

get '/exif/read/raw/?' do
  return {:status => 404, :message => "Route not found", :error => true}.to_json
end

get '/exif/read/copy/?' do
  return {:status => 404, :message => "Route not found", :error => true}.to_json
end

get '/exif/read/delete/?' do
  return {:status => 404, :message => "Route not found", :error => true}.to_json
end

get '/exif/?' do
  File.read(File.join('frontend', 'index.html'))
end

post '/exif/upload/?' do
  result=Utils.parseFileParam(params)
  if result.nil?
    tempfile = params[:file][:tempfile]
    filename = params[:file][:filename]
    begin
        hash = Utils.duplicateFile(tempfile, SAVE_DIR)
        result = { :file_hash => hash }.to_json
    rescue Exception => e
        result = {:status => 500, :message => "Internal server error: Unable to upload file", :error => true}.to_json
    end
  end
  result
end

get '/exif/read/simple/:hash/?' do
    filepath, result = Utils.parseParams params[:hash]
    if result.nil?
      begin
        exif = getExifInfo(filepath, false)
        result = exif.to_json
      rescue Exception => e
        result = {:status => 500, :message => "Internal server error: Unable to retrieve exif data", :error => true}.to_json
      end
    end
    result
end

get '/exif/read/all/:hash/?' do
    filepath, result = Utils.parseParams params[:hash]
    if result.nil?
      begin
        exif = getExifInfo(filepath, true)
        result = exif.to_json
      rescue Exception => e
        puts e.message
        result = {:status => 500, :message => "Internal server error: Unable to retrieve exif data", :error => true}.to_json
      end
    end
    result
end

get '/exif/read/raw/:hash/?' do
    filepath, result = Utils.parseParams params[:hash]
    if result.nil?
      begin
        exif = getRawExifInfo(filepath)
        result = exif.to_json
      rescue Exception => e
        puts e.message
        result = {:status => 500, :message => "Internal server error: Unable to retrieve exif data", :error => true}.to_json
      end
    end
    result
end

get '/exif/copy/:hash_source/:hash_dest/?' do
  filepathsource, result1 = Utils.parseParams params[:hash_source]
  filepathdest, result2 = Utils.parseParams params[:hash_dest]
  if !result1.nil?
    return result1
  elsif !result2.nil?
    return result2
  else
    begin
        newFilePath, result = copyTags(filepathsource, filepathdest)
        if !result.nil?
          return result
        end
        if newFilePath.nil?
          result = {:status => 500, :message => "Internal server error: Unable to copy tags from source file", :error => true}.to_json
        else
          send_file newFilePath, :filename => Utils.getFilename(filepathdest), type: 'image/jpeg'
        end
    rescue Exception => e
      puts e.message
      result = {:status => 500, :message => "Internal server error: Unable to copy exif data", :error => true}.to_json
    end
  end
  result
end

get '/exif/delete/:hash/?' do
  filepath, result = Utils.parseParams params[:hash]
  if result.nil? && !filepath.nil?
    begin
      newFilePath, result = delete_all_tags filepath
      if result.nil?
        send_file newFilePath, :filename => Utils.getFilename(filepath), type: 'image/jpeg'
      end
    rescue Exception => e
      puts e.message
      result = {:status => 500, :message => "Internal server error: Unable to retrieve exif data", :error => true}.to_json
    end
  end
  result
end

def getRawExifInfo(filename)
  data = MiniExiftool.new(filename)
  exif = Utils.convertNilValues(parseExif(data))
  return exif.sort.to_h
end

def parseExif(data)
  hash = Utils.hashToSnakeCase(data.to_hash)
  exif = hash.delete_if { |k,v| EXCLUDE_LIST.include? k }
  return exif
end

def copyTags(filepathSource, filepathDest)
  if !File.file?(filepathSource)
    return nil, {:status => 404, :message => "File not found", :error => true}.to_json
  elsif !File.file?(filepathDest)
    return nil, {:status => 404, :message => "File not found", :error => true}.to_json
  end
  extension = filepathDest.split('.').last
  newFileName = File.join(SAVE_DIR, Utils.hashFile(filepathDest)+"."+extension)
  command_line = `exiftool -o #{newFileName} -tagsFromFile #{filepathSource} -all:all #{filepathDest}`
  if !File.file?(newFileName)
    return nil, {:status => 404, :message => "File not found", :error => true}.to_json
  end
  return newFileName,nil
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
  #file[:file_name]=filename
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

  return Utils.convertNilValues(exif)
end


def delete_all_tags(filePath)
  if !File.file?(filePath)
    return nil, {:status => 404, :message => "File not found", :error => true}.to_json
  end
  extension = filePath.split('.').last
  newFilePath = File.join(SAVE_DIR, Utils.hashFile(filePath)+"."+extension)
  command_line = `exiftool -o #{newFilePath} -all= #{filePath}`
  if !File.file?(newFilePath)
    return nil, {:status => 404, :message => "File not found", :error => true}.to_json
  end
  return newFilePath, nil
end
