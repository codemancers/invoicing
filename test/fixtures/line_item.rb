connection = ActiveRecord::Base.connection

connection.create_table :line_item_records do |t|
  t.string   :type
  t.integer  :ledger_item_id, null: false
  t.decimal  :net_amount
  t.decimal  :tax_amount
  t.string   :uuid
  t.datetime :tax_point
  t.integer  :tax_rate_id
  t.integer  :price_id
  t.decimal  :quantity
  t.integer  :creator_id

  t.timestamps
end

class SuperLineItem < ActiveRecord::Base
  self.table_name = "line_item_records"
end

class SubLineItem < SuperLineItem; end
class OtherLineItem < SuperLineItem; end
class UntaxedLineItem < SuperLineItem; end


line_item_entries = [
  #(id2, type2, ledger_item_id2, net_amount2, tax_amount2, uuid2,                              tax_point2,   tax_rate_id2, price_id2, quantity2, creator_id2, created_at,            updated_at) values
  [1,   'SuperLineItem',     1, 100.00,      15.00,   '0cc659f0-cfac-012b-481d-0017f22d32c0', '2008-06-30', 1,            1,         1,         42,          '2008-06-30 12:34:56', '2008-06-30 12:34:56'],
  [2,   'SubLineItem',       1, 200.00,      0,       '0cc65e20-cfac-012b-481d-0017f22d32c0', '2008-06-25', 2,            2,         4,         42,          '2008-06-30 21:43:56', '2008-06-30 21:43:56'],
  [3,   'OtherLineItem',     2, 123.45,      18.52,   '0cc66060-cfac-012b-481d-0017f22d32c0', '2009-01-01', 1,            nil,      1,         43,          '2008-12-25 00:00:00', '2008-12-26 00:00:00'],
  [4,   'UntaxedLineItem',   5, 432.10,      nil,    '0cc662a0-cfac-012b-481d-0017f22d32c0', '2007-04-23', nil,         3,         nil,      99,          '2007-04-03 12:34:00', '2007-04-03 12:34:00'],
  [5,   'SuperLineItem',     3, -50.00,      -7.50,   'eab28cf0-d1b4-012b-48a5-0017f22d32c0', '2008-07-13', 1,            1,         0.5,       42,          '2008-07-13 09:13:14', '2008-07-13 09:13:14'],
  [6,   'OtherLineItem',     6, 666666.66,   nil,    'b5e66b50-d1b9-012b-48a5-0017f22d32c0', '2009-01-01', 3,            nil,      0,         666,         '2009-01-23 00:00:00', '2009-01-23 00:00:00'],
  [7,   'SubLineItem',       9, 10.00,       1.50,    '6f362040-d1be-012b-48a5-0017f22d32c0', '2009-01-31', 1,            1,         0.1,       nil,        '2009-12-23 00:00:00', '2009-12-23 00:00:00'],
  [8,   'SubLineItem',      10, 427588.15,   4610.62, '3d12c020-d1bf-012b-48a5-0017f22d32c0', '2009-01-31', nil,         nil,      nil,      42,          '2009-12-23 00:00:00', '2009-12-23 00:00:00']
]

line_item_entries.each do |entry|
  params = {}
  params[:ledger_item_id] = entry[2]
  params[:net_amount]     = entry[3]
  params[:tax_amount]     = entry[4]
  params[:uuid]           = entry[5]
  params[:tax_point]      = entry[6]
  params[:tax_rate_id]    = entry[7]
  params[:price_id]       = entry[8]
  params[:quantity]       = entry[9]
  params[:creator_id]     = entry[10]
  params[:created_at]     = entry[11]
  params[:updated_at]     = entry[12]

  type = entry[1]
  type.constantize.create!(params)
end

Object.send(:remove_const, :SuperLineItem  )
Object.send(:remove_const, :SubLineItem    )
Object.send(:remove_const, :OtherLineItem  )
Object.send(:remove_const, :UntaxedLineItem)
