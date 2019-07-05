connection = ActiveRecord::Base.connection

connection.create_table :currency_value_records do |t|
  t.string  :currency_code
  t.decimal :amount
  t.decimal :tax_amount
end

class CurrencyValueRecord < ActiveRecord::Base
end

CurrencyValueRecord.create!(currency_code: "EUR", amount: 98765432, tax_amount: 0.02)


connection.create_table :no_currency_column_records do |t|
  t.decimal :amount
end

class NoCurrencyColumnRecord < ActiveRecord::Base
end

NoCurrencyColumnRecord.create!(amount: 95.15)
