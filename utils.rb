require 'fileutils'
require 'objspace'

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
def self.duplicateFile(file, filename, filedir)
  FileUtils.mkdir_p(filedir) unless File.exists?(filedir)
  hash = hashFile(file.path)
  extension = File.extname(File.basename(file.path))
  newFileName = hash+extension
  FileUtils.cp(file.path, "./#{ENV['SAVE_DIR']}/#{newFileName}")
  return hash
end

def self.hashFile(filename)
  Digest::MD5.hexdigest(File.read(filename) + Time.now.to_s) # Include timestamp in the hash to ensure unicity
end

def self.getExtension(filename)
    filename.split('.').last
end

def self.getMimeType(filename)
  extension = getExtension(filename).downcase
  mimeType = extension
  if(extension!="png")
    mimeType = "jpeg"
  end
  return mimeType
end


# ***** Hash *****
def self.convertNilValues(hash)
  hash.each do |k, v|
    if v.is_a?(String)
      if NIL_VALUES.include? v
        hash[k] = nil
      end
    elsif v.is_a?(Hash)
      convertNilValues v
    end
  end
  return hash
end

def self.hashToSnakeCase(hash)
  newHash = Hash.new
  hash.each { |k,v| newHash[to_snake_case(k)]=v }
  return newHash
end

def self.createJsonBody(status, message, error)
  return {:status => status, :error => true, :message => message}
end

def self.getStatusCode(result)
  if (result.key?(:status) && result.key?(:error))
    if (result[:error]==true)
      return result[:status].to_i
    else
      result=200
    end
  end
end

def self.parseParams(hash)
  result = nil
  filename = nil
  if !hash.nil?
    begin
      filename =`ls -a #{ENV["SAVE_DIR"]} | grep "^#{hash}\..*" | head -1`
      filepath = File.join(ENV["SAVE_DIR"], filename.strip)
      if !File.file?(filepath)
        result = createJsonBody(404, "File not found", true)
      else
        return filepath, nil
      end
    rescue
      result = createJsonBody(500, "Internal server error", true)
    end
  end
  return nil, result
end


def self.parseFileParam(params)
  result = nil
  if params.include?('file')
    if params[:file].include?('tempfile') && params[:file].include?('filename')
        if ObjectSpace.memsize_of(params[:file][:tempfile]) >= LIMIT_FILE_SIZE
          result = createJsonBody(413, "Request Entity Too Large: File size too large", true)
        end
    else
      result = createJsonBody(422, "Unprocessable Entity: File parameter is malformed", true)
    end
  else
    result = createJsonBody(400, "Bad Request: Missing file parameter", true)
  end
  return result
end

end