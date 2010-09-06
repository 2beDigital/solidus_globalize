namespace :spree do
  namespace :i18n do

    language_root = File.dirname(__FILE__) + "/../generators/templates/config/locales"
    default_dir = File.dirname(__FILE__) + "/../../default"

    task :update_default do
      puts "Fetching latest Spree locale file to #{language_root}"
      #TODO also pull the auth and dash locales once they exist
      exec %(
        curl -Lo '#{default_dir}/spree_api.yml' http://github.com/railsdog/spree/raw/master/api/config/locales/en.yml
        curl -Lo '#{default_dir}/spree_core.yml' http://github.com/railsdog/spree/raw/master/core/config/locales/en.yml
        curl -Lo '#{default_dir}/spree_promo.yml' http://github.com/railsdog/spree/raw/master/promotions/config/locales/en.yml
      )
    end

    desc "Syncronize translation files with latest en (adds comments with fallback en value)"
    task :sync do
      puts "Starting syncronization..."
      words = composite_keys
      Dir["#{language_root}/*.yml"].each do |filename|
        basename = File.basename(filename, '.yml')
        (comments, other) = read_file(filename, basename)
        words.each { |k,v| other[k] ||= "##{words[k]}" unless words[k].blank? }  #Initializing hash variable as en fallback if it does not exist
        other.delete_if { |k,v| !words[k] } #Remove if not defined in en locale
        write_file(filename, basename, comments, other, false)
      end
    end

    desc "Create a new translation file based on en"
    task :new  do
      if !ENV['LOCALE'] || ENV['LOCALE'] == ''
        print "You must provide a valid LOCALE value, for example:\nrake spree:i18:new LOCALE=pt-PT\n"
        exit
      end

      write_file "#{language_root}/#{ENV['LOCALE']}.yml", "#{ENV['LOCALE']}", '---', composite_keys
      print "Also, download the rails translation from: http://github.com/svenfuchs/rails-i18n/tree/master/rails/locale\n"
    end

    desc "Show translation status for all supported locales other than en."
    task :stats do
      words = composite_keys
      words.delete_if { |k,v| !v.match(/\w+/) or v.match(/^#/) }

      results = ActiveSupport::OrderedHash.new
      locale = ENV['LOCALE'] || ''
      Dir["#{language_root}/*.yml"].each do |filename|
        # next unless filename.match('_spree')
        basename = File.basename(filename, '.yml')

        # next if basename.starts_with?('en')
        (comments, other) = read_file(filename, basename)
        other.delete_if { |k,v| !words[k] } #Remove if not defined in en.yml
        other.delete_if { |k,v| !v.match(/\w+/) or v.match(/#/) }

        translation_status = 100*(other.values.size / words.values.size.to_f)
        results[basename] = translation_status
      end
      puts "Translation status:"
      results.sort.each do |basename, translation_status|
        puts basename + "\t-    #{sprintf('%.1f', translation_status)}%"
      end
      puts
    end
  end
end

#Retrieve US word set
def get_translation_keys(gem_name)
  (dummy_comments, words) = read_file(File.dirname(__FILE__) + "/../../default/#{gem_name}.yml", "en")
  words
end

# #Retrieve comments, translation data in hash form
def read_file(filename, basename)
  (comments, data) = IO.read(filename).split(/\n#{basename}:\s*\n/)   #Add error checking for failed file read?
  return comments, create_hash(data)
end

#Creates hash of translation data
def create_hash(data)
  words = Hash.new
  return words if !data
  parent = Array.new
  previous_key = 'base'
  data.split("\n").each do |w|
    next if w.strip.blank?
    (key, value) = w.split(':', 2)
    value ||= ''
    shift = (key =~ /\w/)/2 - parent.size                             #Determine level of current key in comparison to parent array
    key = key.sub(/^\s+/,'')
    parent << previous_key if shift > 0                               #If key is child of previous key, add previous key as parent
    (shift*-1).times { parent.pop } if shift < 0                      #If key is not related to previous key, remove parent keys
    previous_key = key                                                #Track key in case next key is child of this key
    words[parent.join(':')+':'+key] = value
  end
  words
end

#Writes to file from translation data hash structure
def write_file(filename,basename,comments,words,comment_values=true, fallback_values={})
  File.open(filename, "w") do |log|
    log.puts(comments+"\n"+basename+": \n")
    words.sort.each do |k,v|
      keys = k.split(':')
      (keys.size-1).times { keys[keys.size-1] = '  ' + keys[keys.size-1] }   #Add indentation for children keys
      value = v.strip
      value = ("#" + value) if comment_values and not value.blank?
      log.puts "#{keys[keys.size-1]}: #{value}\n"
    end
  end
end

# Returns a composite hash of all relevant translation keys from each of the gems
def composite_keys
  api_keys = get_translation_keys "spree_api"
  auth_keys = get_translation_keys "spree_api"
  core_keys = get_translation_keys "spree_core"
  dash_keys = get_translation_keys "spree_api"
  promo_keys = get_translation_keys "spree_api"

  api_keys.merge(auth_keys).merge(core_keys).merge(dash_keys).merge(promo_keys)
end