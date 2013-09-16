module Invoicing
  # = Ledger item objects
  #
  # This module implements a simple ledger, i.e. the record of all of the business transactions
  # which are handled by your application. Each transaction is recorded as one +LedgerItem+ object,
  # each of which may have one of the following three types:
  #
  # +Invoice+::
  #   When you send an invoice to someone (= a customer), this is a record of the fact
  #   that you have sold them something (a product, a service etc.), and how much you expect to be
  #   paid for it. An invoice can consist of a list of individual charges, but it is considered as
  #   one document for legal purposes. You can also create invoices from someone else to yourself,
  #   if you owe someone else money -- for example, if you need to pay commissions to a reseller of
  #   your application.
  # +CreditNote+::
  #   This is basically a invoice for a negative amount; you should use it if you have previously
  #   sent a customer an invoice with an amount which was too great (i.e. you have overcharged them).
  #   The numeric values stored in the database for a credit note are negative, to make it easier to
  #   calculate account summaries, but they may be formatted as positive values when presented to
  #   users if that is customary in your country. For example, if you send a customer an invoice
  #   with a +total_amount+ of $20 and a credit note with a +total_amount+ of -$10, that means that
  #   overall you're asking them to pay $10.
  # +Payment+::
  #   This is a record of the fact that a payment has been made. It's a simple object, in effect just
  #   saying that party A paid amount X to party B on date Y. This module does not implement any
  #   particular payment mechanism such as credit card handling, although it could be implemented on
  #   top of a +Payment+ object.
  #
  # == Important principles
  #
  # Note the distinction between Invoices/Credit Notes and Payments; to keep your accounts clean,
  # it is important that you do not muddle these up.
  #
  # * <b>Invoices and Credit Notes</b> are the important documents for tax purposes in most
  #   jurisdictions. They record the date on which the sale is officially made, and that date
  #   determines which tax rates apply. An invoice often also represents the transfer of ownership from
  #   the supplier to the customer; for example, if you ask your customers to send payment in
  #   advance (such as 'topping up' their account), that money still belongs to your customer
  #   until the point where they have used your service, and you have charged them for your
  #   service by sending them an invoice. You should only invoice them for what they have actually
  #   used, then the remaining balance will automatically be retained on their account.
  # * <b>Payments</b> are just what it says on the tin -- the transfer of money from one hand
  #   to another. A payment may occur before an invoice is issued (payment in advance), or
  #   after/at the same time as an invoice is issued to settle the debt (payment in arrears, giving
  #   your customers credit). You can choose whatever makes sense for your business.
  #   Payments may often be associated one-to-one with invoices, but not necessarily -- an invoice
  #   may be paid in instalments, or several invoices may be lumped together to one payment. Your
  #   customer may even refuse to pay some charges, in which case there is an invoice but no payment
  #   (until at some point you either reverse it with a credit note, or write it off as bad debt,
  #   but that's beyond our scope right now).
  #
  # Another very important principle is that once a piece of information has been added to the
  # ledger, you <b>should not modify or delete it</b>. Particularly when you have 'sent' one of your
  # customers or suppliers a document (which may mean simply that they have seen it on the web) you should
  # not change it again, because they might have added that information to their own accounting system.
  # Changing any information is guaranteed to lead to confusion. (The model objects do not restrict your
  # editing capabilities because they might be necessary in specific circumstances, but you should be
  # extremely careful when changing anything.)
  #
  # Of course you make mistakes or change your mind, but please deal with them cleanly:
  # * If you create an invoice whose value is too small, don't amend the invoice, but send them
  #   another invoice to cover the remaining amount.
  # * If you create an invoice whose value is too great (for example because you want to offer one
  #   customer a special discount), don't amend the invoice, but send them a credit note to waive
  #   your claim to the difference.
  # * If you create a payment, mark it as +pending+ until it the money has actually arrived.
  #   If it never arrives, keep the record but mark it as +failed+ in case you need to investigate
  #   it later.
  #
  # The exception to the 'no modifications' rule are invoices on which you accumulate charges
  # (e.g. over the course of a month)
  # and then officially 'send' the invoice at the end of the period. In this gem we call such
  # invoices +open+ while they may still be changed. It's ok to add charges to +open+ invoices
  # as you go along; while it is +open+ it is not legally an invoice, but only a statement
  # of accumulated charges. If you display it to users, make sure that you don't call it "invoice",
  # to avoid confusion. Only when you set it to +closed+ at the end of the month does the
  # statement become an invoice for legal purposes. Once it's +closed+ you must not add
  # any further charges to it.
  #
  # Finally, each ledger item has a sender and a recipient; typically one of the two will be
  # <b>you</b> (the person/organsation who owns/operates the application):
  # * For invoices, credit notes and payments between you and your customers, set the sender
  #   to be yourself and the recipient to be your customer;
  # * If you use this system to record suppliers, set the sender to be your supplier and the
  #   recipient to be yourself.
  # (See below for details.) It is perfectly ok to have documents which are sent between your
  # users, where you are neither sender nor recipient; this may be useful if you want to allow
  # users to trade directly with each other.
  #
  # == Using invoices, credit notes and payments in your application
  #
  # All invoices, credit notes and payments (collectively called 'ledger items') are stored in a
  # single database table. We use <b>single table inheritance</b> to distinguish the object types.
  # You need to create at least the following four model classes in your application:
  #
  #   class LedgerItem < ActiveRecord::Base
  #     acts_as_ledger_item
  #   end
  #
  #   class Invoice < LedgerItem                      # Base class for all types of invoice
  #     acts_as_ledger_item :subtype => :invoice
  #   end
  #
  #   class CreditNote < LedgerItem                   # Base class for all types of credit note
  #     acts_as_ledger_item :subtype => :credit_note
  #   end
  #
  #   class Payment < LedgerItem                      # Base class for all types of payment
  #     acts_as_ledger_item :subtype => :payment
  #   end
  #
  # You may give the classes different names than these, and you can package them in modules if
  # you wish, but they need to have the <tt>:subtype => ...</tt> option parameters as above.
  #
  # You can create as many subclasses as you like of each of Invoice, CreditNote and Payment. This
  # provides a convenient mechanism for encapsulating different types of functionality which you
  # may need for different types of transactions, but still keeping the accounts in one place. You
  # may start with only one subclass of +Invoice+ (e.g. <tt>class MonthlyChargesInvoice < Invoice</tt>
  # to bill users for their use of your application; but as you want to do more clever things, you
  # can add other subclasses of +Invoice+ as and when you need them (such as +ConsultancyServicesInvoice+
  # and +SalesCommissionInvoice+, for example). Similarly for payments, you may have subclasses
  # representing credit card payments, cash payments, bank transfers etc.
  #
  # Please note that the +Payment+ ledger item type does not itself implement any particular
  # payment methods such as credit card handling; however, for third-party libraries providing
  # credit card handling, this would be a good place to integrate.
  #
  # The model classes must have a certain minimum set of columns and a few common methods, documented
  # below (although you may rename any of them if you wish). Beyond those, you may add other methods and
  # database columns for your application's own needs, provided they don't interfere with names used here.
  #
  # == Required methods/database columns
  #
  # The following methods/database columns are <b>required</b> for +LedgerItem+ objects (you may give them
  # different names, but then you need to tell +acts_as_ledger_item+ about your custom names):
  #
  # +type+::
  #   String to store the class name, for ActiveRecord single table inheritance.
  #
  # +sender_id+::
  #   Integer-valued foreign key, used to refer to some other model object representing the party
  #   (person, company etc.) who is the sender of the transaction.
  #   - In the case of an invoice or credit note, the +sender_id+ identifies the supplier of the product or service,
  #     i.e. the person who is owed the amount specified on the invoice, also known as the creditor.
  #   - In the case of a payment record, the +sender_id+ identifies the payee, i.e. the person who sends the note
  #     confirming that they received payment.
  #   - This field may be +NULL+ to refer to yourself (i.e. the company/person who owns or
  #     operates this application), but you may also use non-+NULL+ values to refer to yourself. It's just
  #     important that you consistently refer to the same party by the same value in different ledger items.
  #
  # +recipient_id+::
  #   The counterpart to +sender_id+: foreign key to a model object which represents the
  #   party who is the recipient of the transaction.
  #   - In the case of an invoice or credit note, the +recipient_id+ identifies the customer/buyer of the product or
  #     service, i.e. the person who owes the amount specified on the invoice, also known as the debtor.
  #   - In the case of a payment record, the +recipient_id+ identifies the payer, i.e. the recipient of the
  #     payment receipt.
  #   - +NULL+ may be used as in +sender_id+.
  #
  # +sender_details+::
  #   A method (does not have to be a database column) which returns a hash with information
  #   about the party identified by +sender_id+. See the documentation of +sender_details+ for the expected
  #   contents of the hash. Must always return valid details, even if +sender_id+ is +NULL+.
  #
  # +recipient_details+::
  #   A method (does not have to be a database column) which returns a hash with information
  #   about the party identified by +recipient_id+. See the documentation of +sender_details+ for the expected
  #   contents of the hash (+recipient_details+ uses the same format as +sender_details+). Must always
  #   return valid details, even if +recipient_id+ is +NULL+.
  #
  # +identifier+::
  #   A number or string used to identify this record, i.e. the invoice number, credit note number or
  #   payment receipt number as appropriate.
  #   - There may be legal requirements in your country concerning its format, but as long as it uniquely identifies
  #     the document within your organisation you should be safe.
  #   - It's possible to simply make this an alias of the primary key, but it's strongly recommended that you use a
  #     separate database column. If you ever need to generate invoices on behalf of other people (i.e. where
  #     +sender_id+ is not you), you need to give the sender of the invoice the opportunity to enter their own
  #     +identifier+ (because it then must be unique within the sender's organisation, not yours).
  #
  # +issue_date+::
  #   A datetime column which indicates the date on which the document is issued, and which may also
  #   serve as the tax point (the date which determines which tax rate is applied). This should be a separate
  #   column, because it won't necessarily be the same as +created_at+ or +updated_at+. There may be business
  #   reasons for choosing particular dates, but the date at which you send the invoice or receive the payment
  #   should do unless your accountant advises you otherwise.
  #
  # +currency+::
  #   The 3-letter code which identifies the currency used in this transaction; must be one of the list
  #   of codes in ISO-4217[http://en.wikipedia.org/wiki/ISO_4217]. (Even if you only use one currency throughout
  #   your site, this is needed to format monetary amounts correctly.)
  #
  # +total_amount+::
  #   A decimal column containing the grand total monetary sum (of the invoice or credit note), or the monetary
  #   amount paid (of the payment record), including all taxes, charges etc. For invoices and credit notes, a
  #   +before_validation+ filter is automatically invoked, which adds up the +net_amount+ and +tax_amount+ values
  #   of all line items and assigns that sum to +total_amount+. For payment records, which do not usually have
  #   line items, you must assign the correct value to this column. See the documentation of the +CurrencyValue+
  #   module for notes on suitable datatypes for monetary values. +acts_as_currency_value+ is automatically applied
  #   to this attribute.
  #
  # +tax_amount+::
  #   If you're a small business you maybe don't need to add tax to your invoices; but if you are successful,
  #   you almost certainly will need to do so eventually. In most countries this takes the form of Value Added
  #   Tax (VAT) or Sales Tax. For invoices and credit notes, you must store the amount of tax in this table;
  #   a +before_validation+ filter is automatically invoked, which adds up the +tax_amount+ values of all
  #   line items and assigns that sum to +total_amount+. For payment records this should be zero (unless you
  #   use a cash accounting scheme, which is currently not supported). See the documentation of the
  #   +CurrencyValue+ module for notes on suitable datatypes for monetary values. +acts_as_currency_value+ is
  #   automatically applied to this attribute.
  #
  # +status+::
  #   A string column used to keep track of the status of ledger items. Currently the following values are defined
  #   (but future versions may add further +status+ values):
  #   +open+::      For invoices/credit notes: the document is not yet finalised, further line items may be added.
  #   +closed+::    For invoices/credit notes: the document has been sent to the recipient and will not be changed again.
  #   +cancelled+:: For invoices/credit notes: the document has been declared void and does not count towards accounts.
  #                 (Use this sparingly; if you want to refund an invoice that has been sent, send a credit note.)
  #   +pending+::   For payments: payment is expected or has been sent, but has not yet been confirmed as received.
  #   +cleared+::   For payments: payment has completed successfully.
  #   +failed+::    For payments: payment did not succeed; this record is not counted towards accounts.
  #
  # +description+::
  #   A method which returns a short string describing what this invoice, credit note or payment is about.
  #   Can be a database column but doesn't have to be.
  #
  # +line_items+::
  #   You should define an association <tt>has_many :line_items, ...</tt> referring to the +LineItem+ objects
  #   associated with this ledger item.
  #
  #
  # == Optional methods/database columns
  #
  # The following methods/database columns are <b>optional, but recommended</b> for +LedgerItem+ objects:
  #
  # +period_start+, +period_end+::
  #   Two datetime columns which define the period of time covered by an invoice or credit note. If the thing you
  #   are selling is a one-off, you can omit these columns or leave them as +NULL+. However, if there is any sort
  #   of duration associated with an invoice/credit note (e.g. charges incurred during a particular month, or
  #   an annual subscription, or a validity period of a license, etc.), please store that period here. It's
  #   important for accounting purposes. (For +Payment+ objects it usually makes most sense to just leave these
  #   as +NULL+.)
  #
  # +uuid+::
  #   A Universally Unique Identifier (UUID)[http://en.wikipedia.org/wiki/UUID] string for this invoice, credit
  #   note or payment. It may seem unnecessary now, but may help you to keep track of your data later on as
  #   your system grows. If you have the +uuid+ gem installed and this column is present, a UUID is automatically
  #   generated when you create a new ledger item.
  #
  # +due_date+::
  #   The date at which the invoice or credit note is due for payment. +nil+ on +Payment+ records.
  #
  # +created_at+, +updated_at+::
  #   The standard ActiveRecord datetime columns for recording when an object was created and last changed.
  #   The values are not directly used at the moment, but it's useful information in case you need to track down
  #   a particular transaction sometime; and ActiveRecord manages them for you anyway.
  #
  #
  # == Generated methods
  #
  # In return for providing +LedgerItem+ with all the required information as documented above, you are given
  # a number of class and instance methods which you will find useful sooner or later. In addition to those
  # documented in this module (instance methods) and <tt>Invoicing::LedgerItem::ClassMethods</tt>
  # (class methods), the following methods are generated dynamically:
  #
  # +sent_by+::     Named scope which takes a person/company ID and matches all ledger items whose
  #                 +sender_id+ matches that value.
  # +received_by+:: Named scope which takes a person/company ID and matches all ledger items whose
  #                 +recipient_id+ matches that value.
  # +sent_or_received_by+:: Union of +sent_by+ and +received_by+.
  # +in_effect+::   Named scope which matches all closed invoices/credit notes (not open or cancelled)
  #                 and all cleared payments (not pending or failed). You probably want to use this
  #                 quite often, for all reporting purposes.
  # +open_or_pending+::     Named scope which matches all open invoices/credit notes and all pending
  #                         payments.
  # +due_at+::      Named scope which takes a +DateTime+ argument and matches all ledger items whose
  #                 +due_date+ value is either +NULL+ or is not after the given time. For example,
  #                 you could run <tt>LedgerItem.due_at(Time.now).account_summaries</tt>
  #                 once a day and process payment for all accounts whose balance is not zero.
  # +sorted+::      Named scope which takes a column name as documented above (even if it has been
  #                 renamed), and sorts the query by that column. If the column does not exist,
  #                 silently falls back to sorting by the primary key.
  # +exclude_empty_invoices+:: Named scope which excludes any invoices or credit notes which do not
  #                            have any associated line items (payments without line items are
  #                            included though). If you're chaining scopes it would be advantageous
  #                            to put this one close to the beginning of your scope chain.
  module LedgerItem

    module ActMethods
      # Declares that the current class is a model for ledger items (i.e. invoices, credit notes and
      # payment notes).
      #
      # This method accepts a hash of options, all of which are optional:
      # <tt>:subtype</tt>:: One of <tt>:invoice</tt>, <tt>:credit_note</tt> or <tt>:payment</tt>.
      #
      # Also, the name of any attribute or method required by +LedgerItem+ (as documented on the
      # +LedgerItem+ module) may be used as an option, with the value being the name under which
      # that particular method or attribute can be found. This allows you to use names other than
      # the defaults. For example, if your database column storing the invoice value is called
      # +gross_amount+ instead of +total_amount+:
      #
      #   acts_as_ledger_item :total_amount => :gross_amount
      def acts_as_ledger_item(*args)
        Invoicing::ClassInfo.acts_as(Invoicing::LedgerItem, self, args)

        info = ledger_item_class_info
        return unless info.previous_info.nil? # Called for the first time?

        before_validation :calculate_total_amount

        # Set the 'amount' columns to act as currency values
        acts_as_currency_value(info.method(:total_amount), info.method(:tax_amount),
          :currency => info.method(:currency), :value_for_formatting => :value_for_formatting)

        extend Invoicing::FindSubclasses
        include Invoicing::LedgerItem::RenderHTML
        include Invoicing::LedgerItem::RenderUBL

        # Dynamically created named scopes
        scope :sent_by, lambda{ |sender_id|
          { :conditions => {info.method(:sender_id) => sender_id} }
        }

        scope :received_by, lambda{ |recipient_id|
          { :conditions => {info.method(:recipient_id) => recipient_id} }
        }

        scope :sent_or_received_by, lambda{ |sender_or_recipient_id|
          sender_col = connection.quote_column_name(info.method(:sender_id))
          recipient_col = connection.quote_column_name(info.method(:recipient_id))
          { :conditions => ["#{sender_col} = ? OR #{recipient_col} = ?",
                            sender_or_recipient_id, sender_or_recipient_id] }
        }

        scope :in_effect, lambda {
          { :conditions => {info.method(:status) => ['closed', 'cleared']} }
        }

        scope :open_or_pending, lambda {
          { :conditions => {info.method(:status) => ['open', 'pending']} }
        }

        scope :due_at, lambda{ |date|
          due_date = connection.quote_column_name(info.method(:due_date))
          where(["#{due_date} <= ? OR #{due_date} IS NULL", date])
        }

        scope :sorted, lambda{|column|
          column = ledger_item_class_info.method(column).to_s
          if column_names.include?(column)
            {:order => "#{connection.quote_column_name(column)}, #{connection.quote_column_name(primary_key)}"}
          else
            {:order => connection.quote_column_name(primary_key)}
          end
        }

        scope :exclude_empty_invoices, lambda{
          line_items_assoc_id = info.method(:line_items).to_sym
          line_items_refl = reflections[line_items_assoc_id]
          line_items_table = line_items_refl.quoted_table_name

          # e.g. `ledger_items`.`id`
          ledger_items_id = quoted_table_name + "." + connection.quote_column_name(primary_key)

          # e.g. `line_items`.`id`
          line_items_id = line_items_table + "." +
            connection.quote_column_name(line_items_refl.klass.primary_key)

          # e.g. `line_items`.`ledger_item_id`
          ledger_item_foreign_key = line_items_table + "." + connection.quote_column_name(
            line_items_refl.klass.send(:line_item_class_info).method(:ledger_item_id))

          payment_classes = select_matching_subclasses(:is_payment, true).map{|c| c.name}
          is_payment_class = merge_conditions({info.method(:type) => payment_classes})

          joins("LEFT JOIN #{line_items_table} ON #{ledger_item_foreign_key} = #{ledger_items_id}").
          where("(#{ledger_item_foreign_key} IS NULL) OR #{is_payment_class}")
        }
      end # def acts_as_ledger_item

      # Synonym for <tt>acts_as_ledger_item :subtype => :invoice</tt>. All options other than
      # <tt>:subtype</tt> are passed on to +acts_as_ledger_item+. You should apply
      # +acts_as_invoice+ only to a model which is a subclass of an +acts_as_ledger_item+ type.
      def acts_as_invoice(options={})
        acts_as_ledger_item(options.clone.update({:subtype => :invoice}))
      end

      # Synonym for <tt>acts_as_ledger_item :subtype => :credit_note</tt>. All options other than
      # <tt>:subtype</tt> are passed on to +acts_as_ledger_item+. You should apply
      # +acts_as_credit_note+ only to a model which is a subclass of an +acts_as_ledger_item+ type.
      def acts_as_credit_note(options={})
        acts_as_ledger_item(options.clone.update({:subtype => :credit_note}))
      end

      # Synonym for <tt>acts_as_ledger_item :subtype => :payment</tt>. All options other than
      # <tt>:subtype</tt> are passed on to +acts_as_ledger_item+. You should apply
      # +acts_as_payment+ only to a model which is a subclass of an +acts_as_ledger_item+ type.
      def acts_as_payment(options={})
        acts_as_ledger_item(options.clone.update({:subtype => :payment}))
      end
    end # module ActMethods

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

    # We don't actually implement anything using +method_missing+ at the moment, but use it to
    # generate slightly more useful error messages in certain cases.
    def method_missing(method_id, *args)
      method_name = method_id.to_s
      if ['line_items', ledger_item_class_info.method(:line_items)].include? method_name
        raise RuntimeError, "You need to define an association like 'has_many :line_items' on #{self.class.name}. If you " +
          "have defined the association with a different name, pass the option :line_items => :your_association_name to " +
          "acts_as_ledger_item."
      else
        super
      end
    end

    # The difference +total_amount+ minus +tax_amount+.
    def net_amount
      total_amount = ledger_item_class_info.get(self, :total_amount)
      tax_amount   = ledger_item_class_info.get(self, :tax_amount)
      (total_amount && tax_amount) ? (total_amount - tax_amount) : nil
    end

    # +net_amount+ formatted in human-readable form using the ledger item's currency.
    def net_amount_formatted
      format_currency_value(net_amount)
    end


    # You must overwrite this method in subclasses of +Invoice+, +CreditNote+ and +Payment+ so that it returns
    # details of the party sending the document. See +sender_id+ above for a detailed interpretation of
    # sender and receiver.
    #
    # The methods +sender_details+ and +recipient_details+ are required to return hashes
    # containing details about the sender and recipient of an invoice, credit note or payment. The reason we
    # do this is that you probably already have your own system for handling users, customers and their personal
    # or business details, and this framework shouldn't require you to change any of that.
    #
    # The invoicing framework currently uses these details only for rendering invoices and credit notes, but
    # in future it may serve more advanced purposes, such as determining which tax rate to apply for overseas
    # customers.
    #
    # In the hash returned by +sender_details+ and +recipient_details+, the following keys are recognised --
    # please fill in as many as possible:
    # <tt>:is_self</tt>::      +true+ if these details refer to yourself, i.e. the person or organsiation who owns/operates
    #                          this application. +false+ if these details refer to any other party.
    # <tt>:name</tt>::         The name of the person or organisation whose billing address is defined below.
    # <tt>:contact_name</tt>:: The name of a person/department within the organisation named by <tt>:name</tt>.
    # <tt>:address</tt>::      The body of the billing address (not including city, postcode, state and country); may be
    #                          a multi-line string, with lines separated by '\n' line breaks.
    # <tt>:city</tt>::         The name of the city or town in the billing address.
    # <tt>:state</tt>::        The state/region/province/county of the billing address as appropriate.
    # <tt>:postal_code</tt>::  The postal code of the billing address (e.g. ZIP code in the US).
    # <tt>:country</tt>::      The billing address country (human-readable).
    # <tt>:country_code</tt>:: The two-letter country code of the billing address, according to
    #                          ISO-3166-1[http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2].
    # <tt>:tax_number</tt>::   The Value Added Tax registration code of this person or organisation, if they have
    #                          one, preferably including the country identifier at the beginning. This is important for
    #                          transactions within the European Union.
    def sender_details
      raise 'overwrite this method'
    end

    # You must overwrite this method in subclasses of +Invoice+, +CreditNote+ and +Payment+ so that it returns
    # details of the party receiving the document. See +recipient_id+ above for a detailed interpretation of
    # sender and receiver. See +sender_details+ for a list of fields to return in the hash.
    def recipient_details
      raise 'overwrite this method'
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

    # Returns a boolean which specifies whether this transaction should be recorded as a debit (+true+)
    # or a credit (+false+) on a particular ledger. Unless you know what you are doing, you probably
    # do not need to touch this method.
    #
    # It takes an argument +self_id+, which should be equal to either +sender_id+ or +recipient_id+ of this
    # object, and which determines from which perspective the account is viewed. The default behaviour is:
    # * A sent invoice (<tt>self_id == sender_id</tt>) is a debit since it increases the recipient's
    #   liability; a sent credit note decreases the recipient's liability with a negative-valued
    #   debit; a sent payment receipt is a positive-valued credit and thus decreases the recipient's
    #   liability.
    # * A received invoice (<tt>self_id == recipient_id</tt>) is a credit because it increases your own
    #   liability; a received credit note decreases your own liability with a negative-valued credit;
    #   a received payment receipt is a positive-valued debit and thus decreases your own liability.
    #
    # Note that accounting practices differ with regard to credit notes: some think that a sent
    # credit note should be recorded as a positive credit (hence the name 'credit note'); others
    # prefer to use a negative debit. We chose the latter because it allows you to calculate the
    # total sale volume on an account simply by adding up all the debits. If there is enough demand
    # for the positive-credit model, we may add support for it sometime in future.
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

      # Returns a summary of the customer or supplier account between two parties identified
      # by +self_id+ (the party from whose perspective the account is seen, 'you') and +other_id+
      # ('them', your supplier/customer). The return value is a hash with ISO 4217 currency codes
      # as keys (as symbols), and summary objects as values. An account using only one currency
      # will have only one entry in the hash, but more complex accounts may have several.
      #
      # The summary object has the following methods:
      #
      #   currency          => symbol           # Same as the key of this hash entry
      #   sales             => BigDecimal(...)  # Sum of sales (invoices sent by self_id)
      #   purchases         => BigDecimal(...)  # Sum of purchases (invoices received by self_id)
      #   sale_receipts     => BigDecimal(...)  # Sum of payments received from customer
      #   purchase_payments => BigDecimal(...)  # Sum of payments made to supplier
      #   balance           => BigDecimal(...)  # sales - purchases - sale_receipts + purchase_payments
      #
      # The <tt>:balance</tt> fields indicate any outstanding money owed on the account: the value is
      # positive if they owe you money, and negative if you owe them money.
      #
      # In addition, +acts_as_currency_value+ is set on the numeric fields, so you can use its
      # convenience methods such as +summary.sales_formatted+.
      #
      # If +other_id+ is +nil+, this method aggregates the accounts of +self_id+ with *all* other
      # parties.
      #
      # Also accepts options:
      #
      # <tt>:with_status</tt>:: List of ledger item status strings; only ledger items whose status
      #                         is one of these will be taken into account. Default:
      #                         <tt>["closed", "cleared"]</tt>.
      def account_summary(self_id, other_id=nil, options={})
        info = ledger_item_class_info
        self_id = self_id.to_i
        other_id = [nil, ''].include?(other_id) ? nil : other_id.to_i

        if other_id.nil?
          result = {}
          # Sum over all others, grouped by currency
          account_summaries(self_id, options).each_pair do |other_id, hash|
            hash.each_pair do |currency, summary|
              if result[currency]
                result[currency] += summary
              else
                result[currency] = summary
              end
            end
          end
          result
        else
          conditions = {info.method(:sender_id)    => [self_id, other_id],
                        info.method(:recipient_id) => [self_id, other_id]}
          where(conditions).account_summaries(self_id, options)[other_id] || {}
        end
      end

      # Returns a summary account status for all customers or suppliers with which a particular party
      # has dealings. Takes into account all +closed+ invoices/credit notes and all +cleared+ payments
      # which have +self_id+ as their +sender_id+ or +recipient_id+. Returns a hash whose keys are the
      # other party of each account (i.e. the value of +sender_id+ or +recipient_id+ which is not
      # +self_id+, as an integer), and whose values are again hashes, of the same form as returned by
      # +account_summary+ (+summary+ objects as documented on +account_summary+):
      #
      #   LedgerItem.account_summaries(1)
      #     # => { 2 => { :USD => summary, :EUR => summary },
      #     #      3 => { :EUR => summary } }
      #
      # If you want to further restrict the ledger items taken into account in this calculation (e.g.
      # include only data from a particular quarter) you can call this method within an ActiveRecord
      # scope:
      #
      #   q3_2008 = ['issue_date >= ? AND issue_date < ?', DateTime.parse('2008-07-01'), DateTime.parse('2008-10-01')]
      #   LedgerItem.scoped(:conditions => q3_2008).account_summaries(1)
      #
      #
      # Also accepts options:
      #
      # <tt>:with_status</tt>:: List of ledger item status strings; only ledger items whose status
      #                         is one of these will be taken into account. Default:
      #                         <tt>["closed", "cleared"]</tt>.
      def account_summaries(self_id, options={})
        info = ledger_item_class_info
        ext = Invoicing::ConnectionAdapterExt

        debit_classes  = select_matching_subclasses(:debit_when_sent_by_self, true,  self.table_name, self.inheritance_column).map{|c| c.name}
        credit_classes = select_matching_subclasses(:debit_when_sent_by_self, false, self.table_name, self.inheritance_column).map{|c| c.name}
        debit_when_sent      = merge_conditions({info.method(:sender_id)    => self_id, info.method(:type) => debit_classes})
        debit_when_received  = merge_conditions({info.method(:recipient_id) => self_id, info.method(:type) => credit_classes})
        credit_when_sent     = merge_conditions({info.method(:sender_id)    => self_id, info.method(:type) => credit_classes})
        credit_when_received = merge_conditions({info.method(:recipient_id) => self_id, info.method(:type) => debit_classes})

        cols = {}
        [:total_amount, :sender_id, :recipient_id, :status, :currency].each do |col|
          cols[col] = connection.quote_column_name(info.method(col))
        end

        sender_is_self    = merge_conditions({info.method(:sender_id)    => self_id})
        recipient_is_self = merge_conditions({info.method(:recipient_id) => self_id})
        other_id_column = ext.conditional_function(sender_is_self, cols[:recipient_id], cols[:sender_id])
        accept_status = merge_conditions(info.method(:status) => (options[:with_status] || %w(closed cleared)))
        filter_conditions = "#{accept_status} AND (#{sender_is_self} OR #{recipient_is_self})"

        sql = select("#{other_id_column} AS other_id, #{cols[:currency]} AS currency, " +
          "SUM(#{ext.conditional_function(debit_when_sent,      cols[:total_amount], 0)}) AS sales, " +
          "SUM(#{ext.conditional_function(debit_when_received,  cols[:total_amount], 0)}) AS purchase_payments, " +
          "SUM(#{ext.conditional_function(credit_when_sent,     cols[:total_amount], 0)}) AS sale_receipts, " +
          "SUM(#{ext.conditional_function(credit_when_received, cols[:total_amount], 0)}) AS purchases ")

        sql = sql.where(filter_conditions)
        sql = sql.group("other_id, currency")

        # add order, limit, and lock from outside
        rows = connection.execute(sql.to_sql).to_a

        results = {}
        rows.each do |row|
          row.symbolize_keys!
          other_id = row[:other_id].to_i
          currency = row[:currency].to_sym
          summary = {:balance => BigDecimal('0'), :currency => currency}

          {:sales => 1, :purchases => -1, :sale_receipts => -1, :purchase_payments => 1}.each_pair do |field, factor|
            summary[field] = BigDecimal(row[field].to_s)
            summary[:balance] += BigDecimal(factor.to_s) * summary[field]
          end

          results[other_id] ||= {}
          results[other_id][currency] = AccountSummary.new summary
        end

        results
      end

      # Takes an array of IDs like those used in +sender_id+ and +recipient_id+, and returns a hash
      # which maps each of these IDs (typecast to integer) to the <tt>:name</tt> field of the
      # hash returned by +sender_details+ or +recipient_details+ for that ID. This is useful as it
      # allows +LedgerItem+ to use human-readable names for people or organisations in its output,
      # without depending on a particular implementation of the model objects used to store those
      # entities.
      #
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


    # Very simple class for representing the sum of all sales, purchases and payments on
    # an account.
    class AccountSummary #:nodoc:
      NUM_FIELDS = [:sales, :purchases, :sale_receipts, :purchase_payments, :balance]
      attr_reader *([:currency] + NUM_FIELDS)

      def initialize(hash)
        @currency = hash[:currency]; @sales = hash[:sales]; @purchases = hash[:purchases]
        @sale_receipts = hash[:sale_receipts]; @purchase_payments = hash[:purchase_payments]
        @balance = hash[:balance]
      end

      def method_missing(name, *args)
        if name.to_s =~ /(.*)_formatted$/
          ::Invoicing::CurrencyValue::Formatter.format_value(currency, send($1))
        else
          super
        end
      end

      def +(other)
        hash = {:currency => currency}
        NUM_FIELDS.each {|field| hash[field] = send(field) + other.send(field) }
        AccountSummary.new hash
      end

      def to_s
        NUM_FIELDS.map do |field|
          val = send("#{field}_formatted")
          "#{field} = #{val}"
        end.join('; ')
      end
    end


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
