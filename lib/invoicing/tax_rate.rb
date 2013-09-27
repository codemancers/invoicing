module Invoicing
  module TaxRate
    module ActMethods
      def acts_as_tax_rate(*args)
        Invoicing::ClassInfo.acts_as(Invoicing::TaxRate, self, args)

        info = tax_rate_class_info
        if info.previous_info.nil? # Called for the first time?
          # Import TimeDependent functionality
          acts_as_time_dependent :value => :rate
        end
      end
    end

    # Stores state in the ActiveRecord class object
    class ClassInfo < Invoicing::ClassInfo::Base #:nodoc:
    end
  end
end
