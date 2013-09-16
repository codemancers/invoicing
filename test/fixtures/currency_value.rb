connection = ActiveRecord::Base.connection

connection.create_table :currency_value_records do |t|
  t.string  :currency_code
  t.decimal :amount
  t.decimal :tax_amount
end

class CurrencyValueRecord < ActiveRecord::Base
end

CurrencyValueRecord.create!(currency_code: "GBP", amount: 123.45, tax_amount: nil)
CurrencyValueRecord.create!(currency_code: "EUR", amount: 98765432, tax_amount: 0.02)
CurrencyValueRecord.create!(currency_code: "CNY", amount: 5432, tax_amount: 0)
CurrencyValueRecord.create!(currency_code: "JPY", amount: 8888, tax_amount: 123)
CurrencyValueRecord.create!(currency_code: "XXX", amount: 123, tax_amount: nil)


connection.create_table :no_currency_column_records do |t|
  t.decimal :amount
end

class NoCurrencyColumnRecord < ActiveRecord::Base
end

NoCurrencyColumnRecord.create!(amount: 95.15)
