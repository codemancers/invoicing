module Invoicing
  # Extensions specific to certain database adapters. Currently only MySQL and PostgreSQL are
  # supported.
  class ConnectionAdapterExt

    # Creates a database-specific SQL fragment for evaluating a three-legged conditional function
    # in a query.
    def self.conditional_function(condition, value_if_true, value_if_false)
      case ActiveRecord::Base.connection.adapter_name
        when "MySQL"
          "IF(#{condition}, #{value_if_true}, #{value_if_false})"
        when "PostgreSQL", "SQLite"
          "CASE WHEN #{condition} THEN #{value_if_true} ELSE #{value_if_false} END"
        else
          raise "Database adapter #{ActiveRecord::Base.connection.adapter_name} not supported by invoicing gem"
      end
    end

    # Suppose <tt>A has_many B</tt>, and you want to select all As, counting for each A how many
    # Bs it has. In MySQL you can just say:
    #   SELECT A.*, COUNT(B.id) AS number_of_bs FROM A LEFT JOIN B on A.id = B.a_id GROUP BY A.id
    # PostgreSQL, however, doesn't like you selecting a column from A if that column is neither
    # in the <tt>GROUP BY</tt> clause nor wrapped in an aggregation function (even though it is
    # implicitly grouped by through the fact that <tt>A.id</tt> is unique per row). Therefore
    # for PostgreSQL, we need to explicitly list all of A's columns in the <tt>GROUP BY</tt>
    # clause.
    #
    # This method takes a model class (a subclass of <tt>ActiveRecord::Base</tt>) and returns
    # a string suitable to be used as the contents of the <tt>GROUP BY</tt> clause.
    def self.group_by_all_columns(model_class)
      case ActiveRecord::Base.connection.adapter_name
        when "MySQL"
          model_class.quoted_table_name + "." +
            ActiveRecord::Base.connection.quote_column_name(model_class.primary_key)
        when "PostgreSQL", "SQLite"
          model_class.column_names.map{ |column|
            model_class.quoted_table_name + "." + ActiveRecord::Base.connection.quote_column_name(column)
          }.join(', ')
        else
          raise "Database adapter #{ActiveRecord::Base.connection.adapter_name} not supported by invoicing gem"
      end
    end
  end
end
