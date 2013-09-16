module Invoicing
  module Countries
    module UK
      # Extremely simplistic implementation of UK VAT. This needs to be fixed.
      class VAT
        def tax_rate(params)
          params[:model_object].send(:tax_rate)
        end

        def tax_factor(params)
          BigDecimal('1') + tax_rate(params).rate
        end

        def tax_percent(params)
          BigDecimal('100') * tax_rate(params).rate
        end

        def apply_tax(params)
          params[:value] * tax_factor(params)
        end

        def remove_tax(params)
          params[:value] / tax_factor(params)
        end

        def tax_info(params)
          "(inc. VAT)"
        end

        def tax_details(params)
          "(including VAT at #{tax_percent(params).to_s}%)"
        end
      end
    end
  end
end
