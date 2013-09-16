# encoding: utf-8

require File.join(File.dirname(__FILE__), 'test_helper.rb')

class TaxableTest < Test::Unit::TestCase

  class SimpleTaxLogic
    def apply_tax(params)
      if params[:attribute].to_s == 'amount'
        params[:value] * (BigDecimal('1.0') + params[:model_object].tax_factor)
      else
        params[:value]
      end
    end

    def remove_tax(params)
      if params[:attribute].to_s == 'amount'
        params[:value] / (BigDecimal('1.0') + params[:model_object].tax_factor)
      else
        params[:value]
      end
    end

    def tax_info(params)
      if params[:attribute].to_s == 'amount'
        "(inc. tax)"
      else
        ""
      end
    end

    def tax_details(params)
      if params[:attribute].to_s == 'amount'
        "(including #{sprintf('%.2f', 100*params[:model_object].tax_factor)}% tax)"
      else
        "(tax not applicable)"
      end
    end

    def some_other_method(options, param1, param2)
      param1 * param2 + options[:model_object].id
    end

    def mixin_methods
      [:some_other_method]
    end
  end


  class TaxableRecord < ActiveRecord::Base
    validates_numericality_of :amount
    acts_as_taxable :amount, :gross_amount, :tax_logic => SimpleTaxLogic.new, :currency => :currency_code
  end

  class NonsenseClass < ActiveRecord::Base
    self.table_name = "taxable_records"
  end


  ######################################################################

  def test_raises_error_if_no_tax_logic_is_specified
    assert_raise ArgumentError do
      NonsenseClass.class_eval do
        acts_as_taxable :amount
      end
    end
  end

  def test_apply_tax_on_existing_record
    record = TaxableRecord.find(1)
    assert_equal BigDecimal('141.09'), record.amount_taxed
    assert_equal BigDecimal('123.45'), record.amount
  end

  def test_apply_tax_on_new_record
    record = TaxableRecord.new(:amount => '200', :tax_factor => '0.4', :currency_code => 'USD')
    assert_equal BigDecimal('280'), record.amount_taxed
    assert_equal BigDecimal('200'), record.amount
    assert_equal '$280.00', record.amount_taxed_formatted
    assert_equal '$200.00', record.amount_formatted
    assert_equal '200', record.amount_before_type_cast
    record.save!
    assert_equal([{'amount' => 200}],
      ActiveRecord::Base.connection.select_all("SELECT amount FROM taxable_records WHERE id=#{record.id}").to_ary)
  end

  def test_remove_tax_on_existing_record
    record = TaxableRecord.find(1)
    record.amount_taxed = 114.29
    assert_equal BigDecimal('100.00'), record.amount
    assert_equal BigDecimal('114.29'), record.amount_taxed
    assert_equal '£100.00', record.amount_formatted
    assert_equal '£114.29', record.amount_taxed_formatted
    assert_equal 114.29, record.amount_taxed_before_type_cast
    record.save!
    assert_equal([{'amount' => 100}],
      ActiveRecord::Base.connection.select_all("SELECT amount FROM taxable_records WHERE id=1").to_ary)
  end

  def test_remove_tax_on_new_record
    record = TaxableRecord.new(:amount_taxed => '360', :tax_factor => '0.2', :currency_code => 'USD')
    assert_equal BigDecimal('300'), record.amount
    assert_equal BigDecimal('360'), record.amount_taxed
    assert_equal '$300.00', record.amount_formatted
    assert_equal '$360.00', record.amount_taxed_formatted
    assert_equal '360', record.amount_taxed_before_type_cast
    record.save!
    assert_equal([{'amount' => 300}],
      ActiveRecord::Base.connection.select_all("SELECT amount FROM taxable_records WHERE id=#{record.id}").to_ary)
  end

  def test_assign_taxed_then_untaxed
    record = TaxableRecord.find(1)
    record.amount_taxed = '333.33'
    record.amount = '1210.11'
    assert_equal BigDecimal('1382.98'), record.amount_taxed
    assert_equal BigDecimal('1210.11'), record.amount
    assert_equal '1210.11', record.amount_before_type_cast
  end

  def test_assign_untaxed_then_taxed
    record = TaxableRecord.find(1)
    record.amount = '0.02'
    record.amount_taxed = '1142.86'
    assert_equal BigDecimal('1000.00'), record.amount
    assert_equal BigDecimal('1142.86'), record.amount_taxed
    assert_equal '1142.86', record.amount_taxed_before_type_cast
  end

  def test_no_rounding_error
    record = TaxableRecord.new(:amount_taxed => 100, :tax_factor => 1.0/3.0)
    assert_equal BigDecimal('0'), record.amount_tax_rounding_error
    assert_equal BigDecimal('100'), record.amount_taxed
    assert_equal BigDecimal('75'), record.amount
  end

  def test_rounding_error_high
    record = TaxableRecord.new(:amount_taxed => 1.04, :tax_factor => 0.175)
    assert_equal BigDecimal('0.01'), record.amount_tax_rounding_error
    assert_equal BigDecimal('0.89'), record.amount
    assert_equal BigDecimal('1.05'), record.amount_taxed
  end

  def test_rounding_error_low
    record = TaxableRecord.new(:amount_taxed => 1.11, :tax_factor => 0.175)
    assert_equal BigDecimal('1.10'), record.amount_taxed
    assert_equal BigDecimal('0.94'), record.amount
    assert_equal BigDecimal('-0.01'), record.amount_tax_rounding_error
  end

  def test_tax_info
    record = TaxableRecord.find(1)
    assert_equal "(inc. tax)", record.amount_tax_info
    assert_equal "", record.gross_amount_tax_info
  end

  def test_tax_details
    record = TaxableRecord.find(1)
    assert_equal "(including 14.29% tax)", record.amount_tax_details
    assert_equal "(tax not applicable)", record.gross_amount_tax_details
  end

  def test_with_tax_info
    record = TaxableRecord.new(currency_code: "GBP", amount: 123.45,
                               gross_amount: 141.09, tax_factor: 0.142857143)
    assert_equal "£141.09 (inc. tax)", record.amount_with_tax_info
    assert_equal "£141.09", record.gross_amount_with_tax_info
  end

  def test_with_tax_details
    record = TaxableRecord.new(currency_code: "GBP", amount: 123.45,
                               gross_amount: 141.09, tax_factor: 0.142857143)
    assert_equal "£141.09 (including 14.29% tax)", record.amount_with_tax_details
    assert_equal "£141.09 (tax not applicable)", record.gross_amount_with_tax_details
  end

  def test_other_method
    record = TaxableRecord.find(1)
    assert_equal 49, record.some_other_method(6, 8)
  end
end
