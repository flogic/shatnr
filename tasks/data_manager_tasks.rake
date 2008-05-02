namespace :db do
  desc "Load a data set into the current environments database. Defaults data set to centerstone/RAIL_ENV. Override with SET=datasetname"
  task :load => [:environment, :purge] do
    require 'data_loader'
    require 'active_record/fixtures'

    ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
    DataLoader.new( ENV['SET'] || 'centerstone/'+RAILS_ENV)
  end
end