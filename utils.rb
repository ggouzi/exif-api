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

def self.getFilename(filepath)
  File.basename filepath 
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

def self.parseParams(hash)
  result = nil
  filename = nil
  if !hash.nil?
    begin
      filename =`ls -a #{SAVE_DIR} | grep "^#{hash}\..*" | head -1`
      filepath = File.join(SAVE_DIR, filename)
      #extension = filename.split('.').last
      if !File.file?(filepath)
        result = {:status => 404, :message => "File not found", :error => true}.to_json
      end
      return filepath.strip, nil
    rescue
      result = {:status => 500, :message => "Internal server error", :error => true}.to_json
    end
  end
  return nil, result
end


def self.parseFileParam(params)
  result = nil
  if params.include?('file')
    if params[:file].include?('tempfile') && params[:file].include?('filename')  
      begin
        fileSize = File.size(params[:file][:tempfile]).to_f / 1024
        if ObjectSpace.memsize_of(params[:file][:tempfile])>=LIMIT_FILE_SIZE
          result = {:status => 413, :message => "File size too large", :error => true}.to_json
        end
      rescue
        result = {:status => 500, :message => "Internal server error", :error => true}.to_json
      end
    else
      result = {:status => 400, :message => "File parameter is malformed", :error => true}.to_json
    end
  else
    result = {:status => 400, :message => "Missing file parameter", :error => true}.to_json
  end
  return result
end

end