# encoding: utf-8

module Invoicing
  # = Computation of tax on prices
  #
  # This module provides a general-purpose framework for calculating tax. Its most common application
  # will probably be for computing VAT/sales tax on the price of your product, but since you can easily
  # attach your own tax computation logic, it can apply in a broad variety of different situations.
  #
  # Computing the tax on a price may be as simple as multiplying it with a constant factor, but in most
  # cases it will be more complicated. The tax rate may change over time (see +TimeDependent+), may vary
  # depending on the customer currently viewing the page (and the country in which they are located),
  # and may depend on properties of the object to which the price belongs. This module does not implement
  # any specific computation, but makes easy to implement specific tax regimes with minimal code duplication.
  #
  # == Using taxable attributes in a model
  #
  # If you have a model object (a subclass of <tt>ActiveRecord::Base</tt>) with a monetary quantity
  # (such as a price) in one or more of its database columns, you can declare that those columns/attributes
  # are taxable, for example:
  #
  #   class MyProduct < ActiveRecord::Base
  #     acts_as_taxable :normal_price, :promotion_price, :tax_logic => Invoicing::Countries::UK::VAT.new
  #   end
  #
  # In the taxable columns (+normal_price+ and +promotion_price+ in this example) you <b>must always
  # store values excluding tax</b>. The option <tt>:tax_logic</tt> is mandatory, and you must give it
  # an instance of a 'tax logic' object; you may use one of the tax logic implementations provided with
  # this framework, or write your own. See below for details of what a tax logic object needs to do.
  #
  # Your database table should also contain a column +currency+, in which you store the ISO 4217
  # three-letter upper-case code identifying the currency of the monetary amounts in the same table row.
  # If your currency code column has a name other than +currency+, you need to specify the name of that
  # column to +acts_as_taxable+ using the <tt>:currency => '...'</tt> option.
  #
  # For each attribute which you declare as taxable, several new methods are generated on your model class:
  #
  # <tt><attr></tt>::                        Returns the amount of money excluding tax, as stored in the database,
  #                                          subject to the model object's currency rounding conventions.
  # <tt><attr>=</tt>::                       Assigns a new value (exclusive of tax) to the attribute.
  # <tt><attr>_taxed</tt>::                  Returns the amount of money including tax, as computed by the tax
  #                                          logic, subject to the model object's currency rounding conventions.
  # <tt><attr>_taxed=</tt>::                 Assigns a new value (including tax) to the attribute.
  # <tt><attr>_tax_rounding_error</tt>::     Returns a number indicating how much the tax-inclusive value of the
  #                                          attribute has changed as a result of currency rounding. See the section
  #                                          'currency rounding errors' below. +nil+ if the +_taxed=+ attribute
  #                                          has not been assigned.
  # <tt><attr>_tax_info</tt>::               Returns a short string to inform a user about the tax status of
  #                                          the value returned by <tt><attr>_taxed</tt>; this could be
  #                                          "inc. VAT", for example, if the +_taxed+ attribute includes VAT.
  # <tt><attr>_tax_details</tt>::            Like +_tax_info+, but a longer string for places in the user
  #                                          interface where more space is available. For example, "including
  #                                          VAT at 15%".
  # <tt><attr>_with_tax_info</tt>::          Convenience method for views: returns the attribute value including
  #                                          tax, formatted as a human-friendly currency string in UTF-8, with
  #                                          the return value of +_tax_info+ appended. For example,
  #                                          "AU$1,234.00 inc. GST".
  # <tt><attr>_with_tax_details</tt>::       Like +_with_tax_info+, but using +_tax_details+. For example,
  #                                          "AU$1,234.00 including 10% Goods and Services Tax".
  # <tt><attr>_taxed_before_type_cast</tt>:: Returns any value which you assign to <tt><attr>_taxed=</tt> without
  #                                          converting it first. This means you to can use +_taxed+ attributes as
  #                                          fields in Rails forms and get the expected behaviour of form validation.
  #
  # +acts_as_currency+ is automatically called for all attributes given to +acts_as_taxable+, as well as all
  # generated <tt><attr>_taxed</tt> attributes. This means you get automatic currency-specific rounding
  # behaviour as documented in the +CurrencyValue+ module, and you get two additional methods for free:
  # <tt><attr>_formatted</tt> and <tt><attr>_taxed_formatted</tt>, which return the untaxed and taxed amounts
  # respectively, formatted as a nice human-friendly string.
  #
  # The +Taxable+ module automatically converts between taxed and untaxed attributes. This works as you would
  # expect: you can assign to a taxed attribute and immediately read from an untaxed attribute, or vice versa.
  # When you store the object, only the untaxed value is written to the database. That way, if the tax rate
  # changes or you open your business to overseas customers, nothing changes in your database.
  #
  # == Using taxable attributes in views and forms
  #
  # The tax logic object allows you to have one single place in your application where you declare which products
  # are seen by which customers at which tax rate. For example, if you are a VAT registered business in an EU
  # country, you always charge VAT at your home country's rate to customers within your home country; however,
  # to a customer in a different EU country you do not charge any VAT if you have received a valid VAT registration
  # number from them. You see that this logic can easily become quite complicated. This complexity should be
  # encapsulated entirely within the tax logic object, and not require any changes to your views or controllers if
  # at all possible.
  #
  # The way to achieve this is to <b>always use the +_taxed+ attributes in views and forms</b>, unless you have a
  # very good reason not to. The value returned by <tt><attr>_taxed</tt>, and the value you assign to
  # <tt><attr>_taxed=</tt>, do not necessarily have to include tax; for a given customer and product, the tax may
  # be zero-rated or not applicable, in which case their numeric value will be the same as the untaxed attributes.
  # The attributes are called +_taxed+ because they may be taxed, not because they necessarily always are. It is
  # up to the tax logic to decide whether to return the same number, or one modified to include tax.
  #
  # The purpose of the +_tax_info+ and +_tax_details+ methods is to clarify the tax status of a given number to the
  # user; if the number returned by the +_taxed+ attribute does not contain tax for whatever reason, +_tax_info+ for
  # the same attribute should say so.
  #
  # Using these attributes, views can be kept very simple:
  #
  #   <h1>Products</h1>
  #   <table>
  #     <tr>
  #       <th>Name</th>
  #       <th>Price</th>
  #     </tr>
  #   <% for product in @products %>
  #     <tr>
  #       <td><%=h product.name %></td>
  #       <td><%=h product.price_with_tax_info %></td>                                # e.g. "$25.80 (inc. tax)"
  #     </tr>
  #   <% end %>
  #   </table>
  #
  #   <h1>New product</h1>
  #   <% form_for(@product) do |f| %>
  #     <%= f.error_messages %>
  #     <p>
  #       <%= f.label :name, "Product name:" %><br />
  #       <%= f.text_field :name %>
  #     </p>
  #     <p>
  #       <%= f.label :price_taxed, "Price #{h(@product.price_tax_info)}:" %><br />   # e.g. "Price (inc. tax):"
  #       <%= f.text_field :price_taxed %>
  #     </p>
  #   <% end %>
  #
  # If this page is viewed by a user who shouldn't be shown tax, the numbers in the output will be different,
  # and it might say "excl. tax" instead of "inc. tax"; but none of that clutters the view. Moreover, any price
  # typed into the form will of course be converted as appropriate for that user. This is important, for
  # example, in an auction scenario, where you may have taxed and untaxed bidders bidding in the same
  # auction; their input and output is personalised depending on their account information, but for
  # purposes of determining the winning bidder, all bidders are automatically normalised to the untaxed
  # value of their bids.
  #
  # == Tax logic objects
  #
  # A tax logic object is an instance of a class with the following structure:
  #
  #   class MyTaxLogic
  #     def apply_tax(params)
  #       # Called to convert a value without tax into a value with tax, as applicable. params is a hash:
  #       #   :model_object => The model object whose attribute is being converted
  #       #   :attribute    => The name of the attribute (without '_taxed' suffix) being converted
  #       #   :value        => The untaxed value of the attribute as a BigDecimal
  #       # Should return a number greater than or equal to the input value. Don't worry about rounding --
  #       # CurrencyValue deals with that.
  #     end
  #
  #     def remove_tax(params)
  #       # Does the reverse of apply_tax -- converts a value with tax into a value without tax. The params
  #       # hash has the same format. First applying tax and then removing it again should always result in the
  #       # starting value (for the the same object and the same environment -- it may depend on time,
  #       # global variables, etc).
  #     end
  #
  #     def tax_info(params, *args)
  #       # Should return a short string to explain to users which operation has been performed by apply_tax
  #       # (e.g. if apply_tax has added VAT, the string could be "inc. VAT"). The params hash is the same as
  #       # given to apply_tax. Additional parameters are optional; if any arguments are passed to a call to
  #       # model_object.<attr>_tax_info then they are passed on here.
  #     end
  #
  #     def tax_details(params, *args)
  #       # Like tax_info, but should return a longer string for use in user interface elements which are less
  #       # limited in size.
  #     end
  #
  #     def mixin_methods
  #       # Optionally you can define a method mixin_methods which returns a list of method names which should
  #       # be included in classes which use this tax logic. Methods defined here become instance methods of
  #       # model objects with acts_as_taxable attributes. For example:
  #       [:some_other_method]
  #     end
  #
  #     def some_other_method(params, *args)
  #       # some_other_method was named by mixin_methods to be included in model objects. For example, if the
  #       # class MyProduct uses MyTaxLogic, then MyProduct.find(1).some_other_method(:foo, 'bar') will
  #       # translate into MyTaxLogic#some_other_method({:model_object => MyProduct.find(1)}, :foo, 'bar').
  #       # The model object on which the method is called is passed under the key :model_object in the
  #       # params hash, and all other arguments to the method are simply passed on.
  #     end
  #   end
  #
  #
  # == Currency rounding errors
  #
  # Both the taxed and the untaxed value of an attribute are currency values, and so they must both be rounded
  # to the accuracy which is conventional for the currency in use (see the discussion of precision and rounding
  # in the +CurrencyValue+ module). If we are always storing untaxed values and outputting taxed values to the
  # user, this is not a problem. However, if we allow users to input taxed values (like in the form example
  # above), something curious may happen: The input value has its tax removed, is rounded to the currency's
  # conventional precision and stored in the database in untaxed form; then later it is loaded, tax is added
  # again, it is again rounded to the currency's conventional precision, and displayed to the user. If the
  # rounding steps have rounded the number upwards twice, or downwards twice, it may happen that the value
  # displayed to the user differs slightly from the one they originally entered.
  #
  # We believe that storing untaxed values and performing currency rounding are the right things to do, and this
  # apparent rounding error is a natural consequence. This module therefore tries to deal with the error
  # elegantly: If you assign a value to a taxed attribute and immediately read it again, it will return the
  # same value as if it had been stored and loaded again (i.e. the number you read has been rounded twice --
  # make sure the currency code has been assigned to the object beforehand, so that the +CurrencyValue+ module
  # knows which precision to apply).
  #
  # Moreover, after assigning a value to a <tt><attr>_taxed=</tt> attribute, the <tt><attr>_tax_rounding_error</tt>
  # method can tell you whether and by how much the value has changed as a result of removing and re-applying
  # tax. A negative number indicates that the converted amount is less than the input; a positive number indicates
  # that it is more than entered by the user; and zero means that there was no difference.
  #
  module Taxable
    module ActMethods
      # Declares that one or more attributes on this model object store monetary values to which tax may be
      # applied. Takes one or more attribute names, followed by an options hash:
      # <tt>:tax_logic</tt>:: Object with instance methods apply_tax, remove_tax, tax_info and tax_details
      #                       as documented in the +Taxable+ module. Required.
      # <tt>:currency</tt>::  The name of the attribute/database column which stores the ISO 4217 currency
      #                       code for the monetary amounts in this model object. Required if the column
      #                       is not called +currency+.
      # +acts_as_taxable+ implies +acts_as_currency_value+ with the same options. See the +Taxable+ for details.
      def acts_as_taxable(*args)
        Invoicing::ClassInfo.acts_as(Invoicing::Taxable, self, args)

        attrs = taxable_class_info.new_args.map{|a| a.to_s }
        currency_attrs = attrs + attrs.map{|attr| "#{attr}_taxed"}
        currency_opts = taxable_class_info.all_options.update({:conversion_input => :convert_taxable_value})
        acts_as_currency_value(currency_attrs, currency_opts)

        attrs.each {|attr| generate_attr_taxable_methods(attr) }

        if tax_logic = taxable_class_info.all_options[:tax_logic]
          other_methods = (tax_logic.respond_to?(:mixin_methods) ? tax_logic.mixin_methods : []) || []
          other_methods.each {|method_name| generate_attr_taxable_other_method(method_name.to_s) }
        else
          raise ArgumentError, 'You must specify a :tax_logic option for acts_as_taxable'
        end
      end
    end

    # If +write_attribute+ is called on a taxable attribute, we note whether the taxed or the untaxed
    # version contains the latest correct value. We don't do the conversion immediately in case the tax
    # logic requires the value of another attribute (which may be assigned later) to do its calculation.
    def write_attribute(attribute, value) #:nodoc:
      attribute = attribute.to_s
      attr_regex = taxable_class_info.all_args.map{|a| a.to_s }.join('|')
      @taxed_or_untaxed ||= {}
      @taxed_attributes ||= {}

      if attribute =~ /^(#{attr_regex})$/
        @taxed_or_untaxed[attribute] = :untaxed
        @taxed_attributes[attribute] = nil
      elsif attribute =~ /^(#{attr_regex})_taxed$/
        @attributes[attribute] = value
        @taxed_or_untaxed[$1] = :taxed
        @taxed_attributes[$1] = value
      end

      super
    end

    # Called internally to convert between taxed and untaxed values. You shouldn't usually need to
    # call this method from elsewhere.
    def convert_taxable_value(attr) #:nodoc:
      attr = attr.to_s
      attr_without_suffix = attr.sub(/(_taxed)$/, '')
      to_status = ($1 == '_taxed') ? :taxed : :untaxed

      @taxed_or_untaxed ||= {}
      from_status = @taxed_or_untaxed[attr_without_suffix] || :untaxed # taxed or untaxed most recently assigned?

      attr_to_read = attr_without_suffix
      attr_to_read += '_taxed' if from_status == :taxed

      if from_status == :taxed && to_status == :taxed
        # Special case: remove tax, apply rounding errors, apply tax again, apply rounding errors again.
        write_attribute(attr_without_suffix, send(attr_without_suffix))
        send(attr)
      else
        taxable_class_info.convert(self, attr_without_suffix, read_attribute(attr_to_read), from_status, to_status)
      end
    end

    protected :write_attribute, :convert_taxable_value


    module ClassMethods #:nodoc:
      # Generate additional accessor method for attribute with getter +method_name+.
      def generate_attr_taxable_methods(method_name) #:nodoc:

        define_method("#{method_name}_tax_rounding_error") do
          original_value = read_attribute("#{method_name}_taxed")
          return nil if original_value.nil? # Can only have a rounding error if the taxed attr was assigned

          original_value = BigDecimal.new(original_value.to_s)
          converted_value = send("#{method_name}_taxed")

          return nil if converted_value.nil?
          converted_value - original_value
        end

        define_method("#{method_name}_tax_info") do |*args|
          tax_logic = taxable_class_info.all_options[:tax_logic]
          tax_logic.tax_info({:model_object => self, :attribute => method_name, :value => send(method_name)}, *args)
        end

        define_method("#{method_name}_tax_details") do |*args|
          tax_logic = taxable_class_info.all_options[:tax_logic]
          tax_logic.tax_details({:model_object => self, :attribute => method_name, :value => send(method_name)}, *args)
        end

        define_method("#{method_name}_with_tax_info") do |*args|
          amount = send("#{method_name}_taxed_formatted")
          tax_info = send("#{method_name}_tax_info").to_s
          tax_info.blank? ? amount : "#{amount} #{tax_info}"
        end

        define_method("#{method_name}_with_tax_details") do |*args|
          amount = send("#{method_name}_taxed_formatted")
          tax_details = send("#{method_name}_tax_details").to_s
          tax_details.blank? ? amount : "#{amount} #{tax_details}"
        end

        define_method("#{method_name}_taxed_before_type_cast") do
          @taxed_attributes ||= {}
          @taxed_attributes[method_name] ||
            read_attribute_before_type_cast("#{method_name}_taxed") ||
            send("#{method_name}_taxed")
        end
      end

      # Generate a proxy method called +method_name+ which is forwarded to the +tax_logic+ object.
      def generate_attr_taxable_other_method(method_name) #:nodoc:
        define_method(method_name) do |*args|
          tax_logic = taxable_class_info.all_options[:tax_logic]
          tax_logic.send(method_name, {:model_object => self}, *args)
        end
      end

      private :generate_attr_taxable_methods, :generate_attr_taxable_other_method
    end # module ClassMethods


    class ClassInfo < Invoicing::ClassInfo::Base #:nodoc:
      # Performs the conversion between taxed and untaxed values. Arguments +from_status+ and
      # +to_status+ must each be either <tt>:taxed</tt> or <tt>:untaxed</tt>.
      def convert(object, attr_without_suffix, value, from_status, to_status)
        return nil if value.nil?
        value = BigDecimal.new(value.to_s)
        return value if from_status == to_status

        if to_status == :taxed
          all_options[:tax_logic].apply_tax({:model_object => object, :attribute => attr_without_suffix, :value => value})
        else
          all_options[:tax_logic].remove_tax({:model_object => object, :attribute => attr_without_suffix, :value => value})
        end
      end
    end

  end
end
