## Helper stuff
module LedgerItemMethods
  def user_id_to_details_hash(user_id)
    case user_id
      when 1, nil
        {:is_self => true, :name => 'Unlimited Limited', :contact_name => "Mr B. Badger",
         :address => "The Sett\n5 Badger Lane\n", :city => "Badgertown", :state => "",
         :postal_code => "Badger999", :country => "England", :country_code => "GB",
         :tax_number => "123456789"}
      when 2
        {:name => 'Lovely Customer Inc.', :contact_name => "Fred",
         :address => "The pasture", :city => "Mootown", :state => "Cow Kingdom",
         :postal_code => "MOOO", :country => "Scotland", :country_code => "GB",
         :tax_number => "987654321"}
      when 3
        {:name => 'I drink milk', :address => "Guzzle guzzle", :city => "Cheesetown",
         :postal_code => "12345", :country => "United States", :country_code => "US"}
      when 4
        {:name => 'The taxman', :address => "ALL YOUR EARNINGS\r\n\tARE BELONG TO US",
         :city => 'Cumbernauld', :state => 'North Lanarkshire', :postal_code => "",
         :country => 'United Kingdom'}
    end
  end

  def sender_details
    user_id_to_details_hash(sender_id)
  end

  def recipient_details
    user_id_to_details_hash(recipient_id)
  end

  def description
    "#{type} #{id}"
  end
end


class MyLedgerItem < ActiveRecord::Base
  self.table_name = "ledger_item_records"
  acts_as_ledger_item
  has_many :line_items, class_name: "SuperLineItem", foreign_key: "ledger_item_id"
  include LedgerItemMethods
end

class MyInvoice < MyLedgerItem
  acts_as_ledger_item :subtype => :invoice
end

class InvoiceSubtype < MyInvoice
end

class CorporationTaxLiability < MyLedgerItem
  def self.debit_when_sent_by_self
    true
  end
end

class UUIDNotPresentLedgerItem < ActiveRecord::Base
  self.table_name = "ledger_item_records"
  include LedgerItemMethods

  def get_class_info
    ledger_item_class_info
  end
end

class OverwrittenMethodsNotPresentLedgerItem < ActiveRecord::Base
  self.table_name = "ledger_item_records"
  acts_as_invoice
end
