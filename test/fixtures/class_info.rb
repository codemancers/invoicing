connection = ActiveRecord::Base.connection

connection.create_table :class_info_test_records do |t|
  t.integer :value
  t.string  :type
end

class ClassInfoTestRecord < ActiveRecord::Base
end

class ClassInfoTestSubclass    < ClassInfoTestRecord; end
class ClassInfoTestSubclass2   < ClassInfoTestRecord; end
class ClassInfoTestSubSubclass < ClassInfoTestSubclass2; end


ClassInfoTestRecord.create!(value: 2, type: "ClassInfoTestRecord")
ClassInfoTestRecord.create!(value: 3, type: "ClassInfoTestSubclass")
ClassInfoTestRecord.create!(value: 3, type: "ClassInfoTestSubclass2")
ClassInfoTestRecord.create!(value: 3, type: "ClassInfoTestSubSubclass")


connection.create_table :class_info_test2_records do |t|
  t.integer :value
  t.string  :okapi
end

class ClassInfoTest2Record < ActiveRecord::Base
end

ClassInfoTest2Record.create!(value: 1, okapi: "OKAPI!")
