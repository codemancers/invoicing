require File.join(File.dirname(__FILE__), 'test_helper.rb')

# Mini implementation of the ClassInfo pattern, at which we can fire our tests

module MyNamespace
  module ClassInfoTestModule
    module ActMethods
      def acts_as_class_info_test(*args)
        Invoicing::ClassInfo.acts_as(MyNamespace::ClassInfoTestModule, self, args)
      end
    end

    def get_class_info
      class_info_test_module_class_info
    end

    def my_instance_method
      class_info_test_module_class_info.the_answer / value
    end

    def my_other_instance_method
      class_info_test_module_class_info.not_the_answer / value
    end

    module ClassMethods
      def my_class_method(number)
        class_info_test_module_class_info.the_answer / number
      end

      def my_other_class_method(number)
        class_info_test_module_class_info.not_the_answer / number
      end

      def get_class_info
        class_info_test_module_class_info
      end
    end

    class ClassInfo < Invoicing::ClassInfo::Base
      def foo
        'foo'
      end

      def the_answer
        all_args.first
      end

      def not_the_answer
        all_args.last
      end

      def option_defaults
        {:option1 => :baa, :option2 => :blah}
      end
    end
  end


  module ClassInfoTest2
    module ActMethods
      def acts_as_class_info_test2(*args)
        Invoicing::ClassInfo.acts_as(MyNamespace::ClassInfoTest2, self, args)
      end
    end

    module ClassMethods
      def test2_class_info
        class_info_test2_class_info
      end
    end

    class ClassInfo < Invoicing::ClassInfo::Base
    end
  end
end

ActiveRecord::Base.send(:extend, MyNamespace::ClassInfoTestModule::ActMethods)
ActiveRecord::Base.send(:extend, MyNamespace::ClassInfoTest2::ActMethods)


# Model objects which use the acts_as feature defined above

class ClassInfoTestRecord < ActiveRecord::Base
  acts_as_class_info_test 42, :option1 => :moo
  acts_as_class_info_test 84, 42, 168, :option3 => :asdf

  def self.class_foo
    class_info_test_module_class_info.foo
  end

  def instance_foo
    class_info_test_module_class_info.foo
  end
end

class ClassInfoTestSubclass < ClassInfoTestRecord
  acts_as_class_info_test 336, :option1 => :quack, :option4 => :fdsa
end

class ClassInfoTestSubclass2 < ClassInfoTestRecord
  acts_as_class_info_test2 :option1 => :badger
end

class ClassInfoTestSubSubclass < ClassInfoTestSubclass2
  acts_as_class_info_test 112, :option3 => 1234
end

class ClassInfoTestEmptySubclass < ClassInfoTestRecord
end

class ClassInfoTest2Record < ActiveRecord::Base
  acts_as_class_info_test2 :option1 => :okapi, :option3 => :kangaroo

  def option1; 'this is option1'; end
  def option2; 'this is option2'; end
  def kangaroo; 'bounce'; end
end


#######################################################################################

class ClassInfoTest < Test::Unit::TestCase

  def test_call_into_class_info_via_class
    assert_equal 'foo', ClassInfoTestRecord.class_foo
  end

  def test_call_into_class_info_via_instance
    assert_equal 'foo', ClassInfoTestRecord.new.instance_foo
  end

  def test_mixin_superclass_instance_methods
    assert_equal 21, ClassInfoTestRecord.find(1).my_instance_method
    assert_equal 84, ClassInfoTestRecord.find(1).my_other_instance_method
  end

  def test_mixin_superclass_class_methods
    assert_equal 14, ClassInfoTestRecord.my_class_method(3)
    assert_equal 28, ClassInfoTestRecord.my_other_class_method(6)
  end

  def test_mixin_subclass_instance_methods
    assert_equal 14, ClassInfoTestRecord.find(2).my_instance_method
    assert_equal 112, ClassInfoTestRecord.find(2).my_other_instance_method
  end

  def test_mixin_subclass_class_methods
    assert_equal 14, ClassInfoTestSubclass.my_class_method(3)
    assert_equal 56, ClassInfoTestSubclass.my_other_class_method(6)
  end

  def test_all_args_in_superclass
    assert_equal [42, 84, 168], ClassInfoTestRecord.get_class_info.all_args
  end

  def test_all_args_in_subclass
    assert_equal [42, 84, 168, 336], ClassInfoTestSubclass.get_class_info.all_args
  end

  def test_all_args_in_sub_subclass
    assert_equal [42, 84, 168, 112], ClassInfoTestSubSubclass.get_class_info.all_args
  end

  def test_current_args_in_superclass
    assert_equal [84, 42, 168], ClassInfoTestRecord.get_class_info.current_args
  end

  def test_current_args_in_subclass
    assert_equal [336], ClassInfoTestSubclass.get_class_info.current_args
  end

  def test_current_args_in_sub_subclass
    assert_equal [112], ClassInfoTestSubSubclass.get_class_info.current_args
  end

  def test_new_args_in_superclass
    assert_equal [84, 168], ClassInfoTestRecord.get_class_info.new_args
  end

  def test_new_args_in_subclass
    assert_equal [336], ClassInfoTestSubclass.get_class_info.new_args
  end

  def test_new_args_in_sub_subclass
    assert_equal [112], ClassInfoTestSubSubclass.get_class_info.new_args
  end

  def test_all_options_in_superclass
    assert_equal :moo,   ClassInfoTestRecord.get_class_info.all_options[:option1]
    assert_equal :blah,  ClassInfoTestRecord.get_class_info.all_options[:option2]
    assert_equal :asdf,  ClassInfoTestRecord.get_class_info.all_options[:option3]
    assert_nil           ClassInfoTestRecord.get_class_info.all_options[:option4]
  end

  def test_all_options_in_subclass
    assert_equal :quack, ClassInfoTestSubclass.get_class_info.all_options[:option1]
    assert_equal :blah,  ClassInfoTestSubclass.get_class_info.all_options[:option2]
    assert_equal :asdf,  ClassInfoTestSubclass.get_class_info.all_options[:option3]
    assert_equal :fdsa,  ClassInfoTestSubclass.get_class_info.all_options[:option4]
  end

  def test_all_options_in_sub_subclass
    assert_equal :moo,   ClassInfoTestSubSubclass.get_class_info.all_options[:option1]
    assert_equal :blah,  ClassInfoTestSubSubclass.get_class_info.all_options[:option2]
    assert_equal 1234,   ClassInfoTestSubSubclass.get_class_info.all_options[:option3]
    assert_nil           ClassInfoTestSubSubclass.get_class_info.all_options[:option4]
  end

  def test_current_options_in_superclass
    assert_equal({:option3 => :asdf}, ClassInfoTestRecord.get_class_info.current_options)
  end

  def test_current_options_in_subclass
    assert_equal({:option1 => :quack, :option4 => :fdsa}, ClassInfoTestSubclass.get_class_info.current_options)
  end

  def test_two_features_in_the_same_model
    assert_equal({:option1 => :badger}, ClassInfoTestSubclass2.test2_class_info.all_options)
    assert_equal({:option1 => :badger}, ClassInfoTestSubSubclass.test2_class_info.all_options)
  end

  def test_the_same_feature_in_two_models
    assert_equal({:option1 => :okapi, :option3 => :kangaroo}, ClassInfoTest2Record.test2_class_info.all_options)
  end

  def test_method_renamed
    assert_equal 'kangaroo', ClassInfoTest2Record.test2_class_info.method(:option3)
    assert_equal 'bounce',   ClassInfoTest2Record.test2_class_info.get(ClassInfoTest2Record.find(1), :option3)
  end

  def test_database_column_renamed
    assert_equal 'okapi',  ClassInfoTest2Record.test2_class_info.method(:option1)
    assert_equal 'OKAPI!', ClassInfoTest2Record.test2_class_info.get(ClassInfoTest2Record.find(1), :option1)
  end

  def test_method_not_renamed
    assert_equal 'option2',         ClassInfoTest2Record.test2_class_info.method(:option2)
    assert_equal 'this is option2', ClassInfoTest2Record.test2_class_info.get(ClassInfoTest2Record.find(1), :option2)
  end

  def test_method_on_nil_object
    assert_nil ClassInfoTest2Record.test2_class_info.get(nil, :option2)
  end

  def test_method_not_found_via_class_info
    assert_nil ClassInfoTest2Record.test2_class_info.get(ClassInfoTest2Record.find(1), :this_method_does_not_exist)
  end

  def test_inherited_to_empty_subclass
    assert_not_nil ClassInfoTestEmptySubclass.new.get_class_info
    assert_equal ClassInfoTestEmptySubclass.new.get_class_info, ClassInfoTestRecord.new.get_class_info
  end
end
