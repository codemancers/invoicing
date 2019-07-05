require "active_support/concern"

module Invoicing
  module CurrencyValue
    extend ActiveSupport::Concern

    module ActMethods
      def acts_as_currency_value(*args)
        Invoicing::ClassInfo.acts_as(Invoicing::CurrencyValue, self, args)
      end
    end

    included do
      # Register callback if this is the first time acts_as_currency_value has been called
      before_save :write_back_currency_values, if: -> { currency_value_class_info.previous_info.nil? }
    end

    # Format a numeric monetary value into a human-readable string, in the currency of the
    # current model object.
    def format_currency_value(value, options={})
      currency_value_class_info.format_value(self, value, options)
    end


    # Called automatically via +before_save+. Writes the result of converting +CurrencyValue+ attributes
    # back to the actual attributes, so that they are saved in the database. (This doesn't happen in
    # +convert_currency_values+ to avoid losing the +_before_type_cast+ attribute values.)
    def write_back_currency_values
      currency_value_class_info.all_args.each do |attr|
        write_attribute(attr, send(attr))
      end
    end

    protected :write_back_currency_values


    # Encapsulates the methods for formatting currency values in a human-friendly way.
    # These methods do not depend on ActiveRecord and can thus also be called externally.
    module Formatter
      class << self

        def currency_info
          info = {:code => 'EUR', :symbol => '\xE2\x82\xAC', :round => 0.01}
          info[:suffix] = true
          info[:space] = true
          info[:digits] = -Math.log10(info[:round]).floor if info[:digits].nil?
          info[:digits] = 0 if info[:digits] < 0

          info
        end

        def format_value(currency_code, value, options={})
          info = currency_info

          negative = false
          if value < 0
            negative = true
            value = -value
          end

          value = "%.#{info[:digits]}f" % value
          while value.sub!(/(\d+)(\d\d\d)/, '\1,\2'); end
          value.sub!(/^\-/, '') # avoid displaying minus zero

          formatted = if ['', nil].include? info[:symbol]
            value
          elsif info[:space]
            info[:suffix] ? "#{value} #{info[:symbol]}" : "#{info[:symbol]} #{value}"
          else
            info[:suffix] ? "#{value}#{info[:symbol]}" : "#{info[:symbol]}#{value}"
          end

          if negative
            # default is to use proper unicode minus sign
            formatted = (options[:negative] == :brackets) ? "(#{formatted})" : (
              (options[:negative] == :hyphen) ? "-#{formatted}" : "\xE2\x88\x92#{formatted}"
            )
          end
          formatted.force_encoding("utf-8")
        end
      end
    end


    class ClassInfo < Invoicing::ClassInfo::Base #:nodoc:

      def initialize(model_class, previous_info, args)
        super
        new_args.each{|attr| generate_attrs(attr)}
      end

      # Generates the getter and setter method for attribute +attr+.
      def generate_attrs(attr)
        model_class.class_eval do
          define_method(attr) do
            currency_info = currency_value_class_info.currency_info_for(self)
            return read_attribute(attr) if currency_info.nil?
            round_factor = BigDecimal(currency_info[:round].to_s)

            value = currency_value_class_info.attr_conversion_input(self, attr)
            value.nil? ? nil : (value / round_factor).round * round_factor
          end

          define_method("#{attr}=") do |new_value|
            write_attribute(attr, new_value)
          end

          define_method("#{attr}_formatted") do |*args|
            options = args.first || {}
            value_as_float = begin
              Kernel.Float(send("#{attr}_before_type_cast"))
            rescue ArgumentError, TypeError
              nil
            end

            if value_as_float.nil?
              ''
            else
              format_currency_value(value_as_float, options.merge({:method_name => attr}))
            end
          end
        end
      end

      # Returns the value of the currency code column of +object+, if available; otherwise the
      # default currency code (set by the <tt>:currency_code</tt> option), if available; +nil+ if all
      # else fails.
      def currency_of(object)
        if object.attributes.has_key?(method(:currency)) || object.respond_to?(method(:currency))
          get(object, :currency)
        else
          all_options[:currency_code]
        end
      end

      # Returns a hash of information about the currency used by model +object+.
      def currency_info_for(object)
        ::Invoicing::CurrencyValue::Formatter.currency_info
      end

      # Formats a numeric value as a nice currency string in UTF-8 encoding.
      # +object+ is the model object carrying the value (used to determine the currency).
      def format_value(object, value, options={})
        options = all_options.merge(options).symbolize_keys
        intercept = options[:value_for_formatting]
        if intercept && object.respond_to?(intercept)
          value = object.send(intercept, value, options)
        end
        ::Invoicing::CurrencyValue::Formatter.format_value(currency_of(object), value, options)
      end

      # If other modules have registered callbacks for the event of reading a rounded attribute,
      # they are executed here. +attr+ is the name of the attribute being read.
      def attr_conversion_input(object, attr)
        value = nil

        if callback = all_options[:conversion_input]
          value = object.send(callback, attr)
        end

        unless value
          raw_value = object.read_attribute(attr)
          value = BigDecimal(raw_value.to_s) unless raw_value.nil?
        end
        value
      end
    end
  end
end
