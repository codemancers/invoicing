require File.join(File.dirname(__FILE__), 'test_helper.rb')

class TimeDependentTest < MiniTest::Unit::TestCase
  class TimeDependentRecord < ActiveRecord::Base
    # All columns are renamed to test renaming
    acts_as_time_dependent
  end

  # ----------    Acutal tests begin here    ---------
  def test_valid_records_during_single_period
    records = TimeDependentRecord.valid_records_during(DateTime.parse('2009-01-01'), DateTime.parse('2009-03-01'))
    assert_equal [3, 6, 8, 10], records.map(&:id).sort
  end

  def test_valid_records_during_single_period_ending_on_change_date
    records = TimeDependentRecord.valid_records_during(DateTime.parse('2008-10-31'), DateTime.parse('2009-01-01'))
    assert_equal [1, 2, 5, 8, 10], records.map(&:id).sort
  end

  def test_valid_records_during_transition_period
    records = TimeDependentRecord.valid_records_during(DateTime.parse('2008-09-01'), DateTime.parse('2009-02-28'))
    assert_equal [1, 2, 5, 6, 8, 10], records.map(&:id).sort
  end

  def test_valid_records_during_period_after_unreplaced_expiry
    records = TimeDependentRecord.valid_records_during(DateTime.parse('2011-09-01'), DateTime.parse('2011-09-02'))
    assert_equal [4, 9, 10], records.map(&:id).sort
  end

  def test_valid_records_at_boundary
    records = TimeDependentRecord.valid_records_at(DateTime.parse('2010-01-01'))
    assert_equal [4, 7, 8, 10], records.map(&:id).sort
  end

  def test_valid_records_at_middle_of_period
    records = TimeDependentRecord.valid_records_at(DateTime.parse('2009-07-01'))
    assert_equal [3, 6, 8, 10], records.map(&:id).sort
  end

  def test_valid_records_at_just_before_end_of_period
    records = TimeDependentRecord.valid_records_at(DateTime.parse('2008-12-31 23:59:59'))
    assert_equal [1, 2, 5, 8, 10], records.map(&:id).sort
  end

  def test_default_record_at_returns_default
    assert_equal 9, TimeDependentRecord.default_record_at(DateTime.parse('2011-04-01')).id
  end

  def test_default_record_at_where_there_is_no_default
    assert_nil TimeDependentRecord.default_record_at(DateTime.parse('2008-03-01'))
  end

  def test_default_value_at
    assert_equal 'Seven', TimeDependentRecord.default_value_at(DateTime.parse('2010-01-01 00:00:01'))
  end

  def test_default_value_at_alias
    assert_equal 'Six', TimeDependentRecord.default_value_at(DateTime.parse('2009-12-31 23:59:59'))
  end

  def test_default_record_now
    # Hello future. This is January 2009 speaking. Is someone out there still using this library?
    # If so, you may want to update this test from time to time. But you probably won't need to.
    expected = case Date.today.year
      when 2009 then 6
      when 2010 then 7
      else 9
    end
    assert_equal expected, TimeDependentRecord.default_record_now.id
  end

  def test_default_value_now
    expected = case Date.today.year
      when 2009 then 'Six'
      when 2010 then 'Seven'
      else 'Nine'
    end
    assert_equal expected, TimeDependentRecord.default_value_now
  end

  def test_default_value_now_alias
    expected = case Date.today.year
      when 2009 then 'Six'
      when 2010 then 'Seven'
      else 'Nine'
    end
    assert_equal expected, TimeDependentRecord.default_value_now
  end

  def test_multiple_predecessors
    assert_equal [2, 5], TimeDependentRecord.find(3).predecessors.map{|r| r.id}.sort
  end

  def test_one_predecessor
    assert_equal [8], TimeDependentRecord.find(9).predecessors.map{|r| r.id}
  end

  def test_no_predecessors
    assert_equal [], TimeDependentRecord.find(1).predecessors
  end

  def test_record_at_same_period
    assert_equal 3, TimeDependentRecord.find(3).record_at(DateTime.parse('2009-12-31 23:59:59')).id
  end

  def test_record_at_next_period
    assert_equal 4, TimeDependentRecord.find(3).record_at(DateTime.parse('2010-01-01 00:00:00')).id
  end

  def test_record_at_future_period
    assert_equal 4, TimeDependentRecord.find(2).record_at(DateTime.parse('2036-07-09')).id
  end

  def test_record_at_within_long_period
    assert_equal 8, TimeDependentRecord.find(8).record_at(DateTime.parse('2010-12-31 23:59:58')).id
  end

  def test_record_at_with_no_replacement
    assert_nil TimeDependentRecord.find(1).record_at(DateTime.parse('2009-07-09'))
  end

  def test_record_at_with_no_predecessor
    assert_nil TimeDependentRecord.find(7).record_at(DateTime.parse('2008-07-09'))
  end

  def test_record_at_with_unique_predecessor
    assert_equal 3, TimeDependentRecord.find(4).record_at(DateTime.parse('2009-01-01')).id
  end

  def test_record_at_with_ambiguous_predecessor
    assert_nil TimeDependentRecord.find(4).record_at(DateTime.parse('2008-12-31'))
  end

  def test_record_at_long_ago
    assert_nil TimeDependentRecord.find(10).record_at(DateTime.parse('1970-01-01'))
  end

  def test_record_now
    assert_equal 10, TimeDependentRecord.find(10).record_now.id
  end

  def test_value_at
    assert_equal 'Four', TimeDependentRecord.find(5).value_at(DateTime.parse('2028-01-13'))
  end

  def test_value_at_alias
    assert_equal 'Four', TimeDependentRecord.find(5).value_at(DateTime.parse('2028-01-13'))
  end

  def test_value_now
    assert_equal 'Ten', TimeDependentRecord.find(10).value_now
  end

  def test_value_now_alias
    assert_equal 'Ten', TimeDependentRecord.find(10).value_now
  end

  def test_changes_until_without_changes
    assert_equal [], TimeDependentRecord.find(8).changes_until(DateTime.parse('2010-12-31 23:59:59'))
  end

  def test_changes_until_with_one_change
    assert_equal [9], TimeDependentRecord.find(8).changes_until(DateTime.parse('2011-01-01')).map{|r| r.id}
  end

  def test_changes_until_with_multiple_changes
    assert_equal [3, 4], TimeDependentRecord.find(2).changes_until(DateTime.parse('2034-01-01')).map{|r| r.id}
  end

  def test_changes_until_with_imminent_expiry
    assert_equal [nil], TimeDependentRecord.find(1).changes_until(DateTime.parse('2009-01-01'))
  end

  def test_changes_until_with_future_expiry
    assert_equal [TimeDependentRecord.find(7), nil], TimeDependentRecord.find(6).changes_until(DateTime.parse('2012-01-01'))
  end
end
