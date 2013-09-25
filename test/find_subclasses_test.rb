require File.join(File.dirname(__FILE__), 'test_helper.rb')

# Associated with TestBaseclass
class FindSubclassesAssociate < ActiveRecord::Base
end

# Primary hierarchy of classes for testing.
class TestBaseclass < ActiveRecord::Base
  self.table_name = "find_subclasses_records"
  self.inheritance_column = "type_name" # usually left as default 'type'. rename to test renaming
  belongs_to :associate, :foreign_key => 'associate_id', :class_name => 'FindSubclassesAssociate'
  scope :with_coolness, lambda{|factor| {:conditions => {:coolness_factor => factor}}}
  extend Invoicing::FindSubclasses
  def self.coolness_factor; 3; end
end

class TestSubclass < TestBaseclass
end

class TestSubSubclass < TestSubclass
  def self.coolness_factor; 5; end
end

module TestModule
  class TestInsideModuleSubclass < TestBaseclass
    def self.coolness_factor; nil; end
  end
end

class TestOutsideModuleSubSubclass < TestModule::TestInsideModuleSubclass
  def self.coolness_factor; 999; end
end

# This class' table contains non-existent subclass names, to test errors
class SomeSillySuperclass < ActiveRecord::Base
  extend Invoicing::FindSubclasses
  self.table_name = "find_subclasses_non_existents"
end


#####################
class FindSubclassesTest < MiniTest::Unit::TestCase
  def test_known_subclasses
    # All subclasses of TestBaseclass except for TestSubclassNotInDatabase
    expected = ['TestBaseclass', 'TestModule::TestInsideModuleSubclass', 'TestOutsideModuleSubSubclass',
      'TestSubSubclass', 'TestSubclass', 'TestSubclassInAnotherFile']
    assert_equal expected, TestBaseclass.known_subclasses.map(&:name).sort
  end

  def test_known_subclasses_for_subtype
    expected = ['TestSubSubclass', 'TestSubclass']
    assert_equal expected, TestSubclass.known_subclasses.map(&:name).sort
  end

  def test_error_when_unknown_type_is_encountered
    assert_raises ActiveRecord::SubclassNotFound do
      SomeSillySuperclass.known_subclasses
    end
  end

  def test_class_method_condition_in_find
    assert_equal [1, 2, 4], TestBaseclass.where(:coolness_factor => 3).pluck(:id).sort
  end

  def test_class_method_condition_in_named_scope
    assert_equal [6], TestBaseclass.with_coolness(999).pluck(:id)
  end

  def test_class_method_condition_combined_with_column_condition_as_string_list
    assert_equal [2, 4], TestBaseclass.with_coolness(3).where("value LIKE ?", 'B%').pluck(:id).sort
  end

  def test_class_method_condition_combined_with_column_condition_as_hash
    assert_equal [1], TestBaseclass.where(:value => 'Mooo!', :coolness_factor => 3).pluck(:id)
  end

  def test_class_method_condition_combined_with_column_condition_on_joined_table_expressed_as_string
    conditions = {'find_subclasses_associates.value' => 'Cool stuff', 'find_subclasses_records.coolness_factor' => 3}
    assert_equal [1], TestBaseclass.joins(:associate).where(conditions).pluck(:id)
  end

  # TODO: Nested hashes are not supported as of now. Will look into it later
  # def test_class_method_condition_combined_with_column_condition_on_joined_table_expressed_as_hash
  #   conditions = {:find_subclasses_associates => {:value => 'Cool stuff'},
  #                 :find_subclasses_records    => {:coolness_factor => 3}}
  #   assert_equal [1], TestBaseclass.all(:joins => :associate, :conditions => conditions).map{|r| r.id}
  # end

  def test_class_method_condition_with_same_table_name
    conditions = {'find_subclasses_records.value' => 'Baaa!', 'find_subclasses_records.coolness_factor' => 3}
    assert_equal [2, 4], TestBaseclass.where(conditions).pluck(:id).sort
  end

  def test_class_method_condition_with_list_of_alternatives
    assert_equal [3, 6], TestBaseclass.where(:coolness_factor => [5, 999]).pluck(:id).sort
  end

  def test_class_method_condition_with_range_of_alternatives
    assert_equal [1, 2, 3, 4, 6], TestBaseclass.where(:coolness_factor => 1..1000).pluck(:id).sort
  end

  # TODO: The call is being made on superclass, so this test is not passing.
  # def test_class_method_condition_invoked_on_subclass
  #   assert_equal [2], TestSubclass.with_coolness(3).all.map{|r| r.id}
  # end

  def test_class_method_condition_false_type_coercion
    assert_equal [5], TestBaseclass.where(:coolness_factor => false).pluck(:id)
  end

  def test_class_method_condition_true_type_coercion
    assert_equal [1, 2, 3, 4, 6], TestBaseclass.where(:coolness_factor => true).pluck(:id).sort
  end
end
