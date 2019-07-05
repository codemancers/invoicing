# frozen_string_literal: true

require 'active_record'

require_relative 'invoicing/class_info' # load first because other modules depend on this
require_relative 'invoicing/currency_value'
require_relative 'invoicing/ledger_item'
require_relative 'invoicing/line_item'

ActiveRecord::Base.send(:extend, Invoicing::CurrencyValue::ActMethods)
ActiveRecord::Base.send(:extend, Invoicing::LedgerItem::ActMethods)
ActiveRecord::Base.send(:extend, Invoicing::LineItem::ActMethods)
