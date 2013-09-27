require "active_support/concern"
require 'builder'

module Invoicing
  module LedgerItem
    # Included into ActiveRecord model object when +acts_as_ledger_item+ is invoked.
    module RenderUBL
      extend ActiveSupport::Concern

      # Renders this invoice or credit note into a complete XML document conforming to the
      # {OASIS Universal Business Language}[http://ubl.xml.org/] (UBL) open standard for interchange
      # of business documents ({specification}[http://www.oasis-open.org/committees/ubl/]). This
      # format, albeit a bit verbose, is increasingly being adopted as an international standard. It
      # can represent some very complicated multi-currency, multi-party business relationships, but
      # is still quite usable for simple cases.
      #
      # It is recommended that you present machine-readable UBL data in your application in the
      # same way as you present human-readable invoices in HTML. For example, in a Rails controller,
      # you could use:
      #
      #   class AccountsController < ApplicationController
      #     def show
      #       @ledger_item = LedgerItem.find(params[:id])
      #       # ... check whether current user has access to this document ...
      #       respond_to do |format|
      #         format.html # show.html.erb
      #         format.xml  { render :xml => @ledger_item.render_ubl }
      #       end
      #     end
      #   end
      def render_ubl(options={})
        UBLOutputBuilder.new(self, options).build
      end


      class UBLOutputBuilder #:nodoc:
        # XML Namespaces required by UBL
        UBL_NAMESPACES = {
          "xmlns:cac" => "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
          "xmlns:cbc" => "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"
        }

        UBL_DOC_NAMESPACES = {
          :Invoice              => "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
          :SelfBilledInvoice    => "urn:oasis:names:specification:ubl:schema:xsd:SelfBilledInvoice-2",
          :CreditNote           => "urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2",
          :SelfBilledCreditNote => "urn:oasis:names:specification:ubl:schema:xsd:SelfBilledCreditNote-2"
        }

        attr_reader :ledger_item, :options, :cached_values, :doc_type, :factor

        def initialize(ledger_item, options)
          @ledger_item = ledger_item
          @options = options
          @cached_values = {}
          subtype = ledger_item.send(:ledger_item_class_info).subtype
          @doc_type =
            if [:invoice, :credit_note].include? subtype
              if total_amount >= BigDecimal('0')
                @factor = BigDecimal('1')
                sender_details.symbolize_keys[:is_self] ? :Invoice : :SelfBilledInvoice
              else
                @factor = BigDecimal('-1')
                sender_details.symbolize_keys[:is_self] ? :CreditNote : :SelfBilledCreditNote
              end
            else
              raise RuntimeError, "render_ubl not implemented for ledger item subtype #{subtype.inspect}"
            end
        end

        # For convenience while building the XML structure, method_missing redirects method calls
        # to the ledger item (taking account of method renaming via acts_as_ledger_item options);
        # calls to foo_of(line_item) are redirected to line_item.foo (taking account of method
        # renaming via acts_as_line_item options).
        def method_missing(method_id, *args, &block)
          method_id = method_id.to_sym
          if method_id.to_s =~ /^(.*)_of$/
            method_id = $1.to_sym
            line_item = args[0]
            line_item.send(:line_item_class_info).get(line_item, method_id)
          else
            cached_values[method_id] ||= ledger_item.send(:ledger_item_class_info).get(ledger_item, method_id)
          end
        end

        # Returns a UBL XML rendering of the ledger item previously passed to the constructor.
        def build
          ubl = Builder::XmlMarkup.new :indent => 4
          ubl.instruct! :xml

          ubl.ubl doc_type, UBL_NAMESPACES.clone.update({'xmlns:ubl' => UBL_DOC_NAMESPACES[doc_type]}) do |invoice|
            invoice.cbc :ID, identifier
            invoice.cbc :UUID, uuid if uuid

            issue_date_formatted, issue_time_formatted = date_and_time(issue_date || Time.now)
            invoice.cbc :IssueDate, issue_date_formatted
            invoice.cbc :IssueTime, issue_time_formatted

            # Different document types have the child elements InvoiceTypeCode, Note and
            # TaxPointDate in a different order. WTF?!
            if doc_type == :Invoice
              invoice.cbc :InvoiceTypeCode, method_missing(:type)
              invoice.cbc :Note, description
              invoice.cbc :TaxPointDate, issue_date_formatted
            else
              invoice.cbc :TaxPointDate, issue_date_formatted
              invoice.cbc :InvoiceTypeCode, method_missing(:type) if doc_type == :SelfBilledInvoice
              invoice.cbc :Note, description
            end

            invoice.cac :InvoicePeriod do |invoice_period|
              build_period(invoice_period, period_start, period_end)
            end if period_start && period_end

            if [:Invoice, :CreditNote].include?(doc_type)

              invoice.cac :AccountingSupplierParty do |supplier|
                build_party supplier, sender_details
              end
              invoice.cac :AccountingCustomerParty do |customer|
                customer.cbc :SupplierAssignedAccountID, recipient_id
                build_party customer, recipient_details
              end

            elsif [:SelfBilledInvoice, :SelfBilledCreditNote].include?(doc_type)

              invoice.cac :AccountingCustomerParty do |customer|
                build_party customer, recipient_details
              end
              invoice.cac :AccountingSupplierParty do |supplier|
                supplier.cbc :CustomerAssignedAccountID, sender_id
                build_party supplier, sender_details
              end

            end

            invoice.cac :PaymentTerms do |payment_terms|
              payment_terms.cac :SettlementPeriod do |settlement_period|
                build_period(settlement_period, issue_date || Time.now, due_date)
              end
            end if due_date && [:Invoice, :SelfBilledInvoice].include?(doc_type)

            invoice.cac :TaxTotal do |tax_total|
              tax_total.cbc :TaxAmount, (factor*tax_amount).to_s, :currencyID => currency
            end if tax_amount

            invoice.cac :LegalMonetaryTotal do |monetary_total|
              monetary_total.cbc :TaxExclusiveAmount, (factor*(total_amount - tax_amount)).to_s,
                :currencyID => currency if tax_amount
              monetary_total.cbc :PayableAmount, (factor*total_amount).to_s, :currencyID => currency
            end

            line_items.sorted(:tax_point).each do |line_item|
              line_tag = if [:CreditNote, :SelfBilledCreditNote].include? doc_type
                :CreditNoteLine
              else
                :InvoiceLine
              end

              invoice.cac line_tag do |invoice_line|
                build_line_item(invoice_line, line_item)
              end
            end
          end
          ubl.target!
        end


        # Given a <tt>Builder::XmlMarkup</tt> instance and two datetime objects, builds a UBL
        # representation of the period between the two dates and times, something like the
        # following:
        #
        #   <cbc:StartDate>2008-05-06</cbc:StartTime>
        #   <cbc:StartTime>12:34:56+02:00</cbc:StartTime>
        #   <cbc:EndDate>2008-07-02</cbc:EndDate>
        #   <cbc:EndTime>01:02:03+02:00</cbc:EndTime>
        def build_period(xml, start_datetime, end_datetime)
          start_date, start_time = date_and_time(start_datetime)
          end_date, end_time = date_and_time(end_datetime)
          xml.cbc :StartDate, start_date
          xml.cbc :StartTime, start_time
          xml.cbc :EndDate, end_date
          xml.cbc :EndTime, end_time
        end


        # Given a <tt>Builder::XmlMarkup</tt> instance and a supplier/customer details hash (as
        # returned by <tt>LedgerItem#sender_details</tt> and <tt>LedgerItem#recipient_details</tt>,
        # builds a UBL representation of that party, something like the following:
        #
        #   <cac:Party>
        #       <cac:PartyName>
        #           <cbc:Name>The Big Bank</cbc:Name>
        #       </cac:PartyName>
        #       <cac:PostalAddress>
        #           <cbc:StreetName>Paved With Gold Street</cbc:StreetName>
        #           <cbc:CityName>London</cbc:CityName>
        #           <cbc:PostalZone>E14 5HQ</cbc:PostalZone>
        #           <cac:Country><cbc:IdentificationCode>GB</cbc:IdentificationCode></cac:Country>
        #       </cac:PostalAddress>
        #   </cac:Party>
        def build_party(xml, details)
          details = details.symbolize_keys
          xml.cac :Party do |party|
            party.cac :PartyName do |party_name|
              party_name.cbc :Name, details[:name]
            end if details[:name]

            party.cac :PostalAddress do |postal_address|
              street1, street2 = details[:address].strip.split("\n", 2)
              postal_address.cbc :StreetName,           street1               if street1
              postal_address.cbc :AdditionalStreetName, street2               if street2
              postal_address.cbc :CityName,             details[:city]        if details[:city]
              postal_address.cbc :PostalZone,           details[:postal_code] if details[:postal_code]
              postal_address.cbc :CountrySubentity,     details[:state]       if details[:state]
              postal_address.cac :Country do |country|
                country.cbc :IdentificationCode, details[:country_code] if details[:country_code]
                country.cbc :Name,               details[:country]      if details[:country]
              end if details[:country_code] || details[:country]
            end

            party.cac :PartyTaxScheme do |party_tax_scheme|
              party_tax_scheme.cbc :CompanyID, details[:tax_number]
              party_tax_scheme.cac :TaxScheme do |tax_scheme|
                tax_scheme.cbc :ID, "VAT" # TODO: make country-dependent (e.g. GST in Australia)
              end
            end if details[:tax_number]

            party.cac :Contact do |contact|
              contact.cbc :Name, details[:contact_name]
            end if details[:contact_name]
          end
        end


        # Given a <tt>Builder::XmlMarkup</tt> instance and a +LineItem+ instance, builds a UBL
        # representation of that line item, something like the following:
        #
        #   <cbc:ID>123</cbc:ID>
        #   <cbc:UUID>0cc659f0-cfac-012b-481d-0017f22d32c0</cbc:UUID>
        #   <cbc:InvoicedQuantity>1</cbc:InvoicedQuantity>
        #   <cbc:LineExtensionAmount currencyID="GBP">123.45</cbc:LineExtensionAmount>
        #   <cbc:TaxPointDate>2009-01-01</cbc:TaxPointDate>
        #   <cac:TaxTotal><cbc:TaxAmount currencyID="GBP">12.34</cbc:TaxAmount></cac:TaxTotal>
        #   <cac:Item><cbc:Description>Foo bar baz</cbc:Description></cac:Item>
        def build_line_item(invoice_line, line_item)
          invoice_line.cbc :ID, id_of(line_item)
          invoice_line.cbc :UUID, uuid_of(line_item) if uuid_of(line_item)
          quantity_tag = [:Invoice, :SelfBilledInvoice].include?(doc_type) ? :InvoicedQuantity : :CreditedQuantity
          invoice_line.cbc quantity_tag, quantity_of(line_item) if quantity_of(line_item)
          invoice_line.cbc :LineExtensionAmount, (factor*net_amount_of(line_item)).to_s, :currencyID => currency
          if tax_point_of(line_item)
            tax_point_date, tax_point_time = date_and_time(tax_point_of(line_item))
            invoice_line.cbc :TaxPointDate, tax_point_date
          end

          invoice_line.cac :TaxTotal do |tax_total|
            tax_total.cbc :TaxAmount, (factor*tax_amount_of(line_item)).to_s, :currencyID => currency
          end if tax_amount_of(line_item)

          invoice_line.cac :Item do |item|
            item.cbc :Description, description_of(line_item)
            #cac:BuyersItemIdentification
            #cac:SellersItemIdentification
            #cac:ClassifiedTaxCategory
            #cac:ItemInstance
          end

          #cac:Price
        end

        private

        # Returns an array of two strings, <tt>[date, time]</tt> in the format specified by UBL,
        # for a given datetime value.
        def date_and_time(value)
          value.in_time_zone(Time.zone || 'Etc/UTC').xmlschema.split('T')
        end
      end
    end
  end
end
