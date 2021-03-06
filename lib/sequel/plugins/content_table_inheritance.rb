# encoding: UTF-8

module Sequel
  module Plugins
    # The single_table_inheritance plugin allows storing all objects
    # in the same class hierarchy in the same table.  It makes it so
    # subclasses of this model only load rows related to the subclass,
    # and when you retrieve rows from the main class, you get instances
    # of the subclasses (if the rows should use the subclasses's class).
    #
    # By default, the plugin assumes that the +sti_key+ column (the first
    # argument to the plugin) holds the class name as a string.  However,
    # you can override this by using the <tt>:model_map</tt> option and/or
    # the <tt>:key_map</tt> option.
    #
    # You should only load this plugin in the parent class, not in the subclasses.
    #
    # You shouldn't call set_dataset in the model after applying this
    # plugin, otherwise subclasses might use the wrong dataset. You should
    # make sure this plugin is loaded before the subclasses. Note that since you
    # need to load the plugin before the subclasses are created, you can't use
    # direct class references in the plugin class.  You should specify subclasses
    # in the plugin call using class name strings or symbols, see usage below.
    #
    # Usage:
    #
    #   # Use the default of storing the class name in the sti_key
    #   # column (:kind in this case)
    #   Employee.plugin :single_table_inheritance, :kind
    #
    #   # Using integers to store the class type, with a :model_map hash
    #   # and an sti_key of :type
    #   Employee.plugin :single_table_inheritance, :type,
    #     :model_map=>{1=>:Staff, 2=>:Manager}
    #
    #   # Using non-class name strings
    #   Employee.plugin :single_table_inheritance, :type,
    #     :model_map=>{'line staff'=>:Staff, 'supervisor'=>:Manager}
    #
    #   # Using custom procs, with :model_map taking column values
    #   # and yielding either a class, string, symbol, or nil,
    #   # and :key_map taking a class object and returning the column
    #   # value to use
    #   Employee.plugin :single_table_inheritance, :type,
    #     :model_map=>proc{|v| v.reverse},
    #     :key_map=>proc{|klass| klass.name.reverse}
    #
    # One minor issue to note is that if you specify the <tt>:key_map</tt>
    # option as a hash, instead of having it inferred from the <tt>:model_map</tt>,
    # you should only use class name strings as keys, you should not use symbols
    # as keys.
    module ContentTableInheritance
      # Setup the necessary STI variables, see the module RDoc for SingleTableInheritance
      def self.configure(model, key, opts={})
        model.instance_eval do
          @sti_dataset_root = model
          @sti_model_map = lambda { |id| Spontaneous.schema[id] }
          @sti_key_map = lambda { |klass| klass.schema_id.to_s }
          @sti_key_array = nil
          @sti_subclasses_array = [sti_key_map[model]]
          @sti_key = key
          @sti_dataset = dataset
          @is_content_inheritance_root = false
          @is_site_inheritance_root = false
          dataset.row_proc = lambda{|r| model.sti_load(r)}
        end
      end

      module ClassMethods
        attr_reader :sti_dataset_root

        # The base dataset for STI, to which filters are added to get
        # only the models for the specific STI subclass.
        attr_reader :sti_dataset

        # The column name holding the STI key for this model
        attr_reader :sti_key

        # Array holding keys for all subclasses of this class, used for the
        # dataset filter in subclasses. Nil in the main class.
        attr_reader :sti_key_array

        # A hash/proc with class keys and column value values, mapping
        # the the class to a particular value given to the sti_key column.
        # Used to set the column value when creating objects, and for the
        # filter when retrieving objects in subclasses.
        attr_reader :sti_key_map

        # A hash/proc with column value keys and class values, mapping
        # the value of the sti_key column to the appropriate class to use.
        attr_reader :sti_model_map

        attr_reader :sti_subclasses_array

        attr_reader :is_site_inheritance_root

        # Copy the necessary attributes to the subclasses, and filter the
        # subclass's dataset based on the sti_kep_map entry for the class.
        def inherited(subclass)
          super
          sk = sti_key
          sd = sti_dataset
          sdr = sti_dataset_root
          skm = sti_key_map
          smm = sti_model_map
          key = skm[subclass]
          ska = [key].reject { |k| k.blank? }
          subclass.instance_eval do
            @sti_key = sk
            @sti_key_array = ska
            @sti_subclasses_array = [skm[subclass]]
            @sti_dataset = sd
            @sti_key_map = skm
            @sti_model_map = smm
            @simple_table = nil
            @sti_dataset_root = sdr
          end
          sti_subclass_added(key, subclass)
        end

        # used by Page and Piece classes to control the subclasses used in searches
        # see 'test_content_inheritance.rb'
        def set_inheritance_root
          @is_content_inheritance_root = true
          dataset.row_proc = Spontaneous::Content.dataset.row_proc
        end

        def set_site_inheritance_root
          @is_site_inheritance_root = true
          dataset.row_proc = Spontaneous::Content.dataset.row_proc
        end

        def unset_site_inheritance_root
          @is_site_inheritance_root = false
        end

        # Return an instance of the class specified by sti_key,
        # used by the row_proc.
        def sti_load(r)
          sti_class(sti_model_map[r[sti_key]]).load(r)
        end

        # Make sure that all subclasses of the parent class correctly include
        # keys for all of their descendant classes.
        # Subclasses of Spontaneous::[Page, Piece] as well as ::Page & ::Piece are treated specially
        # they only return instances of that one class as this is the intuitively correct result
        # The top level Page & Piece classes return all sub-classes
        def sti_subclass_added(key, subclass = nil)
          if sti_key_array
            if subclass && subclass.name
              # alright, so this is a bit of a hack
              # we want the site defined ::Page, ::Piece classes to work like Spot::[Page,Piece]
              # but we don't want generic subclasses of Spot::[Page, Piece] to do so
              if subclass.name.demodulize == self.name.demodulize && @is_content_inheritance_root
                subclass.set_site_inheritance_root
              end
            end
            unless key.blank?
              if @is_site_inheritance_root or @is_content_inheritance_root
                sti_key_array << key unless sti_key_array.include?(key)
              end
              sti_subclasses_array << key
            end
            superclass.sti_subclass_added(key)
          end
        end

        def dataset
          return super if self == sti_dataset_root
          sti_dataset_root.dataset.filter(SQL::QualifiedIdentifier.new(sti_dataset_root.table_name, sti_key)=>sti_key_array)
        end

        private

        # Return a class object.  If a class is given, return it directly.
        # Treat strings and symbols as class names.  If nil is given or
        # an invalid class name string or symbol is used, return self.
        # Raise an error for other types.
        def sti_class(v)
          case v
          when String, Symbol
            constantize(v) rescue self
          when nil
            self
          when Class
            v
          else
            raise(Error, "Invalid class type used: #{v.inspect}")
          end
        end

      end

      module InstanceMethods
        # Set the sti_key column based on the sti_key_map.
        def before_create
          send("#{model.sti_key}=", model.sti_key_map[model]) unless self[model.sti_key]
          super
        end
      end
    end
  end
end
