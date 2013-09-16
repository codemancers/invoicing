module Invoicing
  # = Subclass-aware filtering by class methods
  #
  # Utility module which can be mixed into <tt>ActiveRecord::Base</tt> subclasses which use
  # single table inheritance. It enables you to query the database for model objects based
  # on static class properties without having to instantiate more model objects than necessary.
  # Its methods should be used as class methods, so the module should be mixed in using +extend+.
  #
  # For example:
  #
  #   class Product < ActiveRecord::Base
  #     extend Invoicing::FindSubclasses
  #     def self.needs_refrigeration; false; end
  #   end
  #
  #   class Food < Product; end
  #   class Bread < Food; end
  #   class Yoghurt < Food
  #     def self.needs_refrigeration; true; end
  #   end
  #   class GreekYoghurt < Yoghurt; end
  #
  #   class Drink < Product; end
  #   class SoftDrink < Drink; end
  #   class Smoothie < Drink
  #     def self.needs_refrigeration; true; end
  #   end
  #
  # So we know that all +Yoghurt+ and all +Smoothie+ objects need refrigeration (including subclasses
  # of +Yoghurt+ and +Smoothly+, unless they override +needs_refrigeration+ again), and the others
  # don't. This fact is defined through a class method and not stored in the database. It needn't
  # necessarily be constant -- you could make +needs_refrigeration+ return +true+ or +false+
  # depending on the current temperature, for example.
  #
  # Now assume that in your application you need to query all objects which need refrigeration
  # (and maybe also satisfy some other conditions). Since the database knows nothing about
  # +needs_refrigeration+, what you would have to do traditionally is to instantiate all objects
  # and then to filter them yourself, i.e.
  #
  #   Product.find(:all).select{|p| p.class.needs_refrigeration}
  #
  # However, if only a small proportion of your products needs refrigeration, this requires you to
  # load many more objects than necessary, putting unnecessary load on your application. With the
  # +FindSubclasses+ module you can let the database do the filtering instead:
  #
  #   Product.find(:all, :conditions => {:needs_refrigeration => true})
  #
  # You could even define a named scope to do the same thing:
  #
  #   class Product
  #     named_scope :refrigerated_products, :conditions => {:needs_refrigeration => true})
  #   end
  #
  # Much nicer! The condition looks precisely like a condition on a database table column, even
  # though it actually refers to a class method. Under the hood, this query translates into:
  #
  #   Product.find(:all, :conditions => {:type => ['Yoghurt', 'GreekYoghurt', 'Smoothie']})
  #
  # And of course you can combine it with normal conditions on database table columns. If there
  # is a table column and a class method with the same name, +FindSublasses+ remains polite and lets
  # the table column take precedence.
  #
  # == How it works
  #
  # +FindSubclasses+ relies on having a list of all subclasses of your single-table-inheritance
  # base class; then, if you specify a condition with a key which has no corresponding database
  # table column, +FindSubclasses+ will check all subclasses for the return value of a class
  # method with that name, and search for the names of classes which match the condition.
  #
  # Purists of object-oriented programming will most likely find this appalling, and it's important
  # to know the limitations. In Ruby, a class can be notified if it subclassed, by defining the
  # <tt>Class#inherited</tt> method; we use this to gather together a list of subclasses. Of course,
  # we won't necessarily know about every class in the world which may subclass our class; in
  # particular, <tt>Class#inherited</tt> won't be called until that subclass is loaded.
  #
  # If you're including the Ruby files with the subclass definitions using +require+, we will learn
  # about subclasses as soon as they are defined. However, if class loading is delayed until a
  # class is first used (for example, <tt>ActiveSupport::Dependencies</tt> does this with model
  # objects in Rails projects), we could run into a situation where we don't yet know about all
  # subclasses used in a project at the point where we need to process a class method condition.
  # This would cause us to omit some objects we should have found.
  #
  # To prevent this from happening, this module searches for all types of object currently stored
  # in the table (along the lines of <tt>SELECT DISTINCT type FROM table_name</tt>), and makes sure
  # all class names mentioned there are loaded before evaluating a class method condition. Note that
  # this doesn't necessarily load all subclasses, but at least it loads those which currently have
  # instances stored in the database, so we won't omit any objects when selecting from the table.
  # There is still room for race conditions to occur, but otherwise it should be fine. If you want
  # to be on the safe side you can ensure all subclasses are loaded when your application
  # initialises -- but that's not completely DRY ;-)
  module FindSubclasses

    # Overrides <tt>ActiveRecord::Base.sanitize_sql_hash_for_conditions</tt> since this is the method
    # used to transform a hash of conditions into an SQL query fragment. This overriding method
    # searches for class method conditions in the hash and transforms them into a condition on the
    # class name. All further work is delegated back to the superclass method.
    #
    # Condition formats are very similar to those accepted by +ActiveRecord+:
    #   {:my_class_method => 'value'}     # known_subclasses.select{|cls| cls.my_class_method == 'value' }
    #   {:my_class_method => [1, 2]}      # known_subclasses.select{|cls| [1, 2].include?(cls.my_class_method) }
    #   {:my_class_method => 3..6}        # known_subclasses.select{|cls| (3..6).include?(cls.my_class_method) }
    #   {:my_class_method => true}        # known_subclasses.select{|cls| cls.my_class_method }
    #   {:my_class_method => false}       # known_subclasses.reject{|cls| cls.my_class_method }
    def sanitize_sql_hash_for_conditions(attrs, table_name = quoted_table_name)
      new_attrs = {}

      attrs.each_pair do |attr, value|
        attr = attr_base = attr.to_s
        attr_table_name = table_name

        # Extract table name from qualified attribute names
        attr_table_name, attr_base = attr.split('.', 2) if attr.include?('.')

        if columns_hash.include?(attr_base) || ![self.table_name, quoted_table_name].include?(attr_table_name)
          new_attrs[attr] = value   # Condition on a table column, or another table -- pass through unmodified
        else
          begin
            matching_classes = select_matching_subclasses(attr_base, value)
            new_attrs["#{self.table_name}.#{inheritance_column}"] = matching_classes.map{|cls| cls.name.to_s}
          rescue NoMethodError
            new_attrs[attr] = value # If the class method doesn't exist, fall back to passing condition through unmodified
          end
        end
      end

      super(new_attrs, table_name)
    end

    def expand_hash_conditions_for_aggregates(attrs)
      new_attrs = {}

      attrs.each_pair do |attr, value|
        attr = attr_base = attr.to_s
        attr_table_name = table_name

        # Extract table name from qualified attribute names
        attr_table_name, attr_base = attr.split('.', 2) if attr.include?('.')

        if columns_hash.include?(attr_base) || ![self.table_name, quoted_table_name].include?(attr_table_name)
          new_attrs[attr] = value   # Condition on a table column, or another table -- pass through unmodified
        else
          begin
            matching_classes = select_matching_subclasses(attr_base, value)
            new_attrs["#{self.table_name}.#{inheritance_column}"] = matching_classes.map{|cls| cls.name.to_s}
          rescue NoMethodError
            new_attrs[attr] = value # If the class method doesn't exist, fall back to passing condition through unmodified
          end
        end
      end

      super(new_attrs)
    end

    # Returns a list of those classes within +known_subclasses+ which match a condition
    # <tt>method_name => value</tt>. May raise +NoMethodError+ if a class object does not
    # respond to +method_name+.
    def select_matching_subclasses(method_name, value, table = table_name, type_column = inheritance_column)
      known_subclasses(table, type_column).select do |cls|
        returned = cls.send(method_name)
        (returned == value) or case value
          when true         then !!returned
          when false        then !returned
          when Array, Range then value.include?(returned)
        end
      end
    end

    # Ruby callback which is invoked when a subclass is created. We use this to build a list of known
    # subclasses.
    def inherited(subclass)
      remember_subclass subclass
      super
    end

    # Add +subclass+ to the list of know subclasses of this class.
    def remember_subclass(subclass)
      @known_subclasses ||= [self]
      @known_subclasses << subclass unless @known_subclasses.include? subclass
      self.superclass.remember_subclass(subclass) if self.superclass.respond_to? :remember_subclass
    end

    # Return the list of all known subclasses of this class, if necessary checking the database for
    # classes which have not yet been loaded.
    def known_subclasses(table = table_name, type_column = inheritance_column)
      load_all_subclasses_found_in_database(table, type_column)
      @known_subclasses ||= [self]
    end

  private
    # Query the database for all qualified class names found in the +type_column+ column
    # (called +type+ by default), and check that classes of that name have been loaded by the Ruby
    # interpreter. If a type name is encountered which cannot be loaded,
    # <tt>ActiveRecord::SubclassNotFound</tt> is raised.
    #
    # TODO: Cache this somehow, to avoid querying for class names more often than necessary. It's not
    # obvious though how to do this best -- a different Ruby instance may insert a row into the
    # database with a type which is not yet loaded in this interpreter. Maybe reloading the list
    # of types from the database every 30-60 seconds or so would be a compromise?
    def load_all_subclasses_found_in_database(table = table_name, type_column = inheritance_column)
      quoted_table_name = connection.quote_table_name(table)
      quoted_inheritance_column = connection.quote_column_name(type_column)
      query = "SELECT DISTINCT #{quoted_inheritance_column} FROM #{quoted_table_name}"
      for subclass_name in connection.select_all(query).map{|record| record[type_column]}
        unless subclass_name.blank? # empty string or nil means base class
          begin
            compute_type(subclass_name)
          rescue NameError
            raise ActiveRecord::SubclassNotFound, # Error message borrowed from ActiveRecord::Base
              "The single-table inheritance mechanism failed to locate the subclass: '#{subclass_name}'. " +
              "This error is raised because the column '#{type_column}' is reserved for storing the class in case of inheritance. " +
              "Please rename this column if you didn't intend it to be used for storing the inheritance class " +
              "or overwrite #{self.to_s}.inheritance_column to use another column for that information."
          end
        end
      end
    end
  end
end
