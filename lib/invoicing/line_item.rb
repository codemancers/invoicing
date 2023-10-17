require "active_support/concern"

module Invoicing
  # = Line item objects
  #
  # A line item is a single charge on an invoice or credit note, for example representing the sale
  # of one particular product. An invoice or credit note with a non-zero +total_amount+ must have at
  # least one +LineItem+ object associated with it, and its +total_amount+ must equal the sum of the
  # +net_amount+ and +tax_amount+ values of all +LineItem+ objects associated with it. For details
  # on invoices and credit notes, see the +LedgerItem+ module.
  #
  # Many of the important principles set down in the +LedgerItem+ module also apply for line items;
  # for example, once you have created a line item you generally shouldn't change it again. If you
  # need to correct a mistake, create an additional line item of the same type but a negative value.
  #
  # == Using +LineItem+
  #
  # In all likelihood you will have different types of charges which you need to make to your customers.
  # We store all those different types of line item in the same database table and use ActiveRecord's
  # single table inheritance to build a class hierarchy. You must create at least one line item
  # model class in your application, like this:
  #
  #   class LineItem < ActiveRecord::Base
  #     acts_as_line_item
  #     belongs_to :ledger_item
  #   end
  #
  # You may then create a class hierarchy to suit your needs, for example:
  #
  #   class ProductSale < LineItem
  #     belongs_to :product
  #
  #     def description
  #       product.title
  #     end
  #   end
  #
  #   class ShippingCharges < LineItem
  #     def description
  #       "Shipping charges"
  #     end
  #   end
  #
  # You may associate line items of any type with credit notes and invoices interchangeably. This
  # means, for example, that if you overcharge a customer for shipping, you can send them a credit
  # note with a +ShippingCharges+ line item, thus making it explicit what it is you are refunding.
  # On a credit note/refund the line item's +net_amount+ and +tax_amount+ should be negative.
  # +Payment+ records usually do not have any associated line items.
  #
  # == Required methods/database columns
  #
  # The following methods/database columns are <b>required</b> for +LineItem+ objects (you may give them
  # different names, but then you need to tell +acts_as_line_item+ about your custom names):
  #
  # +type+::
  #   String to store the class name, for ActiveRecord single table inheritance.
  #
  # +ledger_item+::
  #   You should define an association <tt>belongs_to :ledger_item, ...</tt> which returns the
  #   +LedgerItem+ object (invoice/credit note) to which this line item belongs.
  #
  # +ledger_item_id+::
  #   A foreign key of integer type, which stores the ID of the model object returned by the
  #   +ledger_item+ association.
  #
  # +net_amount+::
  #   A decimal column containing the monetary amount charged by this line item, not including tax.
  #   The value is typically positive on an invoice and negative on a credit note. The currency is
  #   not explicitly specified on the line item, but is taken to be the currency of the invoice or
  #   credit note to which it belongs. (This is deliberate, because you mustn't mix different
  #   currencies within one invoice.) See the documentation of the +CurrencyValue+ module for notes
  #   on suitable datatypes for monetary values. +acts_as_currency_value+ is automatically applied
  #   to this attribute.
  #
  # +tax_amount+::
  #   A decimal column containing the monetary amount of tax which is added to +net_amount+ to
  #   obtain the total price. This may of course be zero if no tax applies; otherwise it should have
  #   the same sign as +net_amount+. +CurrencyValue+ applies as with +net_amount+. If you have
  #   several different taxes being applied, please check with your accountant. We suggest that you
  #   put VAT or sales tax in this +tax_amount+ column, and any other taxes (e.g. duty on alcohol or
  #   tobacco, or separate state/city taxes) in separate line items. If you are not obliged to pay
  #   tax, lucky you -- put zeroes in this column and await the day when you have enough business
  #   that you *do* have to pay tax.
  #
  # +description+::
  #   A method which returns a short string explaining to your user what this line item is for.
  #   Can be a database column but doesn't have to be.
  #
  # == Optional methods/database columns
  #
  # The following methods/database columns are <b>optional, but recommended</b> for +LineItem+ objects:
  #
  # +uuid+::
  #   A Universally Unique Identifier (UUID)[http://en.wikipedia.org/wiki/UUID] string for this line item.
  #   It may seem unnecessary now, but may help you to keep track of your data later on as your system
  #   grows. If you have the +uuid+ gem installed and this column is present, a UUID is automatically
  #   generated when you create a new line item.
  #
  # +tax_point+::
  #   A datetime column which indicates the date on which the sale is made and/or the service is provided.
  #   It is related to the +issue_date+ on the associated invoice/credit note, but does not necessarily
  #   have the same value. The exact technicalities will vary by jurisdiction, but generally this is the
  #   point in time which determines into which month or which tax period you count a sale. The value may
  #   be the same as +created_at+ or +updated_at+, but not necessarily.
  #
  # +tax_rate_id+, +tax_rate+::
  #   +tax_rate_id+ is a foreign key of integer type, and +tax_rate+ is a +belongs_to+ association
  #   based on it. It refers to another model in your application which represents the tax rate
  #   applied to this line item. The tax rate model object should use +acts_as_tax_rate+. This
  #   attribute is necessary if you want tax calculations to be performed automatically.
  #
  # +price_id+, +price+::
  #   +price_id+ is a foreign key of integer type, and +price+ is a +belongs_to+ association based
  #   on it. It refers to another model in your application which represents the unit price (e.g. a
  #   reference to a the product, or to a particular price band of a service). The model object thus
  #   referred to should use +acts_as_price+. This attribute allows you to get better reports of how
  #   much you sold of what.
  #
  # +quantity+::
  #   A numeric (integer or decimal) type, saying how many units of a particular product or service
  #   this line item represents. Default is 1. Note that if you specify a +quantity+, the values for
  #   +net_amount+ and +tax_amount+ must be the cost of the given quantity as a whole; if you need
  #   to display the unit price, you can get it by dividing +net_amount+ by +quantity+, or by
  #   referring to the +price+ association.
  #
  # +creator_id+::
  #   The ID of the user whose action caused this line item to be created or updated. This can be useful
  #   for audit trail purposes, particularly if you allow multiple users of your application to act on
  #   behalf of the same customer organisation.
  #
  # +created_at+, +updated_at+::
  #   These standard datetime columns are also recommended.
  #
  module LineItem
    extend ActiveSupport::Concern

    module ActMethods
      # Declares that the current class is a model for line items (i.e. individual items on invoices
      # and credit notes).
      #
      # The name of any attribute or method required by +LineItem+ (as documented on the
      # +LineItem+ module) may be used as an option, with the value being the name under which
      # that particular method or attribute can be found. This allows you to use names other than
      # the defaults. For example, if your database column storing the line item value is called
      # +net_price+ instead of +net_amount+:
      #
      #   acts_as_line_item :net_amount => :net_price
      def acts_as_line_item(*args)
        Invoicing::ClassInfo.acts_as(Invoicing::LineItem, self, args)

        info = line_item_class_info
        if info.previous_info.nil? # Called for the first time?
          # Set the 'amount' columns to act as currency values
          acts_as_currency_value(info.method(:net_amount), info.method(:tax_amount))

          extend Invoicing::FindSubclasses
        end
      end
    end

    included do
      before_validation :calculate_tax_amount

      # Dynamically created named scopes
      scope :in_effect, lambda {
        ledger_assoc = line_item_class_info.method(:ledger_item).to_sym
        ledger_refl = reflections[ledger_assoc] || reflections[ledger_assoc.to_s]
        ledger_table = ledger_refl.table_name # not quoted_table_name because it'll be quoted again
        status_column = ledger_refl.klass.send(:ledger_item_class_info).method(:status)
        joins(ledger_assoc).where("#{ledger_table}.#{status_column}" => ['closed', 'cleared'])
      }

      scope :sorted, lambda { |column|
        table = line_item_class_info.method(quoted_table_name).to_s
        column = line_item_class_info.method(column).to_s
        if column_names.include?(column)
          order("#{table}.#{connection.quote_column_name(column)}, #{table}.#{connection.quote_column_name(primary_key)}")
        else
          order("#{table}.#{connection.quote_column_name(primary_key)}")
        end
      }
    end

    # Overrides the default constructor of <tt>ActiveRecord::Base</tt> when +acts_as_line_item+
    # is called. If the +uuid+ gem is installed, this constructor creates a new UUID and assigns
    # it to the +uuid+ property when a new line item model object is created.
    def initialize(*args)
      super
      # Initialise uuid attribute if possible
      info = line_item_class_info
      if self.has_attribute?(info.method(:uuid)) && info.uuid_generator
        write_attribute(info.method(:uuid), info.uuid_generator.generate)
      end
    end

    # Returns the currency code of the ledger item to which this line item belongs.
    def currency
      ledger_item = line_item_class_info.get(self, :ledger_item)
      return if ledger_item.nil?

      ledger_item.send(:ledger_item_class_info).get(ledger_item, :currency)
    end

    def calculate_tax_amount
      return unless respond_to? :net_amount_taxed
      self.tax_amount = net_amount_taxed - net_amount
    end

    # The sum of +net_amount+ and +tax_amount+.
    def gross_amount
      net_amount = line_item_class_info.get(self, :net_amount)
      tax_amount = line_item_class_info.get(self, :tax_amount)
      (net_amount && tax_amount) ? (net_amount + tax_amount) : nil
    end

    # +gross_amount+ formatted in human-readable form using the line item's currency.
    def gross_amount_formatted
      format_currency_value(gross_amount)
    end

    # We don't actually implement anything using +method_missing+ at the moment, but use it to
    # generate slightly more useful error messages in certain cases.
    def method_missing(method_id, *args)
      method_name = method_id.to_s
      if ['ledger_item', line_item_class_info.method(:ledger_item)].include? method_name
        raise RuntimeError, "You need to define an association like 'belongs_to :ledger_item' on #{self.class.name}. If you " +
          "have defined the association with a different name, pass the option :ledger_item => :your_association_name to " +
          "acts_as_line_item."
      elsif method_name =~ /^amount/
        send("net_#{method_name}", *args)
      else
        super
      end
    end


    # Stores state in the ActiveRecord class object
    class ClassInfo < Invoicing::ClassInfo::Base #:nodoc:
      attr_reader :uuid_generator

      def initialize(model_class, previous_info, args)
        super

        begin # try to load the UUID gem
          require 'uuid'
          @uuid_generator = UUID.new
        rescue LoadError, NameError # silently ignore if gem not found
          @uuid_generator = nil
        end
      end

      # Allow methods generated by +CurrencyValue+ to be renamed as well
      def method(name)
        if name.to_s =~ /^(.*)_formatted$/
          "#{super($1)}_formatted"
        else
          super
        end
      end
    end
  end
end
