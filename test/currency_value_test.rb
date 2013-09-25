# encoding: utf-8

require File.join(File.dirname(__FILE__), 'test_helper.rb')

# Test extending the default list of currency codes: include the Zimbabwe Dollar.
# This also tests rounding and seriously large numbers. -- Sorry, you shouldn't make
# jokes about this sort of thing. The people are suffering badly.
Invoicing::CurrencyValue::CURRENCIES['ZWD'] = {:symbol => 'ZW$', :round => 5_000_000}

class CurrencyValueTest < MiniTest::Unit::TestCase
  class CurrencyValueRecord < ActiveRecord::Base
    validates_numericality_of :amount
    acts_as_currency_value :amount, :tax_amount, :currency => 'currency_code'
  end

  # In Finland and the Netherlands, Euro amounts are commonly rounded to the nearest 5 cents.
  class EurosInFinlandRecord < ActiveRecord::Base
    self.table_name = "no_currency_column_records"
    acts_as_currency_value :amount, :currency_code => 'EUR', :round => 0.05, :space => true
  end

  def test_format_small_number
    assert_equal "€0.02", CurrencyValueRecord.find(2).tax_amount_formatted
  end

  def test_format_thousands_separators
    assert_equal "€98,765,432.00", CurrencyValueRecord.find(2).amount_formatted
  end

  def test_format_no_decimal_point
    assert_equal "¥8,888", CurrencyValueRecord.find(4).amount_formatted
  end

  def test_format_suffix_unit
    assert_equal "5,432.00 元", CurrencyValueRecord.find(3).amount_formatted
  end

  def test_format_unknown_currency
    assert_equal "123.00 XXX", CurrencyValueRecord.find(5).amount_formatted
  end

  def test_format_with_custom_currency
    record = CurrencyValueRecord.new(:currency_code => 'ZWD', :amount => BigDecimal('50000000000'))
    assert_equal "ZW$50,000,000,000", record.amount_formatted # price of 1 egg on 18 July 2008
  end

  def test_format_without_currency_column
    assert_equal "€ 95.15", EurosInFinlandRecord.find(1).amount_formatted
  end

  def test_format_with_options
    assert_equal "0.02 €", CurrencyValueRecord.find(2).tax_amount_formatted(:suffix => true)
  end

  def test_format_custom_value
    assert_equal "€1,357.90", CurrencyValueRecord.find(2).format_currency_value(BigDecimal('1357.9'))
  end

  def test_format_negative_value_with_minus
    assert_equal "−€1,357.90", CurrencyValueRecord.find(2).format_currency_value(BigDecimal('-1357.9'))
  end

  def test_format_negative_value_with_hyphen
    assert_equal "-€1,357.90", CurrencyValueRecord.find(2).format_currency_value(BigDecimal('-1357.9'), :negative => :hyphen)
  end

  def test_format_negative_value_with_brackets
    assert_equal "(€1,357.90)", CurrencyValueRecord.find(2).format_currency_value(BigDecimal('-1357.9'), :negative => :brackets)
  end

  def test_load_from_database_and_format
    assert_equal BigDecimal('123.45'), CurrencyValueRecord.find(1).amount
    assert_equal "£123.45", CurrencyValueRecord.find(1).amount_formatted
  end

  def test_new_record_from_string_and_format
    record = CurrencyValueRecord.new(:amount => '44.44', :currency_code => 'USD')
    assert_equal BigDecimal('44.44'), record.amount
    assert_equal "$44.44", record.amount_formatted
  end

  def test_new_record_from_big_decimal_and_format
    record = CurrencyValueRecord.new(:amount => BigDecimal('3.33'), :currency_code => 'USD')
    assert_equal BigDecimal('3.33'), record.amount
    assert_equal "$3.33", record.amount_formatted
  end

  def test_standalone_formatting
    assert_equal "12.00 €", Invoicing::CurrencyValue::Formatter.format_value(:eur, 12, :suffix => true)
  end

  def test_standalone_currency_info
    assert_equal({:code => 'USD', :symbol => '$', :round => 0.01, :suffix => false,
      :space => false, :digits => 2}, Invoicing::CurrencyValue::Formatter.currency_info(:USD))
  end

  def test_assign_float_to_new_record_and_format
    record = CurrencyValueRecord.new
    record.amount = 44.44
    record.currency_code = 'USD'
    assert_equal BigDecimal('44.44'), record.amount
    assert_equal "$44.44", record.amount_formatted
  end

  def test_assign_to_new_record_omitting_currency
    record = CurrencyValueRecord.new
    record.amount = 44.44
    assert_equal BigDecimal('44.44'), record.amount
    assert_equal "44.44", record.amount_formatted
  end

  def test_assign_nothing_to_new_record_with_numericality_validation
    record = CurrencyValueRecord.new(:currency_code => 'USD')
    assert_nil record.amount
    assert_equal '', record.amount_formatted
    assert !record.valid?
  end

  def test_assign_nothing_to_new_record_without_numericality_validation
    record = CurrencyValueRecord.new(:amount => 1, :currency_code => 'USD')
    assert_nil record.tax_amount
    assert_equal '', record.tax_amount_formatted
    assert record.valid?
    record.save!
    assert_equal([{'amount' => 1, 'tax_amount' => nil}],
      ActiveRecord::Base.connection.select_all("SELECT amount, tax_amount FROM currency_value_records WHERE id=#{record.id}").to_ary)
  end

  def test_assign_invalid_value_to_new_record_with_numericality_validation
    record = CurrencyValueRecord.new(:amount => 'plonk', :currency_code => 'USD')
    assert_equal BigDecimal('0.00'), record.amount
    assert_equal 'plonk', record.amount_before_type_cast
    assert_equal '', record.amount_formatted
    assert !record.valid?
  end

  def test_assign_invalid_value_to_new_record_without_numericality_validation
    record = CurrencyValueRecord.new(:amount => 1, :tax_amount => 'plonk', :currency_code => 'USD')
    assert_equal BigDecimal('0.00'), record.tax_amount
    assert_equal 'plonk', record.tax_amount_before_type_cast
    assert_equal '', record.tax_amount_formatted
    assert record.valid?
    record.save!
    assert_equal([{'amount' => 1, 'tax_amount' => 0}],
      ActiveRecord::Base.connection.select_all("SELECT amount, tax_amount FROM currency_value_records WHERE id=#{record.id}").to_ary)
  end

  def test_overwrite_existing_record_with_valid_value
    record = CurrencyValueRecord.find(4)
    record.amount = '12.34'
    record.currency_code = 'EUR'
    assert_equal BigDecimal('12.34'), record.amount
    assert_equal '12.34', record.amount_before_type_cast
    assert_equal "€12.34", record.amount_formatted
    record.save!
    assert_equal([{'amount' => 12.34, 'currency_code' => 'EUR'}],
      ActiveRecord::Base.connection.select_all("SELECT amount, currency_code FROM currency_value_records WHERE id=#{record.id}").to_ary)
  end

  def test_overwrite_existing_record_with_nil
    record = CurrencyValueRecord.find(4)
    record.tax_amount = nil
    assert_nil record.tax_amount
    assert_nil record.tax_amount_before_type_cast
    assert_equal '', record.tax_amount_formatted
    record.save!
    assert_equal([{'amount' => 8888, 'tax_amount' => nil, 'currency_code' => 'JPY'}],
      ActiveRecord::Base.connection.select_all("SELECT amount, tax_amount, currency_code FROM currency_value_records WHERE id=#{record.id}").to_ary)
  end

  def test_rounding_on_new_record_with_currency_column
    record = CurrencyValueRecord.new(:amount => '1234.5678', :currency_code => 'JPY')
    assert_equal BigDecimal('1235'), record.amount
    assert_equal '1234.5678', record.amount_before_type_cast
    record.save!
    assert_equal([{'amount' => 1235}],
      ActiveRecord::Base.connection.select_all("SELECT amount FROM currency_value_records WHERE id=#{record.id}").to_ary)
  end

  def test_rounding_on_overwriting_record_with_currency_column
    record = CurrencyValueRecord.find(1)
    record.amount = 10.0/3.0
    assert_equal BigDecimal('3.33'), record.amount
    assert_equal 10.0/3.0, record.amount_before_type_cast
    record.save!
    assert_equal([{'amount' => 3.33}],
      ActiveRecord::Base.connection.select_all("SELECT amount FROM currency_value_records WHERE id=1").to_ary)
  end

  def test_rounding_on_new_record_with_default_currency
    record = EurosInFinlandRecord.new(:amount => '1234.5678')
    assert_equal BigDecimal('1234.55'), record.amount
    assert_equal '1234.5678', record.amount_before_type_cast
    record.save!
    assert_equal([{'amount' => 1234.55}],
      ActiveRecord::Base.connection.select_all("SELECT amount FROM no_currency_column_records WHERE id=#{record.id}").to_ary)
  end

  def test_rounding_on_overwriting_record_with_default_currency
    record = EurosInFinlandRecord.find(1)
    record.amount = '98.7654321'
    assert_equal BigDecimal('98.75'), record.amount
    assert_equal '98.7654321', record.amount_before_type_cast
    record.save!
    assert_equal([{'amount' => 98.75}],
      ActiveRecord::Base.connection.select_all("SELECT amount FROM no_currency_column_records WHERE id=1").to_ary)
  end
end
