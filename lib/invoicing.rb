require "active_record"

require "invoicing/class_info"  # load first because other modules depend on this
require "invoicing/cached_record"
require "invoicing/connection_adapter_ext"
require "invoicing/currency_value"
require "invoicing/find_subclasses"
require "invoicing/ledger_item"
require "invoicing/line_item"
require "invoicing/price"
require "invoicing/tax_rate"
require "invoicing/taxable"
require "invoicing/time_dependent"

ActiveRecord::Base.send(:extend, Invoicing::CachedRecord::ActMethods)
ActiveRecord::Base.send(:extend, Invoicing::CurrencyValue::ActMethods)
ActiveRecord::Base.send(:extend, Invoicing::LedgerItem::ActMethods)
ActiveRecord::Base.send(:extend, Invoicing::LineItem::ActMethods)
ActiveRecord::Base.send(:extend, Invoicing::Price::ActMethods)
ActiveRecord::Base.send(:extend, Invoicing::TaxRate::ActMethods)
ActiveRecord::Base.send(:extend, Invoicing::Taxable::ActMethods)
ActiveRecord::Base.send(:extend, Invoicing::TimeDependent::ActMethods)
