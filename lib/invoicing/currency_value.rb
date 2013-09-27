require "active_support/concern"

module Invoicing
  # = Input and output of monetary values
  #
  # This module simplifies model objects which need to store monetary values. It automatically takes care
  # of currency rounding conventions and formatting values for output.
  #
  # == General notes on currency precision and rounding
  #
  # It is important to deal carefully with rounding errors in accounts. If the figures don't add up exactly,
  # you may have to pay for expensive accountant hours while they try to find out where the missing pennies or
  # cents have gone -- better to avoid this trouble from the start. Because of this, it is strongly recommended
  # that you use fixed-point or decimal datatypes to store any sort of currency amounts, never floating-point
  # numbers.
  #
  # Keep in mind that not all currencies subdivide their main unit into 100 smaller units; storing four digits
  # after the decimal point should be enough to allow you to expand into other currencies in future. Also leave
  # enough headroom in case you ever need to use an inflated currency. For example,
  # if you are using MySQL, <tt>decimal(20,4)</tt> may be a good choice for all your columns which store
  # monetary amounts. The extra few bytes aren't going to cost you anything.
  #
  # On the other hand, it doesn't usually make sense to store monetary values with a higher precision than is
  # conventional for a particular currency (usually this is related to the value of the smallest coin in
  # circulation, but conventions may differ). For example, if your currency rounds to two decimal places, then
  # you should also round every monetary amount to two decimal places before storing it. If you store values
  # at a higher precision than you display, your numbers may appear to not add up correctly when you present
  # them to users. Fortunately, this module automatically performs currency-specific rounding for you.
  #
  # == Using +acts_as_currency_value+
  #
  # This module simplifies model objects which need to store monetary values, by automatically taking care
  # of currency rounding and formatting conventions. In a typical set-up, every model object which has one or
  # more attributes storing monetary amounts (a price, a fee, a tax amount, a payment value, etc.) should also
  # have a +currency+ column, which stores the ISO 4217 three-letter upper-case code identifying the currency.
  # Annotate your model class with +acts_as_currency_value+, passing it a list of attribute names which store
  # monetary amounts. If you refuse to store a +currency+ attribute, you may instead specify a default currency
  # by passing a <tt>:currency_code => CODE</tt> option to +acts_as_currency_value+, but this is not recommended:
  # even if you are only using one currency now, you may well expand into other currencies later. It is not
  # possible to have multiple different currencies in the same model object.
  #
  # The +CurrencyValue+ module knows how to handle a set of default currencies (see +CURRENCIES+ below). If your
  # currency is not supported in the way you want, you can extend/modify the hash yourself (please also send us
  # a patch so that we can extend our list of inbuilt currencies):
  #   Invoicing::CurrencyValue::CURRENCIES['HKD'] = {:symbol => 'HK$', :round => 0.10, :digits => 2}
  # This specifies that the Hong Kong Dollar should be displayed using the 'HK$' symbol and two digits after the
  # decimal point, but should always be rounded to the nearest 10 cents since the 10 cent coin is the smallest
  # in circulation (therefore the second digit after the decimal point will always be zero).
  #
  # When that is done, you can use the model object normally, and rounding will occur automatically:
  #   invoice.currency = 'HKD'
  #   invoice.tax_amount = invoice.net_amount * TaxRates.default_rate_now  # 1234.56789
  #   invoice.tax_amount == BigDecimal('1234.6')                           # true - rounded to nearest 0.01
  #
  # Moreover, you can just append +_formatted+ to your attribute name and get the value formatted for including
  # in your views:
  #   invoice.tax_amount_formatted                                         # 'HK$1,234.60'
  # The string returned by a +_formatted+ method is UTF-8 encoded -- remember most currency symbols (except $)
  # are outside basic 7-bit ASCII.
  module CurrencyValue
    extend ActiveSupport::Concern

    # Data about currencies, indexed by ISO 4217 code. (Currently a very short list, in need of extending.)
    # The values are hashes, in which the following keys are recognised:
    # <tt>:round</tt>::  Smallest unit of the currency in normal use, to which values are rounded. Default is 0.01.
    # <tt>:symbol</tt>:: Symbol or string usually used to denote the currency. Encoded as UTF-8. Default is ISO 4217 code.
    # <tt>:suffix</tt>:: +true+ if the currency symbol appears after the number, +false+ if it appears before. Default +false+.
    CURRENCIES = {
      'EUR' => {:symbol => "\xE2\x82\xAC"},                   # Euro
      'GBP' => {:symbol => "\xC2\xA3"},                       # Pound Sterling
      'USD' => {:symbol => "$"},                              # United States Dollar
      'CAD' => {:symbol => "$"},                              # Canadian Dollar
      'AUD' => {:symbol => "$"},                              # Australian Dollar
      'CNY' => {:symbol => "\xE5\x85\x83", :suffix => true},  # Chinese Yuan (RMB)
      'INR' => {:symbol => "\xE2\x82\xA8"},                   # Indian Rupee
      'JPY' => {:symbol => "\xC2\xA5",     :round  => 1}      # Japanese Yen
    }

    module ActMethods
      # Declares that the current model object has columns storing monetary amounts. Pass those attribute
      # names to +acts_as_currency_value+. By default, we try to find an attribute or method called +currency+,
      # which stores the 3-letter ISO 4217 currency code for a record; if that attribute has a different name,
      # specify the name using the <tt>:currency</tt> option. For example:
      #
      #   class Price < ActiveRecord::Base
      #     validates_numericality_of :net_amount, :tax_amount
      #     validates_inclusion_of :currency_code, %w( USD GBP EUR JPY )
      #     acts_as_currency_value :net_amount, :tax_amount, :currency => :currency_code
      #   end
      #
      # You may also specify the <tt>:value_for_formatting</tt> option, passing it the name of a method on
      # your model object. That method will be called when a CurrencyValue method with +_formatted+ suffix
      # is called, and allows you to modify the numerical value before it is formatted into a string. An
      # options hash is also passed. This can be useful, for example, if a value is stored positive but you
      # want to display it as negative in certain circumstances depending on the view:
      #
      #   class LedgerItem < ActiveRecord::Base
      #     acts_as_ledger_item
      #     acts_as_currency_value :total_amount, :tax_amount, :value_for_formatting => :value_for_formatting
      #
      #     def value_for_formatting(value, options={})
      #       value *= -1 if options[:debit]  == :negative &&  debit?(options[:self_id])
      #       value *= -1 if options[:credit] == :negative && !debit?(options[:self_id])
      #       value
      #     end
      #   end
      #
      #   invoice = Invoice.find(1)
      #   invoice.total_amount_formatted :debit => :negative, :self_id => invoice.sender_id
      #     # => '$25.00'
      #   invoice.total_amount_formatted :debit => :negative, :self_id => invoice.recipient_id
      #     # => '-$25.00'
      #
      # (The example above is actually a real part of +LedgerItem+.)
      def acts_as_currency_value(*args)
        Invoicing::ClassInfo.acts_as(Invoicing::CurrencyValue, self, args)
      end
    end

    included do
      # Register callback if this is the first time acts_as_currency_value has been called
      before_save :write_back_currency_values, :if => "currency_value_class_info.previous_info.nil?"
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

        # Given the three-letter ISO 4217 code of a currency, returns a hash with useful bits of information:
        # <tt>:code</tt>::   The ISO 4217 code of the currency.
        # <tt>:round</tt>::  Smallest unit of the currency in normal use, to which values are rounded. Default is 0.01.
        # <tt>:symbol</tt>:: Symbol or string usually used to denote the currency. Encoded as UTF-8. Default is ISO 4217 code.
        # <tt>:suffix</tt>:: +true+ if the currency symbol appears after the number, +false+ if it appears before.
        # <tt>:space</tt>::  Whether or not to leave a space between the number and the currency symbol.
        # <tt>:digits</tt>:: Number of digits to display after the decimal point.
        def currency_info(code, options={})
          code = code.to_s.upcase
          valid_options = [:symbol, :round, :suffix, :space, :digits]
          info = {:code => code, :symbol => code, :round => 0.01, :suffix => nil, :space => nil, :digits => nil}
          if ::Invoicing::CurrencyValue::CURRENCIES.has_key? code
            info.update(::Invoicing::CurrencyValue::CURRENCIES[code])
          end
          options.each_pair {|key, value| info[key] = value if valid_options.include? key }

          info[:suffix] ||= (info[:code] == info[:symbol]) && !info[:code].nil?
          info[:space]  ||= info[:suffix]
          info[:digits] = -Math.log10(info[:round]).floor if info[:digits].nil?
          info[:digits] = 0 if info[:digits] < 0

          info
        end

        # Given the three-letter ISO 4217 code of a currency and a BigDecimal value, returns the
        # value formatted as an UTF-8 string, ready for human consumption.
        #
        # FIXME: This method currently does not take locale into account -- it always uses the dot
        # as decimal separator and the comma as thousands separator.
        def format_value(currency_code, value, options={})
          info = currency_info(currency_code, options)

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
        ::Invoicing::CurrencyValue::Formatter.currency_info(currency_of(object), all_options)
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
          value = BigDecimal.new(raw_value.to_s) unless raw_value.nil?
        end
        value
      end
    end
  end
end
