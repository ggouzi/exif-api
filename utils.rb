require 'fileutils'
require 'digest/md5'

module Utils


# ***** String *****
def self.to_snake_case(camel_cased_word)
 camel_cased_word.to_s.gsub(/::/, '/').
   gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
   gsub(/([a-z\d])([A-Z])/,'\1_\2').
   tr("- ", "_ ").downcase
end

# ***** File *****
def self.deleteFile(hash, dir)
	FileUtils.rm(File.join(dir, hash))
end

def self.deleteFile(path)
  FileUtils.rm(path)
end

def self.duplicateFile(filename, filedir)
  hash = hashFile(filename)
  FileUtils.mkdir_p(filedir) unless File.exists?(filedir)
  newFileName = hash+".jpg"
  fileLocation = File.join(filedir, newFileName)
  File.open(fileLocation, 'wb') do |file|
      file.write(filename.read)
  end
  return hash
end

def self.hashFile(filename)
  Digest::MD5.hexdigest(File.read(filename)+Time.now.to_s) # Include timestamp in the hash to ensure unicity
end


# ***** Hash *****
def self.convertNilValues(hash)
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

def self.hashToSnakeCase(hash)
  newHash=Hash.new
  hash.each { |k,v| newHash[to_snake_case(k)]=v }
  return newHash
end



def self.parseRequest(params)
  result = nil
  if params.include?('file')
    if params[:file].include?('tempfile') && params[:file].include?('filename')  
      begin
        fileSize = File.size(params[:file][:tempfile]).to_f / 1024
        if ObjectSpace.memsize_of(params[:file][:tempfile])>=LIMIT_FILE_SIZE
          result = {:status => 413, :message => "File size too large", :error => true}.to_json
        end
      rescue
        result = {:status => 400, :message => "Cannot access file parameter as a File", :error => true}.to_json
      end

    else
      result = {:status => 400, :message => "File parameter is malformed", :error => true}.to_json
    end
  else
    result = {:status => 400, :message => "Missing file parameter", :error => true}.to_json
  end
  return result
end

def self.parseRequestCopy(params)
  result = nil
  if params.include?('file_source') && params.include?('file_dest')
    if params[:file_source].include?('tempfile') && params[:file_source].include?('filename') && params[:file_dest].include?('tempfile') && params[:file_dest].include?('filename')  
      begin
        fileSourceSize = File.size(params[:file_source][:tempfile]).to_f / 1024
        fileDestSize = File.size(params[:file_dest][:tempfile]).to_f / 1024
        if ObjectSpace.memsize_of(params[:file_source][:tempfile])>=LIMIT_FILE_SIZE || ObjectSpace.memsize_of(params[:file_dest][:tempfile])>=LIMIT_FILE_SIZE
          result = {:status => 413, :message => "File size too large", :error => true}.to_json
        end
      rescue
        result = {:status => 400, :message => "Cannot access file parameter as a File", :error => true}.to_json
      end

    else
      result = {:status => 400, :message => "File parameter is malformed", :error => true}.to_json
    end
  else
    result = {:status => 400, :message => "Missing file parameter", :error => true}.to_json
  end
  return result
end

def self.parseRequestDelete(params)
  result = nil
  if params.include?('file')
    if params[:file].include?('tempfile') && params[:file].include?('filename')  
      begin
        fileSize = File.size(params[:file][:tempfile]).to_f / 1024
        if ObjectSpace.memsize_of(params[:file][:tempfile])>=LIMIT_FILE_SIZE
          result = {:status => 413, :message => "File size too large", :error => true}.to_json
        end
      rescue
        result = {:status => 400, :message => "Cannot access file parameter as a File", :error => true}.to_json
      end
    else
      result = {:status => 400, :message => "File parameter is malformed", :error => true}.to_json
    end
  else
    result = {:status => 400, :message => "Missing file parameter", :error => true}.to_json
  end
  if params.include?('tags')
    if !params[:tags].is_a? String
      result = {:status => 400, :message => "Cannot parse tags parameter", :error => true}.to_json
    end
  else
    result = {:status => 400, :message => "Missing tags parameter", :error => true}.to_json
  end
  return result
end


def self.parseRequestUpdate(params)
  result = nil
  if params.include?('file')
    if params[:file].include?('tempfile') && params[:file].include?('filename')  
      begin
        fileSize = File.size(params[:file][:tempfile]).to_f / 1024
        if ObjectSpace.memsize_of(params[:file][:tempfile])>=LIMIT_FILE_SIZE
          result = {:status => 413, :message => "File size too large", :error => true}.to_json
        end
      rescue
        result = {:status => 400, :message => "Cannot access file parameter as a File", :error => true}.to_json
      end
    else
      result = {:status => 400, :message => "File parameter is malformed", :error => true}.to_json
    end
  else
    result = {:status => 400, :message => "Missing file parameter", :error => true}.to_json
  end
  if params.include?('tag')
    if !params[:tag].is_a? String
      result = {:status => 400, :message => "Cannot parse tag parameter", :error => true}.to_json
    end
  else
    result = {:status => 400, :message => "Missing tag parameter", :error => true}.to_json
  end
  return result
end


end