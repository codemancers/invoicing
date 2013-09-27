require 'active_support/concern'

module Invoicing
  # == Aggressive ActiveRecord cache
  #
  # This module implements a cache of +ActiveRecord+ objects. It is suitable for database
  # tables with a small number of rows (no more than a few dozen is recommended) which
  # change very infrequently. The contents of the table is loaded into memory when the
  # class is first created; <b>to clear the cache you must call +clear_cache+ or
  # restart the Ruby interpreter</b>. It is recommended that if you need to change the
  # data in this table, you do so in a database migration, and apply that migration as
  # part of a release deployment.
  #
  # The cache works as a simple identity map: it has a hash where the key is the primary
  # key of each model object and the value is the model object itself. +ActiveRecord+
  # methods are overridden so that if +find+ is called with one or more IDs, the object(s)
  # are returned from cache; if +find+ is called with more complex conditions, the usual
  # database mechanisms are used and the cache is ignored. Note that this does not
  # guarantee that the same ID value will always map to the same model object instance;
  # it just reduces the number of database queries.
  #
  # To activate +CachedRecord+, call +acts_as_cached_record+ in the scope of an
  # <tt>ActiveRecord::Base</tt> class.
  module CachedRecord
    extend ActiveSupport::Concern

    module ActMethods
      # Call +acts_as_cached_record+ on an <tt>ActiveRecord::Base</tt> class to declare
      # that objects of this class should be cached using +CachedRecord+.
      #
      # Accepts options in a hash, all of which are optional:
      # * +id+ -- If the primary key of this model is not +id+, declare the method name
      #   of the primary key.
      def acts_as_cached_record(*args)
        Invoicing::ClassInfo.acts_as(Invoicing::CachedRecord, self, args)
      end
    end

    module ClassMethods
      # This method overrides the default <tt>ActiveRecord::Base.find_from_ids</tt> (which is called
      # from <tt>ActiveRecord::Base.find</tt>) with caching behaviour. +find+ is also used by
      # +ActiveRecord+ when evaluating associations; therefore if another model object refers to
      # a cached record by its ID, calling the getter of that association should result in a cache hit.
      #
      # FIXME: Currently +options+ is ignored -- we should do something more useful with it
      # to ensure CachedRecord behaviour is fully compatible with +ActiveRecord+.
      def find_from_ids(ids, options)
        expects_array = ids.first.kind_of?(Array)
        return ids.first if expects_array && ids.first.empty?

        ids = ids.flatten.compact.uniq

        case ids.size
          when 0
            raise ::ActiveRecord::RecordNotFound, "Couldn't find #{name} without an ID"
          when 1
            result = cached_record_class_info.find_one(ids.first, options)
            expects_array ? [ result ] : result
          else
            cached_record_class_info.find_some(ids, options)
        end
      end

      # Returns a list of all objects of this class. Like <tt>ActiveRecord::Base.find(:all)</tt>
      # but coming from the cache.
      def cached_record_list
        cached_record_class_info.list
      end

      # Reloads the cached objects from the database.
      def reload_cache
        cached_record_class_info.reload_cache
      end
    end # module ClassMethods


    # Stores state in the ActiveRecord class object, including the cache --
    # a hash which maps ID to model object for all objects of this model object type
    class ClassInfo < Invoicing::ClassInfo::Base #:nodoc:
      def initialize(model_class, previous_info, args)
        super
        reload_cache
      end

      def reload_cache
        @cache = {}
        model_class.all.each {|obj| @cache[get(obj, :id)] = obj }
      end

      # Returns one object from the cache, given its ID.
      def find_one(id, options)
        if result = @cache[id]
          result
        else
          raise ::ActiveRecord::RecordNotFound, "Couldn't find #{model_class.name} with ID=#{id}"
        end
      end

      # Returns a list of objects from the cache, given a list of IDs.
      def find_some(ids, options)
        ids.map{|id| find_one(id, options) }
      end

      # Returns a list of all objects in the cache.
      def list
        @cache.values
      end
    end # class ClassInfo
  end # module CachedRecord
end
