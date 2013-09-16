connection = ActiveRecord::Base.connection

connection.create_table :time_dependent_records do |t|
  t.datetime :valid_from, null: false
  t.datetime :valid_until
  t.integer  :replaced_by_id
  t.string   :value, null: false
  t.boolean  :is_default
end

class TimeDependentRecord < ActiveRecord::Base
end

#	2008 -> 2009 -> 2010 -> 2011
#
#	1	  -> none
#	2	  -> 3	 -> 4
#	5	  -> 3
#	none -> 6*	 -> 7*	-> none
#	8							-> 9*
#	10
#
#	* = default
time_dependent_record_entries = [
  #(id2, valid_from2, valid_until2, replaced_by_id2, value2, is_default2)
	[ 1, '2008-01-01 00:00:00', '2009-01-01 00:00:00', nil, 'One',	false],
	[ 2, '2008-01-01 00:00:00', '2009-01-01 00:00:00', 3,		'Two',	false],
	[ 3, '2009-01-01 00:00:00', '2010-01-01 00:00:00', 4,		'Three', false],
	[ 4, '2010-01-01 00:00:00', nil,						nil, 'Four',	false],
	[ 5, '2008-01-01 00:00:00', '2009-01-01 00:00:00', 3,		'Five',	false],
	[ 6, '2009-01-01 00:00:00', '2010-01-01 00:00:00', 7,		'Six',	true ],
	[ 7, '2010-01-01 00:00:00', '2011-01-01 00:00:00', nil, 'Seven', true ],
	[ 8, '2008-01-01 00:00:00', '2011-01-01 00:00:00', 9,		'Eight', false],
	[ 9, '2011-01-01 00:00:00', nil,						nil, 'Nine',	true ],
	[10, '2008-01-01 00:00:00', nil,						nil, 'Ten',	false]
]

time_dependent_record_entries.each do |entry|
  params = {}
  params[:valid_from]     = entry[1]
  params[:valid_until]    = entry[2]
  params[:replaced_by_id] = entry[3]
  params[:value]          = entry[4]
  params[:is_default]     = entry[5]

  TimeDependentRecord.create!(params)
end
