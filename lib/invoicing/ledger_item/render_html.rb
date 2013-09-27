# encoding: utf-8

require "active_support/concern"
require 'builder'

module Invoicing
  module LedgerItem
    # Included into ActiveRecord model object when +acts_as_ledger_item+ is invoked.
    module RenderHTML
      extend ActiveSupport::Concern

      # Shortcut for rendering an invoice or a credit note into a human-readable HTML format.
      # Can be called without any arguments, in which case a general-purpose representation is
      # produced. Can also be given options and a block for customising the output:
      #
      #   @invoice = Invoice.find(params[:id])
      #   @invoice.render_html :quantity_column => false do |i|
      #     i.date_format "%d %B %Y"        # overwrites default "%Y-%m-%d"
      #     i.recipient_label "Customer"    # overwrites default "Recipient"
      #     i.sender_label "Supplier"       # overwrites default "Sender"
      #     i.description_tag do |params|
      #       "<p>Thank you for your order. Here is our invoice for your records.</p>\n" +
      #       "<p>Description: #{params[:description]}</p>\n"
      #     end
      #   end
      def render_html(options={}, &block)
        output_builder = HTMLOutputBuilder.new(self, options)
        yield output_builder if block_given?
        output_builder.build
      end


      class HTMLOutputBuilder #:nodoc:

        HTML_ESCAPE = { '&' => '&amp;', '>' => '&gt;', '<' => '&lt;', '"' => '&quot;' }

        attr_reader :ledger_item, :current_line_item, :options, :custom_fragments, :factor

        def initialize(ledger_item, options)
          @ledger_item = ledger_item
          @options = default_options
          @options.update(options)
          @custom_fragments = {}
          total_amount = get(:total_amount)
          @factor = (total_amount && total_amount < BigDecimal('0')) ? BigDecimal('-1') : BigDecimal('1')
        end

        def default_options
          line_items = get(:line_items)
          {
            :tax_point_column    => line_items.map{|i| line_get(:tax_point,  i) }.compact != [],
            :quantity_column     => line_items.map{|i| line_get(:quantity,   i) }.compact != [],
            :description_column  => true,
            :net_amount_column   => true,
            :tax_amount_column   => line_items.map{|i| line_get(:tax_amount, i) }.compact != [],
            :gross_amount_column => false,
            :subtotal            => true
          }
        end

        def h(s)
          s.to_s.gsub(/[#{HTML_ESCAPE.keys.join}]/) { |char| HTML_ESCAPE[char] }
        end

        # foo { block }   => call block when invoking fragment foo
        # foo "string"    => return string when invoking fragment foo
        # invoke_foo      => invoke fragment foo; if none set, delegate to default_foo
        def method_missing(method_id, *args, &block)
          method_id = method_id.to_sym
          if method_id.to_s =~ /^invoke_(.*)$/
            method_id = $1.to_sym
            if custom_fragments[method_id]
              return custom_fragments[method_id].call(*args, &block)
            else
              return send("default_#{method_id}", *args, &block)
            end
          end

          return super unless respond_to? "default_#{method_id}"

          if block_given? && args.empty?
            custom_fragments[method_id] = proc &block
          elsif args.length == 1
            custom_fragments[method_id] = proc{ args[0].to_s }
          else
            raise ArgumentError, "#{method_id} expects exactly one value or block argument"
          end
        end

        # Returns the value of a (potentially renamed) method on the ledger item
        def get(method_id)
          ledger_item.send(:ledger_item_class_info).get(ledger_item, method_id)
        end

        # Returns the value of a (potentially renamed) method on a line item
        def line_get(method_id, line_item = current_line_item)
          line_item.send(:line_item_class_info).get(line_item, method_id)
        end

        # String for one level of indentation
        def indent
          '    '
        end

        # This is quite meta. :)
        #
        #   params_hash(:sender_label, :sender_tax_number => :tax_number_label)
        #     # => {:sender_label => invoke_sender_label,
        #     #     :sender_tax_number => invoke_sender_tax_number(params_hash(:tax_number_label))}
        def params_hash(*param_names)
          result = {}
          param_names.flatten!
          options = param_names.extract_options!

          param_names.each{|param| result[param.to_sym] = send("invoke_#{param}") }

          options.each_pair do |key, value|
            result[key.to_sym] = send("invoke_#{key}", params_hash(value))
          end

          result
        end

        # Renders an invoice or credit note to HTML
        def build
          addresses_table_deps = [:sender_label, :recipient_label, :sender_address, :recipient_address, {
            :sender_tax_number    => :tax_number_label,
            :recipient_tax_number => :tax_number_label
          }]

          metadata_table_deps = [{
            :identifier   =>  :identifier_label,
            :issue_date   => [:date_format, :issue_date_label],
            :period_start => [:date_format, :period_start_label],
            :period_end   => [:date_format, :period_end_label],
            :due_date     => [:date_format, :due_date_label]
          }]

          line_items_header_deps = [:line_tax_point_label, :line_quantity_label, :line_description_label,
            :line_net_amount_label, :line_tax_amount_label, :line_gross_amount_label]

          line_items_subtotal_deps = [:subtotal_label, :net_amount_label, :tax_amount_label,
            :gross_amount_label, {
            :net_amount => :net_amount_label,
            :tax_amount => :tax_amount_label,
            :total_amount => :gross_amount_label
          }]

          line_items_total_deps = [:total_label, :net_amount_label, :tax_amount_label,
            :gross_amount_label, {
            :net_amount => :net_amount_label,
            :tax_amount => :tax_amount_label,
            :total_amount => :gross_amount_label
          }]

          page_layout_deps = {
            :title_tag => :title,
            :addresses_table => addresses_table_deps,
            :metadata_table => metadata_table_deps,
            :description_tag => :description,
            :line_items_table => [:line_items_list, {
              :line_items_header   => line_items_header_deps,
              :line_items_subtotal => line_items_subtotal_deps,
              :line_items_total    => line_items_total_deps
            }]
          }

          invoke_page_layout(params_hash(page_layout_deps))
        end

        def default_date_format
          "%Y-%m-%d"
        end

        def default_invoice_label
          "Invoice"
        end

        def default_credit_note_label
          "Credit Note"
        end

        def default_recipient_label
          "Recipient"
        end

        def default_sender_label
          "Sender"
        end

        def default_tax_number_label
          "VAT number:<br />"
        end

        def default_identifier_label
          label = (factor == BigDecimal('-1')) ? invoke_credit_note_label : invoke_invoice_label
          "#{label} no.:"
        end

        def default_issue_date_label
          "Issue date:"
        end

        def default_period_start_label
          "Period from:"
        end

        def default_period_end_label
          "Period until:"
        end

        def default_due_date_label
          "Payment due:"
        end

        def default_line_tax_point_label
          "Tax point"
        end

        def default_line_quantity_label
          "Quantity"
        end

        def default_line_description_label
          "Description"
        end

        def default_line_net_amount_label
          "Net price"
        end

        def default_line_tax_amount_label
          "VAT"
        end

        def default_line_gross_amount_label
          "Gross price"
        end

        def default_subtotal_label
          "Subtotal"
        end

        def default_total_label
          "Total"
        end

        def default_net_amount_label
          "Net: "
        end

        def default_tax_amount_label
          "VAT: "
        end

        def default_gross_amount_label
          ""
        end

        def default_title
          (factor == BigDecimal('-1')) ? invoke_credit_note_label : invoke_invoice_label
        end

        def default_title_tag(params)
          "<h1 class=\"invoice\">#{params[:title]}</h1>\n"
        end

        def default_address(details)
          details = details.symbolize_keys
          html =  "#{indent*3}<div class=\"fn org\">#{       h(details[:name])        }</div>\n"
          html << "#{indent*3}<div class=\"contact\">#{      h(details[:contact_name])}</div>\n"        unless details[:contact_name].blank?
          html << "#{indent*3}<div class=\"adr\">\n"
          html << "#{indent*4}<span class=\"street-address\">#{h(details[:address]).strip.gsub(/\n/, '<br />')}</span><br />\n"
          html << "#{indent*4}<span class=\"locality\">#{    h(details[:city])        }</span><br />\n" unless details[:city].blank?
          html << "#{indent*4}<span class=\"region\">#{      h(details[:state])       }</span><br />\n" unless details[:state].blank?
          html << "#{indent*4}<span class=\"postal-code\">#{ h(details[:postal_code]) }</span><br />\n" unless details[:postal_code].blank?
          html << "#{indent*4}<span class=\"country-name\">#{h(details[:country])     }</span>\n"       unless details[:country].blank?
          html << "#{indent*3}</div>\n"
        end

        def default_sender_address
          invoke_address(get(:sender_details))
        end

        def default_recipient_address
          invoke_address(get(:recipient_details))
        end

        def default_sender_tax_number(params)
          sender_tax_number = get(:sender_details).symbolize_keys[:tax_number]
          "#{params[:tax_number_label]}<span class=\"tax-number\">#{h(sender_tax_number)}</span>"
        end

        def default_recipient_tax_number(params)
          recipient_tax_number = get(:recipient_details).symbolize_keys[:tax_number]
          "#{params[:tax_number_label]}<span class=\"tax-number\">#{h(recipient_tax_number)}</span>"
        end

        def default_addresses_table(params)
          html =  "#{indent*0}<table class=\"invoice addresses\">\n"
          html << "#{indent*1}<tr>\n"
          html << "#{indent*2}<th class=\"recipient\">#{params[:recipient_label]}</th>\n"
          html << "#{indent*2}<th class=\"sender\">#{params[:sender_label]}</th>\n"
          html << "#{indent*1}</tr>\n"
          html << "#{indent*1}<tr>\n"
          html << "#{indent*2}<td class=\"recipient vcard\">\n#{params[:recipient_address]}"
          html << "#{indent*2}</td>\n"
          html << "#{indent*2}<td class=\"sender vcard\">\n#{params[:sender_address]}"
          html << "#{indent*2}</td>\n"
          html << "#{indent*1}</tr>\n"
          html << "#{indent*1}<tr>\n"
          html << "#{indent*2}<td class=\"recipient\">\n"
          html << "#{indent*3}#{params[:recipient_tax_number]}\n"
          html << "#{indent*2}</td>\n"
          html << "#{indent*2}<td class=\"sender\">\n"
          html << "#{indent*3}#{params[:sender_tax_number]}\n"
          html << "#{indent*2}</td>\n"
          html << "#{indent*1}</tr>\n"
          html << "#{indent*0}</table>\n"
        end

        def default_metadata_item(params, key, value)
          label = params["#{key}_label".to_sym]
          html =  "#{indent*1}<tr class=\"#{key.to_s.gsub(/_/, '-')}\">\n"
          html << "#{indent*2}<th>#{label}</th>\n"
          html << "#{indent*2}<td>#{h(value)}</td>\n"
          html << "#{indent*1}</tr>\n"
        end

        def default_identifier(params)
          invoke_metadata_item(params, :identifier, get(:identifier))
        end

        def default_issue_date(params)
          if issue_date = get(:issue_date)
            invoke_metadata_item(params, :issue_date, issue_date.strftime(params[:date_format]))
          else
            ""
          end
        end

        def default_period_start(params)
          if period_start = get(:period_start)
            invoke_metadata_item(params, :period_start, period_start.strftime(params[:date_format]))
          else
            ""
          end
        end

        def default_period_end(params)
          if period_end = get(:period_end)
            invoke_metadata_item(params, :period_end, period_end.strftime(params[:date_format]))
          else
            ""
          end
        end

        def default_due_date(params)
          if due_date = get(:due_date)
            invoke_metadata_item(params, :due_date, due_date.strftime(params[:date_format]))
          else
            ""
          end
        end

        def default_metadata_table(params)
          "<table class=\"invoice metadata\">\n" + params[:identifier] + params[:issue_date] +
            params[:period_start] + params[:period_end] + params[:due_date] + "#{indent*0}</table>\n"
        end

        def default_description
          h(get(:description))
        end

        def default_description_tag(params)
          "<p class=\"invoice description\">#{params[:description]}</p>\n"
        end

        def default_line_items_header(params)
          html =  "#{indent*1}<tr>\n"
          html << "#{indent*2}<th class=\"tax-point\">#{   params[:line_tax_point_label]   }</th>\n" if options[:tax_point_column]
          html << "#{indent*2}<th class=\"quantity\">#{    params[:line_quantity_label]    }</th>\n" if options[:quantity_column]
          html << "#{indent*2}<th class=\"description\">#{ params[:line_description_label] }</th>\n" if options[:description_column]
          html << "#{indent*2}<th class=\"net-amount\">#{  params[:line_net_amount_label]  }</th>\n" if options[:net_amount_column]
          html << "#{indent*2}<th class=\"tax-amount\">#{  params[:line_tax_amount_label]  }</th>\n" if options[:tax_amount_column]
          html << "#{indent*2}<th class=\"gross-amount\">#{params[:line_gross_amount_label]}</th>\n" if options[:gross_amount_column]
          html << "#{indent*1}</tr>\n"
        end

        def default_line_tax_point(params)
          if tax_point = line_get(:tax_point)
            h(tax_point.strftime(params[:date_format]))
          else
            ""
          end
        end

        def default_line_quantity(params)
          h(line_get(:quantity).to_s)
        end

        def default_line_description(params)
          h(line_get(:description))
        end

        def default_line_net_amount(params)
          if net_amount = line_get(:net_amount)
            h(current_line_item.format_currency_value(net_amount*factor))
          else
            "—"
          end
        end

        def default_line_tax_amount(params)
          if tax_amount = line_get(:tax_amount)
            h(current_line_item.format_currency_value(tax_amount*factor))
          else
            "—"
          end
        end

        def default_line_gross_amount(params)
          if gross_amount = line_get(:gross_amount)
            h(current_line_item.format_currency_value(gross_amount*factor))
          else
            "—"
          end
        end

        def default_net_amount(params)
          if net_amount = get(:net_amount)
            h(ledger_item.format_currency_value(net_amount*factor))
          else
            "—"
          end
        end

        def default_tax_amount(params)
          if tax_amount = get(:tax_amount)
            h(ledger_item.format_currency_value(tax_amount*factor))
          else
            "—"
          end
        end

        def default_total_amount(params)
          if total_amount = get(:total_amount)
            h(ledger_item.format_currency_value(total_amount*factor))
          else
            "—"
          end
        end

        def default_line_item(params)
          html =  "#{indent*1}<tr>\n"
          html << "#{indent*2}<td class=\"tax-point\">#{   params[:line_tax_point]   }</td>\n" if options[:tax_point_column]
          html << "#{indent*2}<td class=\"quantity\">#{    params[:line_quantity]    }</td>\n" if options[:quantity_column]
          html << "#{indent*2}<td class=\"description\">#{ params[:line_description] }</td>\n" if options[:description_column]
          html << "#{indent*2}<td class=\"net-amount\">#{  params[:line_net_amount]  }</td>\n" if options[:net_amount_column]
          html << "#{indent*2}<td class=\"tax-amount\">#{  params[:line_tax_amount]  }</td>\n" if options[:tax_amount_column]
          html << "#{indent*2}<td class=\"gross-amount\">#{params[:line_gross_amount]}</td>\n" if options[:gross_amount_column]
          html << "#{indent*1}</tr>\n"
        end

        def default_line_items_list
          get(:line_items).sorted(:tax_point).map do |line_item|
            @current_line_item = line_item
            invoke_line_item(params_hash(
              :line_tax_point    => [:line_tax_point_label, :date_format],
              :line_quantity     => [:line_quantity_label],
              :line_description  => [:line_description_label],
              :line_net_amount   => [:line_net_amount_label],
              :line_tax_amount   => [:line_tax_amount_label],
              :line_gross_amount => [:line_gross_amount_label]
            ))
          end.join
        end

        def default_line_items_subtotal(params)
          colspan = 0
          colspan += 1 if options[:tax_point_column]
          colspan += 1 if options[:quantity_column]
          colspan += 1 if options[:description_column]
          html =  "#{indent*1}<tr class=\"subtotal\">\n"
          html << "#{indent*2}<th colspan=\"#{colspan}\">#{params[:subtotal_label]}</th>\n"
          html << "#{indent*2}<td class=\"net-amount\">#{params[:net_amount_label]}#{params[:net_amount]}</td>\n" if options[:net_amount_column]
          html << "#{indent*2}<td class=\"tax-amount\">#{params[:tax_amount_label]}#{params[:tax_amount]}</td>\n" if options[:tax_amount_column]
          html << "#{indent*2}<td class=\"gross-amount\"></td>\n" if options[:gross_amount_column]
          html << "#{indent*1}</tr>\n"
        end

        def default_line_items_total(params)
          colspan = -1
          colspan += 1 if options[:tax_point_column]
          colspan += 1 if options[:quantity_column]
          colspan += 1 if options[:description_column]
          colspan += 1 if options[:net_amount_column]
          colspan += 1 if options[:tax_amount_column]
          colspan += 1 if options[:gross_amount_column]
          html =  "#{indent*1}<tr class=\"total\">\n"
          html << "#{indent*2}<th colspan=\"#{colspan}\">#{params[:total_label]}</th>\n"
          html << "#{indent*2}<td class=\"total-amount\">#{params[:gross_amount_label]}#{params[:total_amount]}</td>\n"
          html << "#{indent*1}</tr>\n"
        end

        def default_line_items_table(params)
          html =  "<table class=\"invoice line-items\">\n"
          html << params[:line_items_header] + params[:line_items_list]
          html << params[:line_items_subtotal] if options[:subtotal]
          html << params[:line_items_total] + "</table>\n"
        end

        def default_page_layout(params)
          params[:title_tag] + params[:addresses_table] + params[:metadata_table] +
          params[:description_tag] + params[:line_items_table]
        end
      end
    end
  end
end
