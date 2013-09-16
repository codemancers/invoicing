connection = ActiveRecord::Base.connection

connection.create_table :taxable_records do |t|
  t.string  :currency_code
  t.decimal :amount
  t.decimal :gross_amount
  t.decimal :tax_factor
end

class TaxableRecord < ActiveRecord::Base
end

TaxableRecord.create!(currency_code: "GBP", amount: 123.45, gross_amount: 141.09,
  tax_factor: 0.142857143)

Object.send(:remove_const, :TaxableRecord)
