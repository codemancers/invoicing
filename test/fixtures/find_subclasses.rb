connection = ActiveRecord::Base.connection

connection.create_table :find_subclasses_records do |t|
  t.string  :value
  t.string  :type_name
  t.integer :associate_id
end

class FindSubclassesRecord < ActiveRecord::Base
end

FindSubclassesRecord.create!(value: "Mooo!", associate_id: 1,   type_name: "TestBaseclass")
FindSubclassesRecord.create!(value: "Baaa!", associate_id: nil, type_name: "TestSubclass")
FindSubclassesRecord.create!(value: "Mooo!", associate_id: nil, type_name: "TestSubSubclass")
FindSubclassesRecord.create!(value: "Baaa!", associate_id: nil, type_name: "TestSubclassInAnotherFile")
FindSubclassesRecord.create!(value: "Mooo!", associate_id: 1,   type_name: "TestModule::TestInsideModuleSubclass")
FindSubclassesRecord.create!(value: "Baaa!", associate_id: 1,   type_name: "TestOutsideModuleSubSubclass")


connection.create_table :find_subclasses_associates do |t|
  t.string :value
end

class FindSubclassesAssociate < ActiveRecord::Base
end

FindSubclassesAssociate.create!(value: "Cool stuff")


connection.create_table :find_subclasses_non_existents do |t|
  t.string :value
  t.string :type
end

class FindSubclassesNonExistent < ActiveRecord::Base
end

class SurelyThereIsNoClassWithThisName < FindSubclassesNonExistent
end

FindSubclassesNonExistent.create!(value: "Badger", type: "SurelyThereIsNoClassWithThisName")
Object.send(:remove_const, :SurelyThereIsNoClassWithThisName)
