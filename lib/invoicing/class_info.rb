module Invoicing
  module ClassInfo
    def self.acts_as(source_module, calling_class, args)
      # The name by which the particular module using ClassInfo is known
      module_name = source_module.name.split('::').last.underscore
      class_info_method = "#{module_name}_class_info"

      previous_info =
        if calling_class.respond_to?(class_info_method, true)
          # acts_as has been called before on the same class, or a superclass
          calling_class.send(class_info_method) || calling_class.superclass.send(class_info_method)
        else
          # acts_as is being called for the first time -- do the mixins!
          calling_class.send(:include, source_module)
          nil # no previous_info
        end

      # Instantiate the ClassInfo::Base subclass and assign it to an instance variable in calling_class
      class_info_class = source_module.const_get('ClassInfo')
      class_info = class_info_class.new(calling_class, previous_info, args)
      calling_class.instance_variable_set("@#{class_info_method}", class_info)

      # Define a getter class method on calling_class through which the ClassInfo::Base
      # instance can be accessed.
      calling_class.class_eval <<-CLASSEVAL
        class << self
          def #{class_info_method}
            if superclass.respond_to?("#{class_info_method}", true)
              @#{class_info_method} ||= superclass.send("#{class_info_method}")
            end
            @#{class_info_method}
          end
          private "#{class_info_method}"
        end
      CLASSEVAL

      # For convenience, also define an instance method which does the same as the class method
      calling_class.class_eval do
        define_method class_info_method do
          self.class.send(class_info_method)
        end
        private class_info_method
      end
    end

    class Base
      # The class on which the +acts_as_+ method was called
      attr_reader :model_class

      # The <tt>ClassInfo::Base</tt> instance created by the last +acts_as_+ method
      # call on the same class (or its superclass); +nil+ if this is the first call.
      attr_reader :previous_info

      # The list of arguments passed to the current +acts_as_+ method call (excluding the final options hash)
      attr_reader :current_args

      # Union of +current_args+ and <tt>previous_info.all_args</tt>
      attr_reader :all_args

      # <tt>self.all_args - previous_info.all_args</tt>
      attr_reader :new_args

      # The options hash passed to the current +acts_as_+ method call
      attr_reader :current_options

      # Hash of options with symbolized keys, with +option_defaults+ overridden by +previous_info+ options,
      # in turn overridden by +current_options+.
      attr_reader :all_options

      def initialize(model_class, previous_info, args)
        @model_class = model_class
        @previous_info = previous_info

        @current_options = args.extract_options!.symbolize_keys
        @all_options = (@previous_info.nil? ? option_defaults : @previous_info.all_options).clone
        @all_options.update(@current_options)

        @all_args = @new_args = @current_args = args.flatten.uniq
        unless @previous_info.nil?
          @all_args = (@previous_info.all_args + @all_args).uniq
          @new_args = @all_args - previous_info.all_args
        end
      end

      # Override this method to return a hash of default option values.
      def option_defaults
        {}
      end

      # If there is an option with the given key, returns the associated value; otherwise returns
      # the key. This is useful for mapping method names to their renamed equivalents through options.
      def method(name)
        name = name.to_sym
        (all_options[name] || name).to_s
      end

      # Returns the value returned by calling +method_name+ (renamed through options using +method+)
      # on +object+. Returns +nil+ if +object+ is +nil+ or +object+ does not respond to that method.
      def get(object, method_name)
        meth = method(method_name)
        (object.nil? || !object.respond_to?(meth)) ? nil : object.send(meth)
      end

      # Assigns +new_value+ to <tt>method_name=</tt> (renamed through options using +method+)
      # on +object+. +method_name+ should not include the equals sign.
      def set(object, method_name, new_value)
        object.send("#{method(method_name)}=", new_value) unless object.nil?
      end
    end
  end
end
