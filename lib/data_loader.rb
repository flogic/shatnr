=begin
  Directory structure:
    data manager only considers files and directories under RAILS_ROOT/db
    Directories under db/ represent organizations. ( centerstone, bloomington, quinco, ... )
      db/core is also at this level.
    Directories under db/{organization} represent environments ( test, development, bloomington, quinco, ... )
      standard environments, corresponding to RAILS_ENV ( test, development, production )
        These contain the base data
      custom environments, corresponding to RAILS_ENV ( billing_demo, all_zips, nightly, milestone )
        These are variations of a standard environment
    
  Terms:
    load plan  : a sequence of steps which populates the target database in a particular way
    data build : contents of target database after a load plan completes
    build root : directory containing the files which determine the load plan 
                 examples: db/centerstone/test, db/bloomington/development, db/centerstone/nightly, ...
        specifically, the load plan is determined by the contents of the following files:
          datasets.yml  -- configuration file that specifies the load order of the files
          ruby scripts  -- may generate data, call other scripts to do so, or load YAML data.
          other CSV files -- fixture loading also works for CSV files.
          other YAML files -- load by default unless a ruby script of the same basename exists
    dependency graph : a directed acyclic graph based on models and their belongs_to associations
       this determines the default load order
=end

# DataLoaderFiles is a hash containing a hash about each file to load. The key is the basename of each file
# It also contains routines that do the work of reading directories and figuring out which file to load, as
# well as the routine to load a file
class DataLoaderFiles < Hash
  
  # Initialize takes a reference to the owning DataLoader. This is a circular reference in memory (BAD!), but
  # prevents namespace pollution on scripts being run by the data loader.
  def initialize(owner, data_root)
    @owner = owner
    @data_root = data_root
  end
  
  SORT_ORDER=%w(.yml .csv .rb) unless defined?(SORT_ORDER)
  
  # Read the files containing in a directory and save information about them to load in the hash
  def read_dir(name)
    puts "read_dir(#{name})" if ENV['DEBUG']
    dir=Dir.new(File.join(@data_root,name))
    dir.map do |m|                                    # First convert to basename, extension pairs
      [  File.basename(m, '.*'), File.extname(m) ]
    end.select do |sbase, sext|                       # Select supported extensions that are not control files
      SORT_ORDER.include?(sext) && sbase != 'datasets'
    end.sort do |(a1,b1),(a2,b2)|                     # Sort based on precedence
      SORT_ORDER.index(b1) <=> SORT_ORDER.index(b2)
    end.each do |base,ext|                            # Insert into hash
      self[base.to_sym] = {
        :path  => File.join( dir.path , base+ext),
        :type  => ext,
        :state => :untouched
      }
    end
  end

  # Load a file given the symbolic key for the base name.
  def load_file(key)
    puts "load_file(#{key})" if ENV['DEBUG']
    fileinfo = self[key]
    raise RuntimeError, 'Unable to locate file #{name}' unless fileinfo
    
    return if fileinfo[:state] == :loaded # Done if this file is already loaded

    # Load model dependencies if the file name corresponds to a model
    model_name = key.to_s.classify
    klass = model_name.constantize rescue nil
    @owner.model_depends(klass) if klass && klass.ancestors.include?(ActiveRecord::Base)
    
    # Now do the actual load
    puts "Request load of #{key}" if ENV['DEBUG']
    case fileinfo[:type] 
    when '.yml', '.csv'
      ActiveRecord::Base.connection.purge_data(key.to_s)
      Fixtures.create_fixtures( File.dirname(fileinfo[:path]), key.to_s)
    when '.rb'
      puts "#{key} instance eval" if ENV['DEBUG']
      @owner.instance_eval(IO.read(fileinfo[:path]), fileinfo[:path])
    else
      raise RuntimeError, "Improper file extension load requested #{fileinfo[:path]}"      
    end
    
    # Mark file as loaded
    puts "loaded file #{fileinfo[:path].gsub(@data_root, '')}"
    fileinfo[:state] = :loaded
   end
end

class DataLoader
  
  attr_accessor :debug, :source_dir
  
  # DataLoader.new(datasetname) will load the given dataset
  def initialize(name, data_root = File.join(RAILS_ROOT,'db'))
    @source_dir = File.join(data_root, name)
    @data_loader_files = DataLoaderFiles.new(self, data_root)
    # Load data sets
    # Read control file and load those first
    ds = YAML.load(IO.read(File.join(data_root,name,'datasets.yml')))
    ds.each {|s| @data_loader_files.read_dir(s)}
    @data_loader_files.read_dir(name) # Load the given dataset's files

    # For each file, load that file
    @data_loader_files.keys.each {|k| @data_loader_files.load_file(k)} 
  end
  
  # This is useful for explictly stating a dependency
  def depends(name)
    puts "depends(#{name})" if ENV['DEBUG']
    fileinfo = @data_loader_files[name.to_sym]
    raise RuntimeError, "Unsatisfied dependency '#{name}'"      unless fileinfo
    raise RuntimeError, "Circular Data Dependency in '#{name}'"  if fileinfo[:state] == :requested
    
    fileinfo[:state] = :requested unless fileinfo[:state] == :loaded
    @data_loader_files.load_file(name.to_sym)
  end
  
  def model_depends(model_class)
    puts "model_depends(#{model_class})" if ENV['DEBUG']
    model_class.reflect_on_all_associations(:belongs_to).reject do |r|
      # Ignore self when doing dependencies
      model_class.to_s == r.class_name
    end.each do |a|
      klass = a.class_name.constantize.table_name rescue nil
      depends(klass) if klass
    end
  end
  
  
end