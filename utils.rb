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

def self.duplicateFile(filename, filedir)
  hash = hashFile(filename)
  FileUtils.mkdir_p(filedir) unless File.exists?(filedir)
  newFileName = hash+".jpg"
  fileLocation = File.join(filedir, newFileName)
  File.open(fileLocation, 'wb') do |file|
      file.write(filename.read)
  end
  return newFileName
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

end