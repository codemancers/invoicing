require "active_support/concern"

module Invoicing
  # == Time-dependent value objects
  #
  # This module implements the notion of a value (or a set of values) which may change at
  # certain points in time, and for which it is important to have a full history of values
  # for every point in time. It is used in the invoicing framework as basis for tax rates,
  # prices, commissions etc.
  #
  # === Background
  #
  # To illustrate the need for this tool, consider for example the case of a tax rate. Say
  # the rate is currently 10%, and in a naive implementation you simply store the value
  # <tt>0.1</tt> in a constant. Whenever you need to calculate tax on a price, you multiply
  # the price with the constant, and store the result together with the price in the database.
  # Then, one day the government decides to increase the tax rate to 12%. On the day the
  # change takes effect, you change the value of the constant to <tt>0.12</tt>.
  #
  # This naive implementation has a number of problems, which are addressed by this module:
  # * With a constant, you have no way of informing users what a price will be after an
  #   upcoming tax change. Using +TimeDependent+ allows you to query the value on any date
  #   in the past or future, and show it to users as appropriate. You also gain the ability
  #   to process back-dated or future-dated transactions if this should be necessary.
  # * With a constant, you have no explicit information in your database informing you which
  #   rate was applied for a particular tax calculation. You may be able to infer the rate
  #   from the prices you store, but this may not be enough in cases where there is additional
  #   metadata attached to tax rates (e.g. if there are different tax rates for different
  #   types of product). With +TimeDependent+ you can have an explicit reference to the tax
  #   object which formed the basis of a calculation, giving you a much better audit trail.
  # * If there are different tax categories (e.g. a reduced rate for products of type A, and
  #   a higher rate for type B), the government may not only change the rates themselves, but
  #   also decide to reclassify product X as type B rather than type A. In any case you will
  #   need to store the type of each of your products; however, +TimeDependent+ tries to
  #   minimize the amount of reclassifying you need to do, should it become necessary.
  #
  # == Data Structure
  #
  # +TimeDependent+ objects are special ActiveRecord::Base objects. One database table is used,
  # and each row in that table represents the value (e.g. the tax rate or the price) during
  # a particular period of time. If there are multiple different values at the same time (e.g.
  # a reduced tax rate and a higher rate), each of these is also represented as a separate
  # row. That way you can refer to a +TimeDependent+ object from another model object (such as
  # storing the tax category for a product), and refer simultaneously to the type of tax
  # applicable for this product and the period for which this classification is valid.
  #
  # If a rate change is announced, it <b>important that the actual values in the table
  # are not changed</b> in order to preserve historical information. Instead, add another
  # row (or several rows), taking effect on the appropriate date. However, it is usually
  # not necessary to update your other model objects to refer to these new rows; instead,
  # each +TimeDependent+ object which expires has a reference to the new +TimeDependent+
  # objects which replaces it. +TimeDependent+ provides methods for finding the current (or
  # future) rate by following this chain of replacements.
  #
  # === Example
  #
  # To illustrate, take as example the rate of VAT (Value Added Tax) in the United Kingdom.
  # The main tax rate was at 17.5% until 1 December 2008, when it was changed to 15%.
  # On 1 January 2010 it is due to be changed back to 17.5%. At the same time, there are a
  # reduced rates of 5% and 0% on certain goods; while the main rate was changed, the
  # reduced rates stayed unchanged.
  #
  # The table of +TimeDependent+ records will look something like this:
  #
  #   +----+-------+---------------+------------+---------------------+---------------------+----------------+
  #   | id | value | description   | is_default | valid_from          | valid_until         | replaced_by_id |
  #   +----+-------+---------------+------------+---------------------+---------------------+----------------+
  #   |  1 | 0.175 | Standard rate |          1 | 1991-04-01 00:00:00 | 2008-12-01 00:00:00 |              4 |
  #   |  2 |  0.05 | Reduced rate  |          0 | 1991-04-01 00:00:00 | NULL                |           NULL |
  #   |  3 |   0.0 | Zero rate     |          0 | 1991-04-01 00:00:00 | NULL                |           NULL |
  #   |  4 |  0.15 | Standard rate |          1 | 2008-12-01 00:00:00 | 2010-01-01 00:00:00 |              5 |
  #   |  5 | 0.175 | Standard rate |          1 | 2010-01-01 00:00:00 | NULL                |           NULL |
  #   +----+-------+---------------+------------+---------------------+---------------------+----------------+
  #
  # Graphically, this may be illustrated as:
  #
  #             1991-04-01             2008-12-01             2010-01-01
  #                      :                      :                      :
  #   Standard rate: 17.5% -----------------> 15% ---------------> 17.5% ----------------->
  #                      :                      :                      :
  #   Zero rate:        0% --------------------------------------------------------------->
  #                      :                      :                      :
  #   Reduced rate:     5% --------------------------------------------------------------->
  #
  # It is a deliberate choice that a +TimeDependent+ object references its successor, and not
  # its predecessor. This is so that you can classify your items based on the current
  # classification, and be sure that if the current rate expires there is an unambiguous
  # replacement for it. On the other hand, it is usually not important to know what the rate
  # for a particular item would have been at some point in the past.
  #
  # Now consider a slightly more complicated (fictional) example, in which a UK court rules
  # that teacakes have been incorrectly classified for VAT purposes, namely that they should
  # have been zero-rated while actually they had been standard-rated. The court also decides
  # that all sales of teacakes before 1 Dec 2008 should maintain their old standard-rated status,
  # while sales from 1 Dec 2008 onwards should be zero-rated.
  #
  # Assume you have an online shop in which you sell teacakes and other goods (both standard-rated
  # and zero-rated). You can handle this reclassification (in addition to the standard VAT rate
  # change above) as follows:
  #
  #             1991-04-01             2008-12-01             2010-01-01
  #                      :                      :                      :
  #   Standard rate: 17.5% -----------------> 15% ---------------> 17.5% ----------------->
  #                      :                      :                      :
  #   Teacakes:      17.5% ------------.        :                      :
  #                      :              \_      :                      :
  #   Zero rate:        0% ---------------+->  0% ---------------------------------------->
  #                      :                      :                      :
  #   Reduced rate:     5% --------------------------------------------------------------->
  #
  # Then you just need to update the teacake products in your database, which previously referred
  # to the 17.5% object valid from 1991-04-01, to refer to the special teacake rate. None of the
  # other products need to be modified. This way, the teacakes will automatically switch to the 0%
  # rate on 2008-12-01. If you add any new teacake products to the database after December 2008, you
  # can refer either to the teacake rate or to the new 0% rate which takes effect on 2008-12-01;
  # it won't make any difference.
  #
  # == Usage notes
  #
  # This implementation is designed for tables with a small number of rows (no more than a few
  # dozen) and very infrequent changes. To reduce database load, it caches model objects very
  # aggressively; <b>you will need to restart your Ruby interpreter after making a change to
  # the data</b> as the cache is not cleared between requests. This is ok because you shouldn't
  # be lightheartedly modifying +TimeDependent+ data anyway; a database migration as part of an
  # explicitly deployed release is probably the best way of introducing a rate change
  # (that way you can also check it all looks correct on your staging server before making the
  # rate change public).
  #
  # A model object using +TimeDependent+ must inherit from ActiveRecord::Base and must have
  # at least the following columns (although columns may have different names, if declared to
  # +acts_as_time_dependent+):
  # * <tt>id</tt> -- An integer primary key
  # * <tt>valid_from</tt> -- A column of type <tt>datetime</tt>, which must not be <tt>NULL</tt>.
  #   It contains the moment at which the rate takes effect. The oldest <tt>valid_from</tt> dates
  #   in the table should be in the past by a safe margin.
  # * <tt>valid_until</tt> -- A column of type <tt>datetime</tt>, which contains the moment from
  #   which the rate is no longer valid. It may be <tt>NULL</tt>, in which case the the rate is
  #   taken to be "valid until further notice". If it is not <tt>NULL</tt>, it must contain a
  #   date strictly later than <tt>valid_from</tt>.
  # * <tt>replaced_by_id</tt> -- An integer, foreign key reference to the <tt>id</tt> column in
  #   this same table. If <tt>valid_until</tt> is <tt>NULL</tt>, <tt>replaced_by_id</tt> must also
  #   be <tt>NULL</tt>. If <tt>valid_until</tt> is non-<tt>NULL</tt>, <tt>replaced_by_id</tt> may
  #   or may not be <tt>NULL</tt>; if it refers to a replacement object, the <tt>valid_from</tt>
  #   value of that replacement object must be equal to the <tt>valid_until</tt> value of this
  #   object.
  #
  # Optionally, the table may have further columns:
  # * <tt>value</tt> -- The actual (usually numeric) value for which we're going to all this
  #   effort, e.g. a tax rate percentage or a price in some currency unit.
  # * <tt>is_default</tt> -- A boolean column indicating whether or not this object should be
  #   considered a default during its period of validity. This may be useful if there are several
  #   different rates in effect at the same time (such as standard, reduced and zero rate in the
  #   example above). If this column is used, there should be exactly one default rate at any
  #   given point in time, otherwise results are undefined.
  #
  # Apart from these requirements, a +TimeDependent+ object is a normal model object, and you may
  # give it whatever extra metadata you want, and make references to it from any other model object.
  module TimeDependent
    extend ActiveSupport::Concern

    module ActMethods
      # Identifies the current model object as a +TimeDependent+ object, and creates all the
      # necessary methods.
      #
      # Accepts options in a hash, all of which are optional:
      # * <tt>id</tt> -- Alternative name for the <tt>id</tt> column
      # * <tt>valid_from</tt> -- Alternative name for the <tt>valid_from</tt> column
      # * <tt>valid_until</tt> -- Alternative name for the <tt>valid_until</tt> column
      # * <tt>replaced_by_id</tt> -- Alternative name for the <tt>replaced_by_id</tt> column
      # * <tt>value</tt> -- Alternative name for the <tt>value</tt> column
      # * <tt>is_default</tt> -- Alternative name for the <tt>is_default</tt> column
      #
      # Example:
      #
      #   class CommissionRate < ActiveRecord::Base
      #     acts_as_time_dependent :value => :rate
      #     belongs_to :referral_program
      #     named_scope :for_referral_program, lambda { |p| { :conditions => { :referral_program_id => p.id } } }
      #   end
      #
      #   reseller_program = ReferralProgram.find(1)
      #   current_commission = CommissionRate.for_referral_program(reseller_program).default_record_now
      #   puts "Earn #{current_commission.rate} per cent commission as a reseller..."
      #
      #   changes = current_commission.changes_until(1.year.from_now)
      #   for next_commission in changes
      #     message = next_commission.nil? ? "Discontinued as of" : "Changing to #{next_commission.rate} per cent on"
      #     puts "#{message} #{current_commission.valid_until.strftime('%d %b %Y')}!"
      #     current_commission = next_commission
      #   end
      #
      def acts_as_time_dependent(*args)
        Invoicing::ClassInfo.acts_as(Invoicing::TimeDependent, self, args)

        # Create replaced_by association if it doesn't exist yet
        replaced_by_id = time_dependent_class_info.method(:replaced_by_id)
        unless respond_to? :replaced_by
          belongs_to :replaced_by, :class_name => self, :foreign_key => replaced_by_id
        end

        # Create value_at and value_now method aliases
        value_method = time_dependent_class_info.method(:value).to_s
        if value_method != 'value'
          alias_method(value_method + '_at',  :value_at)
          alias_method(value_method + '_now', :value_now)
          class_eval <<-ALIAS
            class << self
              alias_method('default_#{value_method}_at',  :default_value_at)
              alias_method('default_#{value_method}_now', :default_value_now)
            end
          ALIAS
        end
      end # acts_as_time_dependent
    end # module ActMethods


    module ClassMethods
      # Returns a list of records which are valid at some point during a particular date/time
      # range. If there is a change of rate during this time interval, and one rate replaces
      # another, then only the earliest element of each replacement chain is returned
      # (because we can unambiguously convert from an earlier rate to a later one, but
      # not necessarily in reverse).
      #
      # The date range must not be empty (i.e. +not_after+ must be later than +not_before+,
      # not the same time or earlier). If you need the records which are valid at one
      # particular point in time, use +valid_records_at+.
      #
      # A typical application for this method would be where you want to offer users the
      # ability to choose from a selection of rates, including ones which are not yet
      # valid but will become valid within the next month, for example.
      def valid_records_during(not_before, not_after)
        info = time_dependent_class_info

        # List of all records whose validity period intersects the selected period
        valid_records = all.select do |record|
          valid_from  = info.get(record, :valid_from)
          valid_until = info.get(record, :valid_until)
          has_taken_effect = (valid_from < not_after) # N.B. less than
          not_yet_expired  = (valid_until == nil) || (valid_until > not_before)
          has_taken_effect && not_yet_expired
        end

        # Select only those which do not have a predecessor which is also valid
        valid_records.select do |record|
          record.predecessors.empty? || (valid_records & record.predecessors).empty?
        end
      end

      # Returns the list of all records which are valid at one particular point in time.
      # If you need to consider a period of time rather than a point in time, use
      # +valid_records_during+.
      def valid_records_at(point_in_time)
        info = time_dependent_class_info
        all.select do |record|
          valid_from  = info.get(record, :valid_from)
          valid_until = info.get(record, :valid_until)
          has_taken_effect = (valid_from <= point_in_time) # N.B. less than or equals
          not_yet_expired  = (valid_until == nil) || (valid_until > point_in_time)
          has_taken_effect && not_yet_expired
        end
      end

      # Returns the default record which is valid at a particular point in time.
      # If there is no record marked as default, nil is returned; if there are
      # multiple records marked as default, results are undefined.
      # This method only works if the model objects have an +is_default+ column.
      def default_record_at(point_in_time)
        info = time_dependent_class_info
        valid_records_at(point_in_time).select{|record| info.get(record, :is_default)}.first
      end

      # Returns the default record which is valid at the current moment.
      def default_record_now
        default_record_at(Time.now)
      end

      # Finds the default record for a particular +point_in_time+ (using +default_record_at+),
      # then returns the value of that record's +value+ column. If +value+ was renamed to
      # +another_method_name+ (option to +acts_as_time_dependent+), then
      # +default_another_method_name_at+ is defined as an alias for +default_value_at+.
      def default_value_at(point_in_time)
        time_dependent_class_info.get(default_record_at(point_in_time), :value)
      end

      # Finds the current default record (like +default_record_now+),
      # then returns the value of that record's +value+ column. If +value+ was renamed to
      # +another_method_name+ (option to +acts_as_time_dependent+), then
      # +default_another_method_name_now+ is defined as an alias for +default_value_now+.
      def default_value_now
        default_value_at(Time.now)
      end

    end # module ClassMethods

    # Returns a list of objects of the same type as this object, which refer to this object
    # through their +replaced_by_id+ values. In other words, this method returns all records
    # which are direct predecessors of the current record in the replacement chain.
    def predecessors
      time_dependent_class_info.predecessors(self)
    end

    # Translates this record into its replacement for a given point in time, if necessary/possible.
    #
    # * If this record is still valid at the given date/time, this method just returns self.
    # * If this record is no longer valid at the given date/time, the record which has been
    #   marked as this rate's replacement for the given point in time is returned.
    # * If this record has expired and there is no valid replacement, nil is returned.
    # * On the other hand, if the given date is at a time before this record becomes valid,
    #   we try to follow the chain of +predecessors+ records. If there is an unambiguous predecessor
    #   record which is valid at the given point in time, it is returned; otherwise nil is returned.
    def record_at(point_in_time)
      valid_from  = time_dependent_class_info.get(self, :valid_from)
      valid_until = time_dependent_class_info.get(self, :valid_until)

      if valid_from > point_in_time
        (predecessors.size == 1) ? predecessors[0].record_at(point_in_time) : nil
      elsif valid_until.nil? || (valid_until > point_in_time)
        self
      elsif replaced_by.nil?
        nil
      else
        replaced_by.record_at(point_in_time)
      end
    end

    # Returns self if this record is currently valid, otherwise its past or future replacement
    # (see +record_at+). If there is no valid replacement, nil is returned.
    def record_now
      record_at Time.now
    end

    # Finds this record's replacement for a given point in time (see +record_at+), then returns
    # the value in its +value+ column. If +value+ was renamed to +another_method_name+ (option to
    # +acts_as_time_dependent+), then +another_method_name_at+ is defined as an alias for +value_at+.
    def value_at(point_in_time)
      time_dependent_class_info.get(record_at(point_in_time), :value)
    end

    # Returns +value_at+ for the current date/time. If +value+ was renamed to +another_method_name+
    # (option to +acts_as_time_dependent+), then +another_method_name_now+ is defined as an alias for
    # +value_now+.
    def value_now
      value_at Time.now
    end

    # Examines the replacement chain from this record into the future, during the period
    # starting with this record's +valid_from+ and ending at +point_in_time+.
    # If this record stays valid until after +point_in_time+, an empty list is returned.
    # Otherwise the sequence of replacement records is returned in the list. If a record
    # expires before +point_in_time+ and without replacement, a +nil+ element is inserted
    # as the last element of the list.
    def changes_until(point_in_time)
      info = time_dependent_class_info
      changes = []
      record = self
      while !record.nil?
        valid_until = info.get(record, :valid_until)
        break if valid_until.nil? || (valid_until > point_in_time)
        record = record.replaced_by
        changes << record
      end
      changes
    end


    # Stores state in the ActiveRecord class object
    class ClassInfo < Invoicing::ClassInfo::Base #:nodoc:
      def predecessors(record)
        # @predecessors is a hash of an ID pointing to the list of all objects which have that ID
        # as replaced_by_id value
        @predecessors ||= fetch_predecessors
        @predecessors[get(record, :id)] || []
      end

      def fetch_predecessors
        _predecessors = {}
        for record in model_class.all
          id = get(record, :replaced_by_id)
          unless id.nil?
            _predecessors[id] ||= []
            _predecessors[id] << record
          end
        end
        _predecessors
      end
    end # class ClassInfo
  end # module TimeDependent
end
