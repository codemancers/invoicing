connection = ActiveRecord::Base.connection

connection.create_table :ledger_item_records do |t|
  t.string   :type
  t.integer  :sender_id
  t.integer  :recipient_id
  t.string   :identifier
  t.datetime :issue_date
  t.string   :currency
  t.decimal  :total_amount
  t.decimal  :tax_amount
  t.string   :status
  t.datetime :period_start
  t.datetime :period_end
  t.string   :uuid
  t.datetime :due_date

  t.timestamps
end

class LedgerItemRecord < ActiveRecord::Base
end

class MyLedgerItem < ActiveRecord::Base
  self.table_name = "ledger_item_records"
end

class MyInvoice < MyLedgerItem; end
class InvoiceSubtype < MyInvoice; end
class MyCreditNote < MyLedgerItem; end
class MyPayment < MyLedgerItem; end
class CorporationTaxLiability < MyLedgerItem; end


# Invoice 10 is set to not add up correctly; total_amount is 0.01 too little to test error handling
ledger_item_entries = [
  # id2, type2,             sender_id2, recipient_id2, identifier2, issue_date2,  currency2, total_amount2, tax_amount2, status2,     period_start2, period_end2,  uuid2,                                  due_date2,    created_at,            updated_at
  [1, 'MyInvoice',                  1, 2,             '1',         '2008-06-30', 'GBP',            315.00,       15.00, 'closed',    '2008-06-01',  '2008-07-01', '30f4f680-d1b9-012b-48a5-0017f22d32c0', '2008-07-30', '2008-06-02 12:34:00', '2008-07-01 00:00:00'],
  [2, 'InvoiceSubtype',             2, 1,             '12-ASDF',   '2009-01-01', 'GBP',            141.97,       18.52, 'closed',    '2008-01-01',  '2009-01-01', 'fe4d20a0-d1b9-012b-48a5-0017f22d32c0', '2009-01-31', '2008-12-25 00:00:00', '2008-12-26 00:00:00'],
  [3, 'MyCreditNote',               1, 2,             'putain!',   '2008-07-13', 'GBP',            -57.50,       -7.50, 'closed',    '2008-06-01',  '2008-07-01', '671a05d0-d1ba-012b-48a5-0017f22d32c0', nil,         '2008-07-13 09:13:14', '2008-07-13 09:13:14'],
  [4, 'MyPayment',                  1, 2,             '14BC4E0F',  '2008-07-06', 'GBP',            256.50,        0.00, 'cleared',   nil,          nil,         'cfdf2ae0-d1ba-012b-48a5-0017f22d32c0', nil,         '2008-07-06 01:02:03', '2008-07-06 02:03:04'],
  [5, 'MyLedgerItem',               2, 3,             nil,        '2007-04-23', 'USD',            432.10,        nil, 'closed',    nil,          nil,         'f6d6a700-d1ae-012b-48a5-0017f22d32c0', '2011-02-27', '2008-01-01 00:00:00', '2008-01-01 00:00:00'],
  [6, 'CorporationTaxLiability',    4, 1,             'OMGWTFBBQ', '2009-01-01', 'GBP',         666666.66,        nil, 'closed',    '2008-01-01',  '2009-01-01', '7273c000-d1bb-012b-48a5-0017f22d32c0', '2009-04-23', '2009-01-23 00:00:00', '2009-01-23 00:00:00'],
  [7, 'MyPayment',                  1, 2,             'nonsense',  '2009-01-23', 'GBP',        1000000.00,        0.00, 'failed',    nil,          nil,         'af488310-d1bb-012b-48a5-0017f22d32c0', nil,         '2009-01-23 00:00:00', '2009-01-23 00:00:00'],
  [8, 'MyPayment',                  1, 2,             '1quid',     '2008-12-23', 'GBP',              1.00,        0.00, 'pending',   nil,          nil,         'df733560-d1bb-012b-48a5-0017f22d32c0', nil,         '2009-12-23 00:00:00', '2009-12-23 00:00:00'],
  [9, 'MyInvoice',                  1, 2,             '9',         '2009-01-23', 'GBP',             11.50,        1.50, 'open',      '2009-01-01',  '2008-02-01', 'e5b0dac0-d1bb-012b-48a5-0017f22d32c0', '2009-02-01', '2009-12-23 00:00:00', '2009-12-23 00:00:00'],
  [10,'MyInvoice',                  1, 2,             'a la con',  '2009-01-23', 'GBP',         432198.76,     4610.62, 'cancelled', '2008-12-01',  '2009-01-01', 'eb167b10-d1bb-012b-48a5-0017f22d32c0', nil,         '2009-12-23 00:00:00', '2009-12-23 00:00:00'],
  [11,'MyInvoice',                  1, 2,             'no_lines',  '2009-01-24', 'GBP',              nil,        nil, 'closed',    '2009-01-23',  '2009-01-24', '9ed54a00-d99f-012b-592c-0017f22d32c0', '2009-01-25', '2009-01-24 23:59:59', '2009-01-24 23:59:59']
]

ledger_item_entries.each do |entry|
  params = {}
  params[:sender_id]    = entry[2]
  params[:recipient_id] = entry[3]
  params[:identifier]   = entry[4]
  params[:issue_date]   = entry[5]
  params[:currency]     = entry[6]
  params[:total_amount] = entry[7]
  params[:tax_amount]   = entry[8]
  params[:status]       = entry[9]
  params[:period_start] = entry[10]
  params[:period_end]   = entry[11]
  params[:uuid]         = entry[12]
  params[:due_date]     = entry[13]
  params[:created_at]   = entry[14]
  params[:updated_at]   = entry[15]

  type = entry[1]
  type.constantize.create!(params)
end

Object.send(:remove_const, :LedgerItemRecord        )
Object.send(:remove_const, :MyLedgerItem            )
Object.send(:remove_const, :MyInvoice               )
Object.send(:remove_const, :InvoiceSubtype          )
Object.send(:remove_const, :MyCreditNote            )
Object.send(:remove_const, :MyPayment               )
Object.send(:remove_const, :CorporationTaxLiability )
