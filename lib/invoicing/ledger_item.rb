require "active_support/concern"

module Invoicing
  module LedgerItem
    extend ActiveSupport::Concern

    module ActMethods

      # acts_as_ledger_item :total_amount => :gross_amount
      def acts_as_ledger_item(*args)
        Invoicing::ClassInfo.acts_as(Invoicing::LedgerItem, self, args)

        info = ledger_item_class_info
        return unless info.previous_info.nil? # Called for the first time?

        # Set the 'amount' columns to act as currency values
        acts_as_currency_value(info.method(:total_amount), info.method(:tax_amount),
          :currency => info.method(:currency), :value_for_formatting => :value_for_formatting)
      end # def acts_as_ledger_item

      def acts_as_invoice(options={})
        acts_as_ledger_item(options.clone.update({:subtype => :invoice}))
      end
    end # module ActMethods

    included do
      before_validation :calculate_total_amount
    end

    # Overrides the default constructor of <tt>ActiveRecord::Base</tt> when +acts_as_ledger_item+
    # is called. If the +uuid+ gem is installed, this constructor creates a new UUID and assigns
    # it to the +uuid+ property when a new ledger item model object is created.
    def initialize(*args)
      super
      # Initialise uuid attribute if possible
      info = ledger_item_class_info
      if self.has_attribute?(info.method(:uuid)) && info.uuid_generator
        write_attribute(info.method(:uuid), info.uuid_generator.generate)
      end
    end

    # Calculate sum of net_amount and tax_amount across all line items, and assign it to total_amount;
    # calculate sum of tax_amount across all line items, and assign it to tax_amount.
    # Called automatically as a +before_validation+ callback. If the LedgerItem subtype is +payment+
    # and there are no line items then the total amount is not touched.
    def calculate_total_amount
      line_items = ledger_item_class_info.get(self, :line_items)
      return if self.class.is_payment && line_items.empty?

      net_total = tax_total = BigDecimal('0')

      line_items.each do |line|
        info = line.send(:line_item_class_info)

        # Make sure ledger_item association is assigned -- the CurrencyValue
        # getters depend on it to fetch the currency
        info.set(line, :ledger_item, self)
        line.valid? # Ensure any before_validation hooks are called

        net_amount = info.get(line, :net_amount)
        tax_amount = info.get(line, :tax_amount)
        net_total += net_amount unless net_amount.nil?
        tax_total += tax_amount unless tax_amount.nil?
      end

      ledger_item_class_info.set(self, :total_amount, net_total + tax_total)
      ledger_item_class_info.set(self, :tax_amount,   tax_total)
      return net_total
    end

    # The difference +total_amount+ minus +tax_amount+.
    def net_amount
      total_amount = ledger_item_class_info.get(self, :total_amount)
      tax_amount   = ledger_item_class_info.get(self, :tax_amount)
      (total_amount && tax_amount) ? (total_amount - tax_amount) : nil
    end

    # Returns +true+ if this document was sent by the user with ID +user_id+. If the argument is +nil+
    # (indicating yourself), this also returns +true+ if <tt>sender_details[:is_self]</tt>.
    def sent_by?(user_id)
      (ledger_item_class_info.get(self, :sender_id) == user_id) ||
        !!(user_id.nil? && ledger_item_class_info.get(self, :sender_details)[:is_self])
    end

    # Returns +true+ if this document was received by the user with ID +user_id+. If the argument is +nil+
    # (indicating yourself), this also returns +true+ if <tt>recipient_details[:is_self]</tt>.
    def received_by?(user_id)
      (ledger_item_class_info.get(self, :recipient_id) == user_id) ||
        !!(user_id.nil? && ledger_item_class_info.get(self, :recipient_details)[:is_self])
    end

    def debit?(self_id)
      sender_is_self = sent_by?(self_id)
      recipient_is_self = received_by?(self_id)
      raise ArgumentError, "self_id #{self_id.inspect} is neither sender nor recipient" unless sender_is_self || recipient_is_self
      raise ArgumentError, "self_id #{self_id.inspect} is both sender and recipient" if sender_is_self && recipient_is_self
      self.class.debit_when_sent_by_self ? sender_is_self : recipient_is_self
    end

    # Invoked internally when +total_amount_formatted+ or +tax_amount_formatted+ is called. Allows
    # you to specify options like <tt>:debit => :negative, :self_id => 42</tt> meaning that if this
    # ledger item is a debit as regarded from the point of view of +self_id+ then it should be
    # displayed as a negative number. Note this only affects the output formatting, not the actual
    # stored values.
    def value_for_formatting(value, options={})
      value = -value if (options[:debit]  == :negative) &&  debit?(options[:self_id])
      value = -value if (options[:credit] == :negative) && !debit?(options[:self_id])
      value
    end


    module ClassMethods
      # Returns +true+ if this type of ledger item should be recorded as a debit when the party
      # viewing the account is the sender of the document, and recorded as a credit when
      # the party viewing the account is the recipient. Returns +false+ if those roles are
      # reversed. This method implements default behaviour for invoices, credit notes and
      # payments (see <tt>Invoicing::LedgerItem#debit?</tt>); if you define custom ledger item
      # subtypes (other than +invoice+, +credit_note+ and +payment+), you should override this
      # method accordingly in those subclasses.
      def debit_when_sent_by_self
        case ledger_item_class_info.subtype
          when :invoice     then true
          when :credit_note then true
          when :payment     then false
          else nil
        end
      end

      # Returns +true+ if this type of ledger item is a +invoice+ subtype, and +false+ otherwise.
      def is_invoice
        ledger_item_class_info.subtype == :invoice
      end

      # Returns +true+ if this type of ledger item is a +credit_note+ subtype, and +false+ otherwise.
      def is_credit_note
        ledger_item_class_info.subtype == :credit_note
      end

      # Returns +true+ if this type of ledger item is a +payment+ subtype, and +false+ otherwise.
      def is_payment
        ledger_item_class_info.subtype == :payment
      end

      #   LedgerItem.sender_recipient_name_map [2, 4]
      #   => {2 => "Fast Flowers Ltd.", 4 => "Speedy Motors"}
      def sender_recipient_name_map(*sender_recipient_ids)
        sender_recipient_ids = sender_recipient_ids.flatten.map &:to_i
        sender_recipient_to_ledger_item_ids = {}
        result_map = {}
        info = ledger_item_class_info

        # Find the most recent occurrence of each ID, first in the sender_id column, then in recipient_id
        [:sender_id, :recipient_id].each do |column|
          column = info.method(column)
          quoted_column = connection.quote_column_name(column)
          sql = "SELECT MAX(#{primary_key}) AS id, #{quoted_column} AS ref FROM #{quoted_table_name} WHERE "
          sql << merge_conditions({column => sender_recipient_ids})
          sql << " GROUP BY #{quoted_column}"

          ActiveRecord::Base.connection.select_all(sql).each do |row|
            sender_recipient_to_ledger_item_ids[row['ref'].to_i] = row['id'].to_i
          end

          sender_recipient_ids -= sender_recipient_to_ledger_item_ids.keys
        end

        # Load all the ledger items needed to get one representative of each name
        find(sender_recipient_to_ledger_item_ids.values.uniq).each do |ledger_item|
          sender_id = info.get(ledger_item, :sender_id)
          recipient_id = info.get(ledger_item, :recipient_id)

          if sender_recipient_to_ledger_item_ids.include? sender_id
            details = info.get(ledger_item, :sender_details)
            result_map[sender_id] = details[:name]
          end
          if sender_recipient_to_ledger_item_ids.include? recipient_id
            details = info.get(ledger_item, :recipient_details)
            result_map[recipient_id] = details[:name]
          end
        end

        result_map
      end

      def inheritance_condition(classes)
        segments = []
        segments << sanitize_sql(inheritance_column => classes)

        if classes.include?(self.to_s) && self.new.send(inheritance_column).nil?
          segments << sanitize_sql(type: nil)
        end

        "(#{segments.join(') OR (')})" unless segments.empty?
      end

      def merge_conditions(*conditions)
        segments = []

        conditions.each do |condition|
          unless condition.blank?
            sql = sanitize_sql(condition)
            segments << sql unless sql.blank?
          end
        end

        "(#{segments.join(') AND (')})" unless segments.empty?
      end
    end # module ClassMethods

    # Stores state in the ActiveRecord class object
    class ClassInfo < Invoicing::ClassInfo::Base #:nodoc:
      attr_reader :subtype, :uuid_generator

      def initialize(model_class, previous_info, args)
        super
        @subtype = all_options[:subtype]

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

  end # module LedgerItem
end
