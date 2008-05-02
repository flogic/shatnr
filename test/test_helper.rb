$:.unshift(File.dirname(__FILE__) + '/../lib')
RAILS_ROOT = File.dirname(__FILE__) + '/../../../..'

require 'rubygems'
require 'test/unit'
require 'erb'
require 'mocha'

######################
# Firing up a test environment for ActiveRecord should not be this hard, but it is...

RAILS_ENV='test'

# Load ActiveRecord
db_config = begin
  require "#{RAILS_ROOT}/config/boot"
  require "#{RAILS_ROOT}/config/environment"
  require "#{RAILS_ROOT}/vendor/rails/activerecord/lib/active_record/fixtures" 
  "#{RAILS_ROOT}/config/database.yml"
rescue LoadError => e
  require 'active_record' 
  require 'active_record/fixtures'
  puts "Unable to find owning project environment, using local configuration"
  "test/database.yml"
end

# Grab the normal init
require "#{File.dirname(__FILE__)}/../init"

# Connect to database
config = YAML::load(ERB.new(IO.read(db_config)).result)
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config['test'])

# Load the schema
load(File.dirname(__FILE__) + "/schema.rb")

####################


