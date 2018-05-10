module Catapult
  class Config
    require_relative('config/nemesis_properties_file')
    require_relative('config/keys')
    require_relative('config/paths')
    require_relative('config/source_target_pair')
    
    # child classes
    require_relative('config/catapult_node')

    
    include Paths::Mixin
    extend Paths::ClassMixin
    
    def initialize(type, input_attributes, template_attributes)
      @type                  = type
      @config_info_dir       = self.class.config_info_dir
      @template_attributes   = template_attributes
      # gets dynamically updated
      @ndx_config_files = {} #@ndx_config_files is indexed by TYPE-INDEX
    end
    
    private :initialize

    CARDINALITY = {
      api_node: 1,
      peer_node: 2
    }

    def self.generate_and_write_configurations(keys, base_config_target_dir)
      ndx_config_files = {}
      ndx_config_files.merge!(Catapult::Config::CatapultNode::PeerNode.generate(keys: keys))
      ndx_config_files.merge!(Catapult::Config::CatapultNode::ApiNode.generate(keys: keys))
      write_out_config_files(ndx_config_files, base_config_target_dir)
    end

    def self.generate_nemesis_properties_file(input_attributes)
      NemesisPropertiesFile.generate_file(input_attributes)
    end
    
    def self.generate(input_attributes)
      new(input_attributes).generate
    end
      
    def generate
      add_static_config_files!
      add_instantiate_config_templates!
      self.ndx_config_files
    end

    def self.cardinality(type)
      CARDINALITY[type] || fail("Unexpected type '#{type}'")
    end
    
    def self.type
      self::TYPE
    end

    def self.component_indexes(cardinality)
      (0..cardinality-1).to_a
    end
        
    protected
    
    attr_reader :type, :input_attributes, :config_info_dir, :template_attributes, :ndx_config_files
    
    def cardinality
      @cardinality ||= self.class.cardinality(self.type)
    end

    def component_indexes
      @component_indexes ||= self.class.component_indexes(self.cardinality)
    end

    private
    
    def add_static_config_files!
      add_static_files!(:config_file, self.all_files_in_config_info_dir)
    end

    # type can be :script, :config_file
    def add_static_files!(file_type, static_files)
      SourceTargetPair.config_files(static_files).each do |pair|
        path    = relative_path(file_type, pair.filename)
        content = File.open(pair.source_path).read
        self.component_indexes.each { |index| add_config_file!(index, path, content) }
      end
    end
    
    # Can be overwritten
    def add_instantiate_config_templates!
      SourceTargetPair.config_templates(self.all_files_in_config_info_dir).each do |pair|
        template_path = pair.source_path
        template      = File.open(template_path).read
        self.component_indexes.each do |index| 
          instantiated_template = Catapult.bind_mustache_variables(template, self.template_attributes.hash(index))
          path = relative_path(:config_file, pair.filename)
          add_config_file!(index, path, instantiated_template)
        end 
      end
    end
    
    def add_config_file!(component_index, path, content)
      ndx = "#{self.type}#{component_index}"
      (self.ndx_config_files[ndx] ||= {}).merge!(path => content)
    end

    def self.write_out_config_files(ndx_config_files, base_config_target_dir)
      ndx_config_files.each_pair do |component_ref, info|
        component_dir = "#{base_config_target_dir}/#{component_ref}"
        info.each_pair do |path, content|
          full_path = "#{component_dir}/#{path}"
          FileUtils.mkdir_p(directory_part(full_path))
          File.open(full_path, 'w') { |f| f << content }
        end
      end
    end

    def self.directory_part(full_path)
      split = full_path.split('/')
      split.pop
      split.join('/')
    end

  end
end
