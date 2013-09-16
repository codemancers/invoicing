connection = ActiveRecord::Base.connection

connection.create_table :cached_records do |t|
  t.string :value
end

class CachedRecord < ActiveRecord::Base
end

CachedRecord.create!(value: "One")
CachedRecord.create!(value: "Two")

connection.create_table :refers_to_cached_records do |t|
  t.references :cached_record
end

class RefersToCachedRecord < ActiveRecord::Base
  belongs_to :cached_record
end

RefersToCachedRecord.create!(cached_record_id: 1)
RefersToCachedRecord.create!(cached_record_id: 1)
RefersToCachedRecord.create!(cached_record_id: nil)
